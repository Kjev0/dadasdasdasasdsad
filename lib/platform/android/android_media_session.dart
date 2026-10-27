import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../../core/contracts/library.dart';
import '../../core/contracts/playback.dart';
import '../../core/platform/platform_info.dart';
import '../../settings/app_settings.dart';
import '../../settings/settings_store.dart';
import 'fermata_audio_handler.dart';
import 'headset_auto_resume.dart';
import 'media_browser.dart';
import 'media_session_config.dart';
import 'media_session_labels.dart';
import 'media_session_mapping.dart';

final _log = Logger('platform.android.session');

/// Starts and owns Fermata's Android media session: the audio_service
/// foreground service + MediaSession (notification, lock screen, Bluetooth
/// and headset buttons, Wear OS, Android Auto) and headset auto-resume.
///
/// On every other platform [start] returns an inactive session without
/// touching any plugin.
class AndroidMediaSession {
  AndroidMediaSession._({
    required this._settings,
    required this.configuredSettings,
    this.handler,
    this.headsetAutoResume,
  });

  static AndroidMediaSession? _active;

  /// audio_service can be initialised only once per process.
  static bool _audioServiceInitialized = false;

  final SettingsStore _settings;

  /// The audio handler, or null when inactive (non-Android, or
  /// `AudioService.init` failed).
  final FermataAudioHandler? handler;
  final HeadsetAutoResume? headsetAutoResume;

  /// Settings the session was configured with. audio_service reads its
  /// configuration only once per process.
  final AppSettings configuredSettings;

  /// Whether the media session is running.
  bool get isActive => handler != null;

  /// `android.stopForegroundOnPause` as applied at start.
  bool get stopForegroundOnPause => configuredSettings.android.stopForegroundOnPause;

  /// True when settings that are only read at start (keep the notification
  /// while paused; artwork preloading via performance mode) differ from the
  /// running configuration. The settings UI shows "applies after restart"
  /// while this is true.
  bool get restartRequiredForSettings => isActive && restartRequired(configuredSettings, _settings.current);

  /// Pure check behind [restartRequiredForSettings].
  static bool restartRequired(AppSettings configured, AppSettings current) =>
      configured.android.stopForegroundOnPause != current.android.stopForegroundOnPause ||
      preloadArtworkFor(configured) != preloadArtworkFor(current);

  /// Creates the session. Must run once per process, early in bootstrap
  /// (after the [PlaybackController] restored its queue), because Android
  /// may start the app in the background from a media button or the
  /// resumption card. Calling it again returns the running session.
  ///
  /// Never throws: if audio_service cannot start (e.g. manifest
  /// misconfiguration) the error is logged and an inactive session is
  /// returned — playback then still works while the app is in the
  /// foreground.
  ///
  /// [likeIcons]: pass only when those drawables are bundled; the like
  /// button is omitted otherwise. [routeEvents] overrides the audio_session
  /// device events (tests).
  static Future<AndroidMediaSession> start({
    required PlaybackController playback,
    required SettingsStore settings,
    TrackRepository? tracks,
    PlaylistRepository? playlists,
    HistoryRepository? history,
    FavoritesRepository? favorites,
    PlatformInfo? platform,
    LikeControlIcons? likeIcons,
    AudioRouteEvents? routeEvents,
  }) async {
    final running = _active;
    if (running != null) return running;
    final configured = settings.current;
    if (!(platform ?? PlatformInfo.current()).isAndroid) {
      return AndroidMediaSession._(settings: settings, configuredSettings: configured);
    }

    if (_audioServiceInitialized) {
      _log.warning('The Android media session was already started and disposed in this process');
      return AndroidMediaSession._(settings: settings, configuredSettings: configured);
    }

    final labels = MediaSessionLabels.forLocale(configured.localeCode ?? Platform.localeName);
    final FermataAudioHandler handler;
    try {
      _audioServiceInitialized = true;
      handler = await AudioService.init(
        builder: () => FermataAudioHandler(
          playback: playback,
          browser: MediaLibraryBrowser(
            tracks: tracks,
            playlists: playlists,
            history: history,
            favorites: favorites,
            labels: labels,
          ),
          favorites: favorites,
          tracks: tracks,
          likeIcons: likeIcons,
          labels: labels,
        ),
        config: buildAudioServiceConfig(configured, labels: labels),
      );
    } catch (e, st) {
      _log.severe('Could not start the Android media session; background playback is unavailable', e, st);
      return AndroidMediaSession._(settings: settings, configuredSettings: configured);
    }

    HeadsetAutoResume? autoResume;
    try {
      final events = routeEvents ?? AudioSessionRouteEvents(await AudioSession.instance);
      autoResume = HeadsetAutoResume(playback: playback, settings: settings, events: events)..start();
    } catch (e, st) {
      _log.warning('Headset auto-resume unavailable', e, st);
    }

    _log.info('Android media session started '
        '(stopForegroundOnPause=${configured.android.stopForegroundOnPause}, '
        'preloadArtwork=${preloadArtworkFor(configured)})');
    return _active = AndroidMediaSession._(
      settings: settings,
      configuredSettings: configured,
      handler: handler,
      headsetAutoResume: autoResume,
    );
  }

  /// Stops mirroring and headset monitoring (explicit Quit). Playback itself
  /// is stopped by the caller through the [PlaybackController]; the service
  /// goes away when the controller reports `idle`.
  Future<void> dispose() async {
    await headsetAutoResume?.dispose();
    await handler?.dispose();
    if (identical(_active, this)) _active = null;
  }

  /// Forgets the running session (tests only; audio_service itself cannot be
  /// re-initialised in one process).
  @visibleForTesting
  static void resetForTesting() {
    _active = null;
    _audioServiceInitialized = false;
  }
}
