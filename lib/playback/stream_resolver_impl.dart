import 'dart:io';

import 'package:logging/logging.dart';

import '../core/contracts/downloads.dart';
import '../core/contracts/library.dart';
import '../core/contracts/music_source.dart';
import '../core/contracts/playback.dart';
import '../core/errors.dart';
import '../core/models/library.dart';
import '../core/models/playback.dart';
import '../core/models/track.dart';
import '../core/util/cancel_token.dart';
import '../settings/settings_store.dart';

final _log = Logger('playback.resolver');

/// Resolves a [Track] into something playable, in this order:
/// 1. a completed, integrity-verified download,
/// 2. the user-owned local file (must exist, else `file_missing`),
/// 3. the source's own stream (respecting [TrackAvailability]; quality from
///    settings, the mobile quality on metered connections),
/// 4. linked tracks on other sources in provider-preference order (links to
///    preview-only tracks are used only when nothing else works and are
///    marked [PlayableSource.isPreview]).
///
/// Otherwise throws [UnplayableTrackException] with the most informative
/// [AvailabilityReason] seen along the way.
class StreamResolverImpl implements StreamResolver {
  StreamResolverImpl({
    required this._sources,
    required this._downloads,
    required this._links,
    required this._settings,
    this._isMetered,
  });

  final SourceRegistry _sources;
  final DownloadManager _downloads;
  final TrackLinkRepository _links;
  final SettingsStore _settings;
  final Future<bool> Function()? _isMetered;

  /// Most informative first.
  static const _reasonRank = [
    AvailabilityReason.fileMissing,
    AvailabilityReason.offline,
    AvailabilityReason.credentialsMissing,
    AvailabilityReason.notAuthorized,
    AvailabilityReason.regionRestricted,
    AvailabilityReason.subscriptionRequired,
    AvailabilityReason.deleted,
    AvailabilityReason.private,
    AvailabilityReason.previewOnly,
    AvailabilityReason.notStreamable,
    AvailabilityReason.externalOnly,
  ];

  @override
  Future<ResolvedStream> resolve(Track track, {CancelToken? cancel}) async {
    final reasons = <String>[];
    final primary = await _resolveDirect(track, reasons, cancel);
    if (primary != null && !primary.source.isPreview) return primary;
    var preview = primary;

    for (final linked in await _linkedCandidates(track)) {
      cancel?.throwIfCanceled();
      final r = await _resolveDirect(linked, reasons, cancel);
      if (r == null) continue;
      if (r.source.isPreview) {
        preview ??= r;
        continue;
      }
      _log.fine('Playing ${track.id} via linked ${linked.id}');
      return r;
    }
    if (preview != null) return preview;
    throw UnplayableTrackException(track.id, mostInformative(reasons));
  }

  /// Picks the most informative reason code (unknown codes rank just above
  /// `unknown`).
  static String mostInformative(Iterable<String> reasons) {
    String? best;
    var bestRank = 1 << 30;
    for (final r in reasons) {
      if (r == AvailabilityReason.unknown) continue;
      final idx = _reasonRank.indexOf(r);
      final rank = idx < 0 ? _reasonRank.length : idx;
      if (rank < bestRank) {
        best = r;
        bestRank = rank;
      }
    }
    return best ?? AvailabilityReason.unknown;
  }

  /// Steps 1–3 for one track. Returns null (adding reasons) when it cannot
  /// be played this way.
  Future<ResolvedStream?> _resolveDirect(Track t, List<String> reasons, CancelToken? cancel) async {
    cancel?.throwIfCanceled();

    // 1. Verified download.
    try {
      final path = await _downloads.localFileFor(t.id);
      if (path != null) {
        if (await File(path).exists()) return _local(path, t);
        _log.warning('Download of ${t.id} is registered but the file is missing');
      }
    } catch (e, st) {
      _log.warning('Download lookup failed for ${t.id}', e, st);
    }

    // 2. User-owned local file.
    final localPath = t.localPath;
    if (localPath != null) {
      if (await File(localPath).exists()) return _local(localPath, t);
      reasons.add(AvailabilityReason.fileMissing);
    } else if (t.isLocal) {
      reasons.add(AvailabilityReason.fileMissing);
    }
    if (t.isLocal) return null;

    // 3. The source's own stream.
    final settings = _settings.current;
    if (settings.services.disabledSources.contains(t.sourceId)) {
      reasons.add(AvailabilityReason.notAuthorized);
      return null;
    }
    final source = _sources.byId(t.sourceId);
    if (source == null) {
      reasons.add(AvailabilityReason.unknown);
      return null;
    }
    final availability = t.availability;
    switch (availability.playback) {
      case PlaybackRights.unavailable:
        reasons.add(availability.reason ?? AvailabilityReason.unknown);
        return null;
      case PlaybackRights.externalOnly:
        reasons.add(AvailabilityReason.externalOnly);
        return null;
      case PlaybackRights.full || PlaybackRights.preview || PlaybackRights.unknown:
        break;
    }
    final canStream = source.supports(SourceCapability.stream);
    final previewOnly = !canStream && source.supports(SourceCapability.previewOnly);
    if (!canStream && !previewOnly) {
      reasons.add(source.supports(SourceCapability.externalPlayback)
          ? AvailabilityReason.externalOnly
          : AvailabilityReason.notStreamable);
      return null;
    }
    try {
      final quality = await _quality();
      final stream = await source.resolveStream(t, quality: quality, cancel: cancel);
      final isPreview = stream.isPreview || previewOnly || availability.playback == PlaybackRights.preview;
      return ResolvedStream(source: isPreview ? _asPreview(stream) : stream, playedTrack: t);
    } on OperationCanceledException {
      rethrow;
    } on UnplayableTrackException catch (e) {
      reasons.add(e.reason);
    } on MissingCredentialsException {
      reasons.add(AvailabilityReason.credentialsMissing);
    } on AuthRequiredException {
      reasons.add(AvailabilityReason.notAuthorized);
    } on NetworkException {
      reasons.add(AvailabilityReason.offline);
    } on UnsupportedSourceOperation {
      reasons.add(source.supports(SourceCapability.externalPlayback)
          ? AvailabilityReason.externalOnly
          : AvailabilityReason.notStreamable);
    } on FermataException catch (e) {
      _log.warning('Stream resolution failed for ${t.id}: ${e.code}');
      reasons.add(AvailabilityReason.unknown);
    }
    return null;
  }

  /// Linked tracks ordered by provider preference, then link confidence.
  Future<List<Track>> _linkedCandidates(Track track) async {
    List<(Track, TrackLink)> linked;
    try {
      linked = await _links.linkedTracks(track.id);
    } catch (e, st) {
      _log.warning('Could not load links for ${track.id}', e, st);
      return const [];
    }
    final services = _settings.current.services;
    final order = services.providerOrder;
    int rank(Track t) {
      final i = order.indexOf(t.sourceId);
      return i < 0 ? order.length : i;
    }

    final candidates = [
      for (final (t, link) in linked)
        if (t.id != track.id && !services.disabledSources.contains(t.sourceId)) (t, link),
    ];
    // Stable: provider preference first, then confidence (desc), then the
    // repository's order.
    final indexed = [for (var i = 0; i < candidates.length; i++) (i, candidates[i])];
    indexed.sort((a, b) {
      final byProvider = rank(a.$2.$1).compareTo(rank(b.$2.$1));
      if (byProvider != 0) return byProvider;
      final byConfidence = b.$2.$2.confidence.compareTo(a.$2.$2.confidence);
      if (byConfidence != 0) return byConfidence;
      return a.$1.compareTo(b.$1);
    });
    return [for (final (_, (t, _)) in indexed) t];
  }

  Future<AudioQuality> _quality() async {
    final q = _settings.current.audioQuality;
    var metered = false;
    try {
      metered = await (_isMetered?.call() ?? Future.value(false));
    } catch (e) {
      _log.fine('Metered check failed; assuming unmetered', e);
    }
    return metered ? q.mobileStreaming : q.streaming;
  }

  static ResolvedStream _local(String path, Track t) =>
      ResolvedStream(source: PlayableSource(uri: Uri.file(path), isLocalFile: true), playedTrack: t);

  static PlayableSource _asPreview(PlayableSource s) => s.isPreview
      ? s
      : PlayableSource(
          uri: s.uri,
          headers: s.headers,
          isLocalFile: s.isLocalFile,
          isPreview: true,
          expiresAt: s.expiresAt,
          mimeType: s.mimeType,
        );
}
