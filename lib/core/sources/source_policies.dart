import 'package:flutter/foundation.dart';

import 'source_ids.dart';

/// Provider terms that change app behaviour, verified against each
/// provider's current terms (see docs/research/API_NOTES.md and
/// docs/COMPLIANCE.md). Enforced by the stream resolver, playback queue,
/// download manager and UI — never by convention alone.
@immutable
class SourcePolicy {
  const SourcePolicy({
    this.siloedPlayback = false,
    this.userInitiatedDownloads = false,
    this.automaticDownloads = false,
    this.previewUrlTtl,
    this.nonCommercialOnly = false,
  });

  /// Streams from this source must not be combined with streams from other
  /// services in one playback experience (queue). SoundCloud API Terms:
  /// no "playback experience which aggregates and streams User Content with
  /// content from other services". The user's own local files are not a
  /// "service" and may still be mixed in.
  final bool siloedPlayback;

  /// Single tracks may be downloaded when the user explicitly asks for it
  /// and the track itself is marked downloadable by its uploader.
  final bool userInitiatedDownloads;

  /// Tracks may be downloaded automatically (e.g. auto-download playlists /
  /// offline caching). No current remote provider permits this.
  final bool automaticDownloads;

  /// Signed preview URLs expire (Deezer ≈ 15 min) — re-resolve after this.
  final Duration? previewUrlTtl;
  final bool nonCommercialOnly;

  bool get allowsAnyDownload => userInitiatedDownloads || automaticDownloads;
}

abstract final class SourcePolicies {
  static const _policies = <String, SourcePolicy>{
    // User-owned files: everything allowed (no download needed anyway).
    SourceIds.local: SourcePolicy(userInitiatedDownloads: true, automaticDownloads: true),
    // SoundCloud API Terms: siloed playback; no in-app downloads or offline
    // mode regardless of the uploader's download setting.
    SourceIds.soundcloud: SourcePolicy(siloedPlayback: true),
    // Audius: artist-enabled downloads via the official endpoint, user
    // initiated only (API terms allow only session caching otherwise).
    SourceIds.audius: SourcePolicy(userInitiatedDownloads: true),
    // Jamendo: downloads only when audiodownload_allowed; app must not be
    // designed around offline caching → user initiated only.
    SourceIds.jamendo: SourcePolicy(userInitiatedDownloads: true, nonCommercialOnly: true),
    // Deezer: 30 s previews only; offline storage forbidden.
    SourceIds.deezer: SourcePolicy(previewUrlTtl: Duration(minutes: 12), nonCommercialOnly: true),
    // Spotify / YouTube: metadata + external playback only.
    SourceIds.spotify: SourcePolicy(),
    SourceIds.youtube: SourcePolicy(),
  };

  /// Unknown (plugin) sources default to the most restrictive download
  /// policy and no silo.
  static SourcePolicy of(String sourceId) => _policies[sourceId] ?? const SourcePolicy();

  /// The playback silo a queue belongs to: `soundcloud` when it contains
  /// SoundCloud streams, otherwise null (open queue).
  static String? siloOf(Iterable<String> streamSourceIds) {
    for (final id in streamSourceIds) {
      if (of(id).siloedPlayback) return id;
    }
    return null;
  }

  /// Whether a stream from [candidateSource] may play in a queue whose silo
  /// is [silo]. Local files are always allowed.
  static bool canJoinSilo(String? silo, String candidateSource) {
    if (candidateSource == SourceIds.local) return true;
    if (silo == null) return !of(candidateSource).siloedPlayback;
    return candidateSource == silo;
  }
}
