import 'dart:ui' show Color;

import 'package:audio_service/audio_service.dart';

import '../../settings/app_settings.dart';
import 'media_session_labels.dart';

/// Constants shared by the Android media session and its native side
/// (`android/app/src/main/AndroidManifest.xml`, `res/drawable`).
abstract final class AndroidMediaSessionConstants {
  /// Notification channel of the playback (media-style) notification.
  static const playbackChannelId = 'app.fermata.player.playback';

  /// Monochrome status-bar icon bundled by the native/branding side.
  static const notificationIcon = 'drawable/ic_stat_fermata';

  /// Fermata gold; used as the notification accent colour.
  static const notificationColor = Color(0xFFE9B44C);

  /// Artwork is downscaled to this size before it is handed to the system
  /// (saves memory; lock screen/notification never need more).
  static const artworkSize = 512;

  /// Jump size for fast-forward / rewind (notification, Wear, car).
  static const seekInterval = Duration(seconds: 15);
}

/// Whether artwork for queued tracks may be downloaded before they play.
/// Off in Battery saver and Data saver (and whenever the user disabled
/// artwork prefetching).
bool preloadArtworkFor(AppSettings settings) {
  final perf = settings.performance;
  return perf.prefetchArtwork &&
      perf.mode != PerformanceMode.batterySaver &&
      perf.mode != PerformanceMode.dataSaver;
}

/// Builds the [AudioServiceConfig] for [settings].
///
/// NOTE: audio_service reads the config exactly once, in `AudioService.init`
/// at app start. `android.stopForegroundOnPause` (and the performance mode's
/// effect on artwork preloading) therefore take effect after the app is
/// restarted — see `AndroidMediaSession.restartRequiredForSettings`.
AudioServiceConfig buildAudioServiceConfig(
  AppSettings settings, {
  MediaSessionLabels labels = MediaSessionLabels.en,
}) =>
    AudioServiceConfig(
      androidNotificationChannelId: AndroidMediaSessionConstants.playbackChannelId,
      androidNotificationChannelName: labels.channelName,
      androidNotificationChannelDescription: labels.channelDescription,
      androidNotificationIcon: AndroidMediaSessionConstants.notificationIcon,
      notificationColor: AndroidMediaSessionConstants.notificationColor,
      androidStopForegroundOnPause: settings.android.stopForegroundOnPause,
      // Swipe-to-dismiss while paused is only possible when the service
      // leaves the foreground on pause; keep the plugin defaults otherwise.
      androidNotificationOngoing: false,
      androidNotificationClickStartsActivity: true,
      androidShowNotificationBadge: false,
      preloadArtwork: preloadArtworkFor(settings),
      artDownscaleWidth: AndroidMediaSessionConstants.artworkSize,
      artDownscaleHeight: AndroidMediaSessionConstants.artworkSize,
      fastForwardInterval: AndroidMediaSessionConstants.seekInterval,
      rewindInterval: AndroidMediaSessionConstants.seekInterval,
      // Android Auto: show browse folders and tracks as lists.
      androidBrowsableRootExtras: const {
        AndroidContentStyle.supportedKey: true,
        AndroidContentStyle.browsableHintKey: AndroidContentStyle.listItemHintValue,
        AndroidContentStyle.playableHintKey: AndroidContentStyle.listItemHintValue,
      },
    );
