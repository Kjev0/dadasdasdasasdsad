import 'package:flutter/foundation.dart';

import '../core/contracts/platform.dart';
import '../core/models/matching.dart';
import '../core/models/playback.dart';
import '../core/sources/source_ids.dart';

// Every group parses with defaults for missing/invalid keys so older or
// newer settings files always load (forward/backward compatible).

T _enum<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    raw is String ? (values.asNameMap()[raw] ?? fallback) : fallback;

double _double(Object? raw, double fallback, {double? min, double? max}) {
  var v = raw is num ? raw.toDouble() : fallback;
  if (v.isNaN) v = fallback;
  if (min != null && v < min) v = min;
  if (max != null && v > max) v = max;
  return v;
}

int _int(Object? raw, int fallback, {int? min, int? max}) {
  var v = raw is num ? raw.toInt() : fallback;
  if (min != null && v < min) v = min;
  if (max != null && v > max) v = max;
  return v;
}

bool _bool(Object? raw, bool fallback) => raw is bool ? raw : fallback;

Map<String, Object?> _map(Object? raw) => raw is Map ? raw.cast<String, Object?>() : const {};

// ---------------------------------------------------------------------------

enum AppThemeMode { dark, light, system }

enum AccentChoice { gold, coral, mint, ice, mono }

enum UiDensity { comfortable, compact }

@immutable
class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = AppThemeMode.dark,
    this.accent = AccentChoice.gold,
    this.liquidGlass = false,
    this.glassIntensity = 0.6,
    this.density = UiDensity.comfortable,
    this.artworkBackdrop = true,
  });

  final AppThemeMode themeMode;
  final AccentChoice accent;

  /// Optional glass-inspired visual mode. Default OFF.
  final bool liquidGlass;

  /// 0..1 — translucency/blur strength when [liquidGlass] is on.
  final double glassIntensity;
  final UiDensity density;

  /// Tinted, blurred artwork behind the now-playing view.
  final bool artworkBackdrop;

  AppearanceSettings copyWith({
    AppThemeMode? themeMode,
    AccentChoice? accent,
    bool? liquidGlass,
    double? glassIntensity,
    UiDensity? density,
    bool? artworkBackdrop,
  }) =>
      AppearanceSettings(
        themeMode: themeMode ?? this.themeMode,
        accent: accent ?? this.accent,
        liquidGlass: liquidGlass ?? this.liquidGlass,
        glassIntensity: glassIntensity ?? this.glassIntensity,
        density: density ?? this.density,
        artworkBackdrop: artworkBackdrop ?? this.artworkBackdrop,
      );

  Map<String, Object?> toJson() => {
        'themeMode': themeMode.name,
        'accent': accent.name,
        'liquidGlass': liquidGlass,
        'glassIntensity': glassIntensity,
        'density': density.name,
        'artworkBackdrop': artworkBackdrop,
      };

  factory AppearanceSettings.fromJson(Map<String, Object?> j) {
    const d = AppearanceSettings();
    return AppearanceSettings(
      themeMode: _enum(AppThemeMode.values, j['themeMode'], d.themeMode),
      accent: _enum(AccentChoice.values, j['accent'], d.accent),
      liquidGlass: _bool(j['liquidGlass'], d.liquidGlass),
      glassIntensity: _double(j['glassIntensity'], d.glassIntensity, min: 0, max: 1),
      density: _enum(UiDensity.values, j['density'], d.density),
      artworkBackdrop: _bool(j['artworkBackdrop'], d.artworkBackdrop),
    );
  }
}

enum NormalizationMode {
  /// ReplayGain track gain from tags (all platforms).
  replayGainTrack,

  /// ReplayGain album gain from tags (all platforms).
  replayGainAlbum,

  /// Real-time EBU R128 loudness normalization (desktop/libmpv only).
  loudness,
}

@immutable
class PlaybackSettings {
  const PlaybackSettings({
    this.crossfadeSeconds = 0,
    this.gapless = true,
    this.normalizeVolume = false,
    this.normalizationMode = NormalizationMode.replayGainTrack,
    this.preampDb = 0,
    this.speed = 1.0,
    this.volume = 1.0,
    this.restoreQueueOnStartup = true,
    this.autoPlayOnStartup = false,
    this.smartQueue = true,
    this.skipUnplayable = true,
    this.previousRestartThresholdSeconds = 3,
    this.outputDeviceId,
    this.pauseOnHeadphonesDisconnect = true,
    this.resumeAfterInterruption = true,
    this.duckOnTransientInterruption = true,
    this.sleepTimerFadeOut = true,
    this.lyricsEnabled = true,
  });

  /// 0 disables crossfade (gapless is then used when enabled).
  final double crossfadeSeconds;
  final bool gapless;
  final bool normalizeVolume;
  final NormalizationMode normalizationMode;
  final double preampDb;
  final double speed;
  final double volume;
  final bool restoreQueueOnStartup;
  final bool autoPlayOnStartup;

  /// Append similar tracks when the queue runs out.
  final bool smartQueue;
  final bool skipUnplayable;
  final int previousRestartThresholdSeconds;

  /// Null = system default output.
  final String? outputDeviceId;
  final bool pauseOnHeadphonesDisconnect;
  final bool resumeAfterInterruption;
  final bool duckOnTransientInterruption;
  final bool sleepTimerFadeOut;
  final bool lyricsEnabled;

  PlaybackSettings copyWith({
    double? crossfadeSeconds,
    bool? gapless,
    bool? normalizeVolume,
    NormalizationMode? normalizationMode,
    double? preampDb,
    double? speed,
    double? volume,
    bool? restoreQueueOnStartup,
    bool? autoPlayOnStartup,
    bool? smartQueue,
    bool? skipUnplayable,
    int? previousRestartThresholdSeconds,
    String? outputDeviceId,
    bool clearOutputDevice = false,
    bool? pauseOnHeadphonesDisconnect,
    bool? resumeAfterInterruption,
    bool? duckOnTransientInterruption,
    bool? sleepTimerFadeOut,
    bool? lyricsEnabled,
  }) =>
      PlaybackSettings(
        crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
        gapless: gapless ?? this.gapless,
        normalizeVolume: normalizeVolume ?? this.normalizeVolume,
        normalizationMode: normalizationMode ?? this.normalizationMode,
        preampDb: preampDb ?? this.preampDb,
        speed: speed ?? this.speed,
        volume: volume ?? this.volume,
        restoreQueueOnStartup: restoreQueueOnStartup ?? this.restoreQueueOnStartup,
        autoPlayOnStartup: autoPlayOnStartup ?? this.autoPlayOnStartup,
        smartQueue: smartQueue ?? this.smartQueue,
        skipUnplayable: skipUnplayable ?? this.skipUnplayable,
        previousRestartThresholdSeconds: previousRestartThresholdSeconds ?? this.previousRestartThresholdSeconds,
        outputDeviceId: clearOutputDevice ? null : (outputDeviceId ?? this.outputDeviceId),
        pauseOnHeadphonesDisconnect: pauseOnHeadphonesDisconnect ?? this.pauseOnHeadphonesDisconnect,
        resumeAfterInterruption: resumeAfterInterruption ?? this.resumeAfterInterruption,
        duckOnTransientInterruption: duckOnTransientInterruption ?? this.duckOnTransientInterruption,
        sleepTimerFadeOut: sleepTimerFadeOut ?? this.sleepTimerFadeOut,
        lyricsEnabled: lyricsEnabled ?? this.lyricsEnabled,
      );

  Map<String, Object?> toJson() => {
        'crossfadeSeconds': crossfadeSeconds,
        'gapless': gapless,
        'normalizeVolume': normalizeVolume,
        'normalizationMode': normalizationMode.name,
        'preampDb': preampDb,
        'speed': speed,
        'volume': volume,
        'restoreQueueOnStartup': restoreQueueOnStartup,
        'autoPlayOnStartup': autoPlayOnStartup,
        'smartQueue': smartQueue,
        'skipUnplayable': skipUnplayable,
        'previousRestartThresholdSeconds': previousRestartThresholdSeconds,
        'outputDeviceId': outputDeviceId,
        'pauseOnHeadphonesDisconnect': pauseOnHeadphonesDisconnect,
        'resumeAfterInterruption': resumeAfterInterruption,
        'duckOnTransientInterruption': duckOnTransientInterruption,
        'sleepTimerFadeOut': sleepTimerFadeOut,
        'lyricsEnabled': lyricsEnabled,
      };

  factory PlaybackSettings.fromJson(Map<String, Object?> j) {
    const d = PlaybackSettings();
    return PlaybackSettings(
      crossfadeSeconds: _double(j['crossfadeSeconds'], d.crossfadeSeconds, min: 0, max: 12),
      gapless: _bool(j['gapless'], d.gapless),
      normalizeVolume: _bool(j['normalizeVolume'], d.normalizeVolume),
      normalizationMode: _enum(NormalizationMode.values, j['normalizationMode'], d.normalizationMode),
      preampDb: _double(j['preampDb'], d.preampDb, min: -12, max: 12),
      speed: _double(j['speed'], d.speed, min: 0.5, max: 2.0),
      volume: _double(j['volume'], d.volume, min: 0, max: 1),
      restoreQueueOnStartup: _bool(j['restoreQueueOnStartup'], d.restoreQueueOnStartup),
      autoPlayOnStartup: _bool(j['autoPlayOnStartup'], d.autoPlayOnStartup),
      smartQueue: _bool(j['smartQueue'], d.smartQueue),
      skipUnplayable: _bool(j['skipUnplayable'], d.skipUnplayable),
      previousRestartThresholdSeconds:
          _int(j['previousRestartThresholdSeconds'], d.previousRestartThresholdSeconds, min: 0, max: 15),
      outputDeviceId: j['outputDeviceId'] as String?,
      pauseOnHeadphonesDisconnect: _bool(j['pauseOnHeadphonesDisconnect'], d.pauseOnHeadphonesDisconnect),
      resumeAfterInterruption: _bool(j['resumeAfterInterruption'], d.resumeAfterInterruption),
      duckOnTransientInterruption: _bool(j['duckOnTransientInterruption'], d.duckOnTransientInterruption),
      sleepTimerFadeOut: _bool(j['sleepTimerFadeOut'], d.sleepTimerFadeOut),
      lyricsEnabled: _bool(j['lyricsEnabled'], d.lyricsEnabled),
    );
  }
}

@immutable
class AudioQualitySettings {
  const AudioQualitySettings({
    this.streaming = AudioQuality.high,
    this.mobileStreaming = AudioQuality.normal,
    this.download = AudioQuality.high,
  });

  final AudioQuality streaming;

  /// Used on metered/mobile connections.
  final AudioQuality mobileStreaming;
  final AudioQuality download;

  AudioQualitySettings copyWith({AudioQuality? streaming, AudioQuality? mobileStreaming, AudioQuality? download}) =>
      AudioQualitySettings(
        streaming: streaming ?? this.streaming,
        mobileStreaming: mobileStreaming ?? this.mobileStreaming,
        download: download ?? this.download,
      );

  Map<String, Object?> toJson() =>
      {'streaming': streaming.name, 'mobileStreaming': mobileStreaming.name, 'download': download.name};

  factory AudioQualitySettings.fromJson(Map<String, Object?> j) {
    const d = AudioQualitySettings();
    return AudioQualitySettings(
      streaming: _enum(AudioQuality.values, j['streaming'], d.streaming),
      mobileStreaming: _enum(AudioQuality.values, j['mobileStreaming'], d.mobileStreaming),
      download: _enum(AudioQuality.values, j['download'], d.download),
    );
  }
}

@immutable
class DownloadSettings {
  const DownloadSettings({
    this.directory,
    this.wifiOnly = true,
    this.maxConcurrent = 2,
    this.warnOnMobileData = true,
    this.notifyOnComplete = true,
    this.verifyIntegrity = true,
  });

  /// Null = platform default (see `AppPaths.defaultDownloadDir`).
  final String? directory;
  final bool wifiOnly;
  final int maxConcurrent;
  final bool warnOnMobileData;
  final bool notifyOnComplete;
  final bool verifyIntegrity;

  DownloadSettings copyWith({
    String? directory,
    bool clearDirectory = false,
    bool? wifiOnly,
    int? maxConcurrent,
    bool? warnOnMobileData,
    bool? notifyOnComplete,
    bool? verifyIntegrity,
  }) =>
      DownloadSettings(
        directory: clearDirectory ? null : (directory ?? this.directory),
        wifiOnly: wifiOnly ?? this.wifiOnly,
        maxConcurrent: maxConcurrent ?? this.maxConcurrent,
        warnOnMobileData: warnOnMobileData ?? this.warnOnMobileData,
        notifyOnComplete: notifyOnComplete ?? this.notifyOnComplete,
        verifyIntegrity: verifyIntegrity ?? this.verifyIntegrity,
      );

  Map<String, Object?> toJson() => {
        'directory': directory,
        'wifiOnly': wifiOnly,
        'maxConcurrent': maxConcurrent,
        'warnOnMobileData': warnOnMobileData,
        'notifyOnComplete': notifyOnComplete,
        'verifyIntegrity': verifyIntegrity,
      };

  factory DownloadSettings.fromJson(Map<String, Object?> j) {
    const d = DownloadSettings();
    return DownloadSettings(
      directory: j['directory'] as String?,
      wifiOnly: _bool(j['wifiOnly'], d.wifiOnly),
      maxConcurrent: _int(j['maxConcurrent'], d.maxConcurrent, min: 1, max: 6),
      warnOnMobileData: _bool(j['warnOnMobileData'], d.warnOnMobileData),
      notifyOnComplete: _bool(j['notifyOnComplete'], d.notifyOnComplete),
      verifyIntegrity: _bool(j['verifyIntegrity'], d.verifyIntegrity),
    );
  }
}

@immutable
class StorageSettings {
  const StorageSettings({this.downloadLimitMb = 0, this.artworkCacheMb = 300, this.autoCleanup = true});

  /// 0 = unlimited.
  final int downloadLimitMb;
  final int artworkCacheMb;

  /// Remove least-recently-played downloads when over the limit.
  final bool autoCleanup;

  StorageSettings copyWith({int? downloadLimitMb, int? artworkCacheMb, bool? autoCleanup}) => StorageSettings(
        downloadLimitMb: downloadLimitMb ?? this.downloadLimitMb,
        artworkCacheMb: artworkCacheMb ?? this.artworkCacheMb,
        autoCleanup: autoCleanup ?? this.autoCleanup,
      );

  Map<String, Object?> toJson() =>
      {'downloadLimitMb': downloadLimitMb, 'artworkCacheMb': artworkCacheMb, 'autoCleanup': autoCleanup};

  factory StorageSettings.fromJson(Map<String, Object?> j) {
    const d = StorageSettings();
    return StorageSettings(
      downloadLimitMb: _int(j['downloadLimitMb'], d.downloadLimitMb, min: 0),
      artworkCacheMb: _int(j['artworkCacheMb'], d.artworkCacheMb, min: 20, max: 5000),
      autoCleanup: _bool(j['autoCleanup'], d.autoCleanup),
    );
  }
}

enum PerformanceMode { balanced, performance, batterySaver, dataSaver, visualQuality, custom }

enum AnimationLevel { full, reduced, off }

enum ArtworkQuality { low, medium, high }

@immutable
class PerformanceSettings {
  const PerformanceSettings({
    this.mode = PerformanceMode.balanced,
    this.animations = AnimationLevel.full,
    this.blur = true,
    this.artworkQuality = ArtworkQuality.medium,
    this.preloadNext = true,
    this.prefetchArtwork = true,
    this.backgroundSync = true,
    this.syncIntervalMinutes = 60,
  });

  final PerformanceMode mode;
  final AnimationLevel animations;

  /// Background blur (glass, now-playing backdrop).
  final bool blur;
  final ArtworkQuality artworkQuality;

  /// Preload/buffer the next track ahead of time.
  final bool preloadNext;
  final bool prefetchArtwork;

  /// Periodic refresh of connected services, auto-download sync, discovery.
  final bool backgroundSync;
  final int syncIntervalMinutes;

  PerformanceSettings copyWith({
    PerformanceMode? mode,
    AnimationLevel? animations,
    bool? blur,
    ArtworkQuality? artworkQuality,
    bool? preloadNext,
    bool? prefetchArtwork,
    bool? backgroundSync,
    int? syncIntervalMinutes,
  }) =>
      PerformanceSettings(
        mode: mode ?? this.mode,
        animations: animations ?? this.animations,
        blur: blur ?? this.blur,
        artworkQuality: artworkQuality ?? this.artworkQuality,
        preloadNext: preloadNext ?? this.preloadNext,
        prefetchArtwork: prefetchArtwork ?? this.prefetchArtwork,
        backgroundSync: backgroundSync ?? this.backgroundSync,
        syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      );

  Map<String, Object?> toJson() => {
        'mode': mode.name,
        'animations': animations.name,
        'blur': blur,
        'artworkQuality': artworkQuality.name,
        'preloadNext': preloadNext,
        'prefetchArtwork': prefetchArtwork,
        'backgroundSync': backgroundSync,
        'syncIntervalMinutes': syncIntervalMinutes,
      };

  factory PerformanceSettings.fromJson(Map<String, Object?> j) {
    const d = PerformanceSettings();
    return PerformanceSettings(
      mode: _enum(PerformanceMode.values, j['mode'], d.mode),
      animations: _enum(AnimationLevel.values, j['animations'], d.animations),
      blur: _bool(j['blur'], d.blur),
      artworkQuality: _enum(ArtworkQuality.values, j['artworkQuality'], d.artworkQuality),
      preloadNext: _bool(j['preloadNext'], d.preloadNext),
      prefetchArtwork: _bool(j['prefetchArtwork'], d.prefetchArtwork),
      backgroundSync: _bool(j['backgroundSync'], d.backgroundSync),
      syncIntervalMinutes: _int(j['syncIntervalMinutes'], d.syncIntervalMinutes, min: 15, max: 24 * 60),
    );
  }
}

@immutable
class ServicesSettings {
  const ServicesSettings({
    this.providerOrder = SourceIds.defaultPreference,
    this.disabledSources = const {},
    this.preferSoundCloudInDiscovery = true,
  });

  /// Preference order used for search result ordering, stream fallback and
  /// matching targets.
  final List<String> providerOrder;
  final Set<String> disabledSources;
  final bool preferSoundCloudInDiscovery;

  ServicesSettings copyWith({List<String>? providerOrder, Set<String>? disabledSources, bool? preferSoundCloudInDiscovery}) =>
      ServicesSettings(
        providerOrder: providerOrder ?? this.providerOrder,
        disabledSources: disabledSources ?? this.disabledSources,
        preferSoundCloudInDiscovery: preferSoundCloudInDiscovery ?? this.preferSoundCloudInDiscovery,
      );

  Map<String, Object?> toJson() => {
        'providerOrder': providerOrder,
        'disabledSources': disabledSources.toList(),
        'preferSoundCloudInDiscovery': preferSoundCloudInDiscovery,
      };

  factory ServicesSettings.fromJson(Map<String, Object?> j) {
    const d = ServicesSettings();
    final order = (j['providerOrder'] is List) ? (j['providerOrder'] as List).whereType<String>().toList() : d.providerOrder;
    // Make sure newly added built-in sources appear in the order.
    for (final id in SourceIds.defaultPreference) {
      if (!order.contains(id)) order.add(id);
    }
    return ServicesSettings(
      providerOrder: order,
      disabledSources:
          (j['disabledSources'] is List) ? (j['disabledSources'] as List).whereType<String>().toSet() : d.disabledSources,
      preferSoundCloudInDiscovery: _bool(j['preferSoundCloudInDiscovery'], d.preferSoundCloudInDiscovery),
    );
  }
}

@immutable
class ImportSettings {
  const ImportSettings({
    this.reviewMode = ReviewMode.autoAcceptHigh,
    this.autoAcceptThreshold = 0.88,
    this.skipUnavailable = false,
    this.preferredSource = SourceIds.soundcloud,
    this.allowPreviewOnly = false,
  });

  final ReviewMode reviewMode;
  final double autoAcceptThreshold;
  final bool skipUnavailable;
  final String? preferredSource;
  final bool allowPreviewOnly;

  ImportSettings copyWith({
    ReviewMode? reviewMode,
    double? autoAcceptThreshold,
    bool? skipUnavailable,
    String? preferredSource,
    bool? allowPreviewOnly,
  }) =>
      ImportSettings(
        reviewMode: reviewMode ?? this.reviewMode,
        autoAcceptThreshold: autoAcceptThreshold ?? this.autoAcceptThreshold,
        skipUnavailable: skipUnavailable ?? this.skipUnavailable,
        preferredSource: preferredSource ?? this.preferredSource,
        allowPreviewOnly: allowPreviewOnly ?? this.allowPreviewOnly,
      );

  Map<String, Object?> toJson() => {
        'reviewMode': reviewMode.name,
        'autoAcceptThreshold': autoAcceptThreshold,
        'skipUnavailable': skipUnavailable,
        'preferredSource': preferredSource,
        'allowPreviewOnly': allowPreviewOnly,
      };

  factory ImportSettings.fromJson(Map<String, Object?> j) {
    const d = ImportSettings();
    return ImportSettings(
      reviewMode: _enum(ReviewMode.values, j['reviewMode'], d.reviewMode),
      autoAcceptThreshold: _double(j['autoAcceptThreshold'], d.autoAcceptThreshold, min: 0.6, max: 1.0),
      skipUnavailable: _bool(j['skipUnavailable'], d.skipUnavailable),
      preferredSource: j.containsKey('preferredSource') ? j['preferredSource'] as String? : d.preferredSource,
      allowPreviewOnly: _bool(j['allowPreviewOnly'], d.allowPreviewOnly),
    );
  }
}

@immutable
class NotificationSettings {
  const NotificationSettings({this.trackChange = false, this.downloads = true});

  /// Desktop toast when the track changes.
  final bool trackChange;
  final bool downloads;

  NotificationSettings copyWith({bool? trackChange, bool? downloads}) =>
      NotificationSettings(trackChange: trackChange ?? this.trackChange, downloads: downloads ?? this.downloads);

  Map<String, Object?> toJson() => {'trackChange': trackChange, 'downloads': downloads};

  factory NotificationSettings.fromJson(Map<String, Object?> j) {
    const d = NotificationSettings();
    return NotificationSettings(trackChange: _bool(j['trackChange'], d.trackChange), downloads: _bool(j['downloads'], d.downloads));
  }
}

@immutable
class DesktopSettings {
  const DesktopSettings({
    this.closeBehavior = CloseBehavior.minimizeToTray,
    this.showTrayIcon = true,
    this.launchAtLogin = false,
    this.startMinimized = false,
    this.rememberWindowBounds = true,
  });

  final CloseBehavior closeBehavior;
  final bool showTrayIcon;
  final bool launchAtLogin;
  final bool startMinimized;
  final bool rememberWindowBounds;

  DesktopSettings copyWith({
    CloseBehavior? closeBehavior,
    bool? showTrayIcon,
    bool? launchAtLogin,
    bool? startMinimized,
    bool? rememberWindowBounds,
  }) =>
      DesktopSettings(
        closeBehavior: closeBehavior ?? this.closeBehavior,
        showTrayIcon: showTrayIcon ?? this.showTrayIcon,
        launchAtLogin: launchAtLogin ?? this.launchAtLogin,
        startMinimized: startMinimized ?? this.startMinimized,
        rememberWindowBounds: rememberWindowBounds ?? this.rememberWindowBounds,
      );

  Map<String, Object?> toJson() => {
        'closeBehavior': closeBehavior.name,
        'showTrayIcon': showTrayIcon,
        'launchAtLogin': launchAtLogin,
        'startMinimized': startMinimized,
        'rememberWindowBounds': rememberWindowBounds,
      };

  factory DesktopSettings.fromJson(Map<String, Object?> j) {
    const d = DesktopSettings();
    return DesktopSettings(
      closeBehavior: _enum(CloseBehavior.values, j['closeBehavior'], d.closeBehavior),
      showTrayIcon: _bool(j['showTrayIcon'], d.showTrayIcon),
      launchAtLogin: _bool(j['launchAtLogin'], d.launchAtLogin),
      startMinimized: _bool(j['startMinimized'], d.startMinimized),
      rememberWindowBounds: _bool(j['rememberWindowBounds'], d.rememberWindowBounds),
    );
  }
}

@immutable
class AndroidSettings {
  const AndroidSettings({this.stopForegroundOnPause = true, this.resumeOnHeadsetConnect = false});

  /// When paused the notification can be swiped away and the service may be
  /// stopped by the OS. Off = keep the foreground service while paused.
  final bool stopForegroundOnPause;

  /// Resume when a headset/Bluetooth device connects (best effort).
  final bool resumeOnHeadsetConnect;

  AndroidSettings copyWith({bool? stopForegroundOnPause, bool? resumeOnHeadsetConnect}) => AndroidSettings(
        stopForegroundOnPause: stopForegroundOnPause ?? this.stopForegroundOnPause,
        resumeOnHeadsetConnect: resumeOnHeadsetConnect ?? this.resumeOnHeadsetConnect,
      );

  Map<String, Object?> toJson() =>
      {'stopForegroundOnPause': stopForegroundOnPause, 'resumeOnHeadsetConnect': resumeOnHeadsetConnect};

  factory AndroidSettings.fromJson(Map<String, Object?> j) {
    const d = AndroidSettings();
    return AndroidSettings(
      stopForegroundOnPause: _bool(j['stopForegroundOnPause'], d.stopForegroundOnPause),
      resumeOnHeadsetConnect: _bool(j['resumeOnHeadsetConnect'], d.resumeOnHeadsetConnect),
    );
  }
}

/// Action ids for keyboard shortcuts. In-app shortcuts and global (system
/// wide) hotkeys share the format `ctrl+alt+space` (modifiers: ctrl, alt,
/// shift, meta; keys: letters, digits, space, left, right, up, down, f1..f12,
/// mediaPlayPause, mediaNext, mediaPrevious, mediaStop).
abstract final class ShortcutActions {
  static const playPause = 'playPause';
  static const next = 'next';
  static const previous = 'previous';
  static const seekForward = 'seekForward';
  static const seekBackward = 'seekBackward';
  static const volumeUp = 'volumeUp';
  static const volumeDown = 'volumeDown';
  static const toggleShuffle = 'toggleShuffle';
  static const cycleRepeat = 'cycleRepeat';
  static const like = 'like';
  static const search = 'search';
  static const commandPalette = 'commandPalette';
  static const nowPlaying = 'nowPlaying';
  static const queue = 'queue';
  static const settings = 'settings';

  static const globalPlayPause = 'global.playPause';
  static const globalNext = 'global.next';
  static const globalPrevious = 'global.previous';
  static const globalShowWindow = 'global.showWindow';

  static const defaults = <String, String>{
    playPause: 'space',
    next: 'ctrl+right',
    previous: 'ctrl+left',
    seekForward: 'shift+right',
    seekBackward: 'shift+left',
    volumeUp: 'ctrl+up',
    volumeDown: 'ctrl+down',
    toggleShuffle: 'ctrl+s',
    cycleRepeat: 'ctrl+r',
    like: 'ctrl+l',
    search: 'ctrl+f',
    commandPalette: 'ctrl+k',
    nowPlaying: 'ctrl+p',
    queue: 'ctrl+q',
    settings: 'ctrl+comma',
    globalPlayPause: 'ctrl+alt+space',
    globalNext: 'ctrl+alt+right',
    globalPrevious: 'ctrl+alt+left',
    globalShowWindow: 'ctrl+alt+f',
  };

  static bool isGlobal(String action) => action.startsWith('global.');
}

@immutable
class ShortcutSettings {
  const ShortcutSettings({this.globalHotkeysEnabled = true, this.bindings = ShortcutActions.defaults});

  final bool globalHotkeysEnabled;

  /// action id -> accelerator. Missing actions fall back to defaults.
  final Map<String, String> bindings;

  String? bindingFor(String action) => bindings[action] ?? ShortcutActions.defaults[action];

  ShortcutSettings copyWith({bool? globalHotkeysEnabled, Map<String, String>? bindings}) => ShortcutSettings(
        globalHotkeysEnabled: globalHotkeysEnabled ?? this.globalHotkeysEnabled,
        bindings: bindings ?? this.bindings,
      );

  Map<String, Object?> toJson() => {'globalHotkeysEnabled': globalHotkeysEnabled, 'bindings': bindings};

  factory ShortcutSettings.fromJson(Map<String, Object?> j) {
    const d = ShortcutSettings();
    final raw = _map(j['bindings']);
    return ShortcutSettings(
      globalHotkeysEnabled: _bool(j['globalHotkeysEnabled'], d.globalHotkeysEnabled),
      bindings: {
        ...ShortcutActions.defaults,
        for (final e in raw.entries)
          if (e.value is String) e.key: e.value as String,
      },
    );
  }
}

@immutable
class PrivacySettings {
  const PrivacySettings({
    this.recordHistory = true,
    this.personalizedRecommendations = true,
    this.saveSearchHistory = true,
  });

  final bool recordHistory;
  final bool personalizedRecommendations;
  final bool saveSearchHistory;

  PrivacySettings copyWith({bool? recordHistory, bool? personalizedRecommendations, bool? saveSearchHistory}) =>
      PrivacySettings(
        recordHistory: recordHistory ?? this.recordHistory,
        personalizedRecommendations: personalizedRecommendations ?? this.personalizedRecommendations,
        saveSearchHistory: saveSearchHistory ?? this.saveSearchHistory,
      );

  Map<String, Object?> toJson() => {
        'recordHistory': recordHistory,
        'personalizedRecommendations': personalizedRecommendations,
        'saveSearchHistory': saveSearchHistory,
      };

  factory PrivacySettings.fromJson(Map<String, Object?> j) {
    const d = PrivacySettings();
    return PrivacySettings(
      recordHistory: _bool(j['recordHistory'], d.recordHistory),
      personalizedRecommendations: _bool(j['personalizedRecommendations'], d.personalizedRecommendations),
      saveSearchHistory: _bool(j['saveSearchHistory'], d.saveSearchHistory),
    );
  }
}

enum MotionPreference { system, reduce, full }

@immutable
class AccessibilitySettings {
  const AccessibilitySettings({
    this.motion = MotionPreference.system,
    this.highContrast = false,
    this.textScale = 1.0,
    this.largerTargets = false,
  });

  final MotionPreference motion;
  final bool highContrast;
  final double textScale;
  final bool largerTargets;

  AccessibilitySettings copyWith({MotionPreference? motion, bool? highContrast, double? textScale, bool? largerTargets}) =>
      AccessibilitySettings(
        motion: motion ?? this.motion,
        highContrast: highContrast ?? this.highContrast,
        textScale: textScale ?? this.textScale,
        largerTargets: largerTargets ?? this.largerTargets,
      );

  Map<String, Object?> toJson() =>
      {'motion': motion.name, 'highContrast': highContrast, 'textScale': textScale, 'largerTargets': largerTargets};

  factory AccessibilitySettings.fromJson(Map<String, Object?> j) {
    const d = AccessibilitySettings();
    return AccessibilitySettings(
      motion: _enum(MotionPreference.values, j['motion'], d.motion),
      highContrast: _bool(j['highContrast'], d.highContrast),
      textScale: _double(j['textScale'], d.textScale, min: 0.8, max: 1.6),
      largerTargets: _bool(j['largerTargets'], d.largerTargets),
    );
  }
}

@immutable
class UpdateSettings {
  const UpdateSettings({this.checkForUpdates = false});

  /// Opt-in: queries the project's GitHub Releases once per day.
  final bool checkForUpdates;

  UpdateSettings copyWith({bool? checkForUpdates}) =>
      UpdateSettings(checkForUpdates: checkForUpdates ?? this.checkForUpdates);

  Map<String, Object?> toJson() => {'checkForUpdates': checkForUpdates};

  factory UpdateSettings.fromJson(Map<String, Object?> j) =>
      UpdateSettings(checkForUpdates: _bool(j['checkForUpdates'], false));
}

enum SettingsSection {
  appearance,
  playback,
  audioQuality,
  downloads,
  storage,
  performance,
  services,
  import,
  notifications,
  desktop,
  android,
  shortcuts,
  privacy,
  language,
  accessibility,
  updates,
}

/// All persisted, user-facing settings.
@immutable
class AppSettings {
  const AppSettings({
    this.appearance = const AppearanceSettings(),
    this.playback = const PlaybackSettings(),
    this.audioQuality = const AudioQualitySettings(),
    this.downloads = const DownloadSettings(),
    this.storage = const StorageSettings(),
    this.performance = const PerformanceSettings(),
    this.services = const ServicesSettings(),
    this.import = const ImportSettings(),
    this.notifications = const NotificationSettings(),
    this.desktop = const DesktopSettings(),
    this.android = const AndroidSettings(),
    this.shortcuts = const ShortcutSettings(),
    this.privacy = const PrivacySettings(),
    this.accessibility = const AccessibilitySettings(),
    this.updates = const UpdateSettings(),
    this.localeCode,
    this.onboardingCompleted = false,
  });

  static const schemaVersion = 1;

  final AppearanceSettings appearance;
  final PlaybackSettings playback;
  final AudioQualitySettings audioQuality;
  final DownloadSettings downloads;
  final StorageSettings storage;
  final PerformanceSettings performance;
  final ServicesSettings services;
  final ImportSettings import;
  final NotificationSettings notifications;
  final DesktopSettings desktop;
  final AndroidSettings android;
  final ShortcutSettings shortcuts;
  final PrivacySettings privacy;
  final AccessibilitySettings accessibility;
  final UpdateSettings updates;

  /// Null = follow the system language (falls back to English).
  final String? localeCode;
  final bool onboardingCompleted;

  AppSettings copyWith({
    AppearanceSettings? appearance,
    PlaybackSettings? playback,
    AudioQualitySettings? audioQuality,
    DownloadSettings? downloads,
    StorageSettings? storage,
    PerformanceSettings? performance,
    ServicesSettings? services,
    ImportSettings? import,
    NotificationSettings? notifications,
    DesktopSettings? desktop,
    AndroidSettings? android,
    ShortcutSettings? shortcuts,
    PrivacySettings? privacy,
    AccessibilitySettings? accessibility,
    UpdateSettings? updates,
    String? localeCode,
    bool clearLocale = false,
    bool? onboardingCompleted,
  }) =>
      AppSettings(
        appearance: appearance ?? this.appearance,
        playback: playback ?? this.playback,
        audioQuality: audioQuality ?? this.audioQuality,
        downloads: downloads ?? this.downloads,
        storage: storage ?? this.storage,
        performance: performance ?? this.performance,
        services: services ?? this.services,
        import: import ?? this.import,
        notifications: notifications ?? this.notifications,
        desktop: desktop ?? this.desktop,
        android: android ?? this.android,
        shortcuts: shortcuts ?? this.shortcuts,
        privacy: privacy ?? this.privacy,
        accessibility: accessibility ?? this.accessibility,
        updates: updates ?? this.updates,
        localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      );

  /// Reset one section to defaults.
  AppSettings resetSection(SettingsSection section) {
    const d = AppSettings();
    return switch (section) {
      SettingsSection.appearance => copyWith(appearance: d.appearance),
      SettingsSection.playback => copyWith(playback: d.playback),
      SettingsSection.audioQuality => copyWith(audioQuality: d.audioQuality),
      SettingsSection.downloads => copyWith(downloads: d.downloads),
      SettingsSection.storage => copyWith(storage: d.storage),
      SettingsSection.performance => copyWith(performance: d.performance),
      SettingsSection.services => copyWith(services: d.services),
      SettingsSection.import => copyWith(import: d.import),
      SettingsSection.notifications => copyWith(notifications: d.notifications),
      SettingsSection.desktop => copyWith(desktop: d.desktop),
      SettingsSection.android => copyWith(android: d.android),
      SettingsSection.shortcuts => copyWith(shortcuts: d.shortcuts),
      SettingsSection.privacy => copyWith(privacy: d.privacy),
      SettingsSection.language => copyWith(clearLocale: true),
      SettingsSection.accessibility => copyWith(accessibility: d.accessibility),
      SettingsSection.updates => copyWith(updates: d.updates),
    };
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'appearance': appearance.toJson(),
        'playback': playback.toJson(),
        'audioQuality': audioQuality.toJson(),
        'downloads': downloads.toJson(),
        'storage': storage.toJson(),
        'performance': performance.toJson(),
        'services': services.toJson(),
        'import': import.toJson(),
        'notifications': notifications.toJson(),
        'desktop': desktop.toJson(),
        'android': android.toJson(),
        'shortcuts': shortcuts.toJson(),
        'privacy': privacy.toJson(),
        'accessibility': accessibility.toJson(),
        'updates': updates.toJson(),
        'localeCode': localeCode,
        'onboardingCompleted': onboardingCompleted,
      };

  factory AppSettings.fromJson(Map<String, Object?> j) => AppSettings(
        appearance: AppearanceSettings.fromJson(_map(j['appearance'])),
        playback: PlaybackSettings.fromJson(_map(j['playback'])),
        audioQuality: AudioQualitySettings.fromJson(_map(j['audioQuality'])),
        downloads: DownloadSettings.fromJson(_map(j['downloads'])),
        storage: StorageSettings.fromJson(_map(j['storage'])),
        performance: PerformanceSettings.fromJson(_map(j['performance'])),
        services: ServicesSettings.fromJson(_map(j['services'])),
        import: ImportSettings.fromJson(_map(j['import'])),
        notifications: NotificationSettings.fromJson(_map(j['notifications'])),
        desktop: DesktopSettings.fromJson(_map(j['desktop'])),
        android: AndroidSettings.fromJson(_map(j['android'])),
        shortcuts: ShortcutSettings.fromJson(_map(j['shortcuts'])),
        privacy: PrivacySettings.fromJson(_map(j['privacy'])),
        accessibility: AccessibilitySettings.fromJson(_map(j['accessibility'])),
        updates: UpdateSettings.fromJson(_map(j['updates'])),
        localeCode: j['localeCode'] is String ? j['localeCode'] as String : null,
        onboardingCompleted: _bool(j['onboardingCompleted'], false),
      );
}
