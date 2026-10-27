import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

import '../../app/providers.dart';
import '../../core/errors.dart';
import '../../core/models/catalog.dart';
import '../../core/models/download.dart';
import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import '../../core/sources/source_policies.dart';
import '../../l10n/gen/app_localizations.dart';
import '../design/context_ext.dart';
import '../widgets/dialogs/dialogs.dart';
import '../widgets/feedback/messages.dart';
import '../widgets/feedback/toast.dart';
import '../widgets/playlists/add_to_playlist_sheet.dart';
import 'link_launcher.dart';
import 'routes.dart';

final _log = Logger('ui.actions');

/// UI-side wrappers around playback, favorites, downloads and playlist
/// calls: they catch [FermataException]s, show localized toasts and enforce
/// the provider compliance rules (SoundCloud queue silo, download policy).
///
/// Create per use: `TrackActions(context, ref).playNext([track])`. The
/// [context] must stay mounted for toasts (use the tile's/page's context,
/// not a menu's).
class TrackActions {
  TrackActions(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  /// Error code thrown by the playback controller when tracks can't join
  /// the current queue's silo (SoundCloud terms).
  static const mixQueueOperation = 'mix_queue';

  // ---- Playback ---------------------------------------------------------

  Future<void> play(
    List<Track> tracks, {
    int startIndex = 0,
    String? origin,
    String? originLabel,
    bool shuffle = false,
  }) async {
    if (tracks.isEmpty) return;
    await _guard(() => ref.read(playbackProvider).playTracks(
          tracks,
          startIndex: startIndex.clamp(0, tracks.length - 1),
          origin: origin,
          originLabel: originLabel,
          shuffle: shuffle,
        ));
  }

  Future<void> playNext(List<Track> tracks, {String? origin}) =>
      _enqueue(tracks, origin: origin, next: true);

  Future<void> addToQueue(List<Track> tracks, {String? origin}) =>
      _enqueue(tracks, origin: origin, next: false);

  Future<void> _enqueue(List<Track> tracks, {String? origin, required bool next}) async {
    if (tracks.isEmpty) return;
    final playback = ref.read(playbackProvider);
    try {
      if (next) {
        await playback.playNext(tracks, origin: origin);
      } else {
        await playback.enqueue(tracks, origin: origin);
      }
      _toast((l) => next ? l.shellPlayingNext : l.shellAddedToQueue, Icons.queue_music_rounded);
    } on UnsupportedSourceOperation catch (e) {
      if (e.operation != mixQueueOperation) {
        _error(e);
        return;
      }
      if (!context.mounted) return;
      final l10n = context.l10n;
      final start = await ConfirmDialog.show(
        context,
        title: l10n.playerSiloTitle,
        message: l10n.playerSiloMessage,
        confirmLabel: l10n.playerSiloConfirm,
      );
      if (start) await play(tracks, origin: origin);
    } on FermataException catch (e) {
      _error(e);
    } catch (e, st) {
      _log.warning('Queue action failed', e, st);
      _error(e);
    }
  }

  // ---- Favorites --------------------------------------------------------

  Future<void> setFavorite(Track track, bool favorite) async {
    final ok = await _guard(() => ref.read(favoritesRepositoryProvider).setFavorite(track, favorite));
    if (ok) {
      _toast((l) => favorite ? l.shellLiked : l.shellUnliked, favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded);
    }
  }

  Future<void> toggleFavorite(Track track) {
    final ids = ref.read(favoriteIdsProvider).value ?? const <String>{};
    return setFavorite(track, !ids.contains(track.id));
  }

  // ---- Downloads --------------------------------------------------------

  /// Whether the provider's terms allow user-initiated downloads at all
  /// (never for SoundCloud, Deezer, Spotify, YouTube).
  static bool policyAllowsDownload(Track track) =>
      track.sourceId != SourceIds.local && SourcePolicies.of(track.sourceId).userInitiatedDownloads;

  /// Policy + per-track eligibility. Never throws.
  Future<DownloadEligibility?> eligibility(Track track) async {
    if (!policyAllowsDownload(track)) return null;
    try {
      return await ref.read(downloadManagerProvider).checkEligibility(track);
    } catch (e) {
      _log.fine('Eligibility check failed for ${track.id}: $e');
      return null;
    }
  }

  Future<void> download(Track track) async {
    if (!policyAllowsDownload(track)) {
      _toast((l) => l.shellErrorDownloadNotPermitted, Icons.block_rounded, isError: true);
      return;
    }
    final ok = await _guard(() => ref.read(downloadManagerProvider).enqueue(track));
    if (ok) _toast((l) => l.shellDownloadQueued, Icons.download_rounded);
  }

  /// Enqueues the downloadable tracks of [tracks]; reports how many can't be
  /// downloaded.
  Future<void> downloadAll(List<Track> tracks, {String? origin}) async {
    final allowed = tracks.where(policyAllowsDownload).toList();
    var rejected = tracks.length - allowed.length;
    var queued = 0;
    if (allowed.isNotEmpty) {
      Map<String, DownloadEligibility>? result;
      final ok = await _guard(() async {
        result = await ref.read(downloadManagerProvider).enqueueAll(allowed, origin: origin);
      });
      if (!ok) return;
      rejected += result?.length ?? 0;
      queued = allowed.length - (result?.length ?? 0);
    }
    if (queued > 0) {
      _toast(
        (l) => rejected > 0 ? '${l.shellDownloadsQueued(queued)} · ${l.shellDownloadsRejected(rejected)}' : l.shellDownloadsQueued(queued),
        Icons.download_rounded,
      );
    } else if (rejected > 0) {
      _toast((l) => l.shellDownloadsRejected(rejected), Icons.block_rounded, isError: true);
    }
  }

  Future<void> removeDownload(Track track) async {
    final ok = await _guard(() => ref.read(downloadManagerProvider).deleteDownload(track.id));
    if (ok) _toast((l) => l.shellDownloadRemoved, Icons.delete_outline_rounded);
  }

  // ---- Playlists --------------------------------------------------------

  /// Adds [tracks] to [playlist], or asks which playlist when null.
  Future<void> addToPlaylist(List<Track> tracks, {Playlist? playlist}) async {
    if (tracks.isEmpty) return;
    final target = playlist ?? await AddToPlaylistSheet.pick(context);
    if (target == null) return;
    final ok = await _guard(() async {
      await ref.read(trackRepositoryProvider).upsertTracks(tracks);
      await ref.read(playlistRepositoryProvider).addTracks(target.id, [for (final t in tracks) t.id]);
    });
    if (ok) {
      _toast(
        (l) => tracks.length == 1 ? l.shellAddedToPlaylist(target.name) : l.shellTracksAddedToPlaylist(tracks.length, target.name),
        Icons.playlist_add_check_rounded,
      );
    }
  }

  // ---- Links & navigation ----------------------------------------------

  /// Where the track can be opened on its provider (external playback URI,
  /// else the permalink).
  Uri? externalUri(Track track) {
    if (track.isLocal) return null;
    try {
      return ref.read(sourceRegistryProvider).byId(track.sourceId)?.externalPlaybackUri(track) ?? track.permalink;
    } catch (_) {
      return track.permalink;
    }
  }

  /// Link to copy/share (the permalink, else the external URI).
  Uri? shareUri(Track track) => track.isLocal ? null : (track.permalink ?? externalUri(track));

  Future<void> openExternally(Track track) async {
    final uri = externalUri(track);
    if (uri == null) return;
    await openLink(uri);
  }

  Future<void> openLink(Uri uri) async {
    var ok = false;
    try {
      ok = await ref.read(externalLinkLauncherProvider)(uri);
    } catch (e) {
      _log.warning('Could not open $uri: $e');
    }
    if (!ok) _toast((l) => l.shellCouldNotOpenLink, Icons.link_off_rounded, isError: true);
  }

  Future<void> copyLink(Track track) async {
    final uri = shareUri(track);
    if (uri == null) return;
    await Clipboard.setData(ClipboardData(text: uri.toString()));
    _toast((l) => l.shellLinkCopied, Icons.link_rounded);
  }

  void goToArtist(Track track) {
    final route = AppRoutes.artistForTrack(track);
    if (route != null) GoRouter.of(context).go(route);
  }

  void goToAlbum(Track track) {
    final route = AppRoutes.albumForTrack(track);
    if (route != null) GoRouter.of(context).go(route);
  }

  // ---- Helpers ----------------------------------------------------------

  Future<bool> _guard(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e, st) {
      if (e is! FermataException) _log.warning('Action failed', e, st);
      _error(e);
      return false;
    }
  }

  void _error(Object e) {
    if (!context.mounted) return;
    final registry = ref.read(sourceRegistryProvider);
    final message = errorMessageFor(context.l10n, e, sourceName: (id) => registry.byId(id)?.displayName ?? id);
    if (message != null) _toast((_) => message, null, isError: true);
  }

  void _toast(String Function(AppLocalizations l10n) message, IconData? icon, {bool isError = false}) {
    if (!context.mounted) return;
    showFermataToast(context, message(context.l10n), icon: icon, isError: isError);
  }
}
