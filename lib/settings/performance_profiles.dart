import '../core/models/playback.dart';
import 'app_settings.dart';

/// A single concrete effect of a performance mode, shown in Settings so the
/// user can see exactly what a mode changes. No mode claims measured gains.
class ProfileEffect {
  const ProfileEffect(this.settingKey, this.valueLabel);

  /// Localization key of the affected setting (e.g. `settingAnimations`).
  final String settingKey;

  /// Raw value label (enum name / bool / number) — localized by the UI.
  final String valueLabel;
}

/// Applies a [PerformanceMode] preset. Changing any granular performance
/// setting afterwards switches the mode to [PerformanceMode.custom].
abstract final class PerformanceProfiles {
  static AppSettings apply(AppSettings s, PerformanceMode mode) {
    final p = s.performance;
    switch (mode) {
      case PerformanceMode.balanced:
        return s.copyWith(
          performance: p.copyWith(
            mode: mode,
            animations: AnimationLevel.full,
            blur: true,
            artworkQuality: ArtworkQuality.medium,
            preloadNext: true,
            prefetchArtwork: true,
            backgroundSync: true,
            syncIntervalMinutes: 60,
          ),
        );
      case PerformanceMode.performance:
        return s.copyWith(
          performance: p.copyWith(
            mode: mode,
            animations: AnimationLevel.reduced,
            blur: false,
            artworkQuality: ArtworkQuality.medium,
            preloadNext: true,
            prefetchArtwork: false,
            backgroundSync: true,
            syncIntervalMinutes: 120,
          ),
        );
      case PerformanceMode.batterySaver:
        return s.copyWith(
          performance: p.copyWith(
            mode: mode,
            animations: AnimationLevel.off,
            blur: false,
            artworkQuality: ArtworkQuality.low,
            preloadNext: false,
            prefetchArtwork: false,
            backgroundSync: false,
            syncIntervalMinutes: 360,
          ),
        );
      case PerformanceMode.dataSaver:
        return s.copyWith(
          performance: p.copyWith(
            mode: mode,
            artworkQuality: ArtworkQuality.low,
            preloadNext: false,
            prefetchArtwork: false,
            backgroundSync: false,
            syncIntervalMinutes: 360,
          ),
          audioQuality: s.audioQuality.copyWith(streaming: AudioQuality.low, mobileStreaming: AudioQuality.low),
          downloads: s.downloads.copyWith(wifiOnly: true, warnOnMobileData: true),
        );
      case PerformanceMode.visualQuality:
        return s.copyWith(
          performance: p.copyWith(
            mode: mode,
            animations: AnimationLevel.full,
            blur: true,
            artworkQuality: ArtworkQuality.high,
            preloadNext: true,
            prefetchArtwork: true,
            backgroundSync: true,
            syncIntervalMinutes: 60,
          ),
        );
      case PerformanceMode.custom:
        return s.copyWith(performance: p.copyWith(mode: PerformanceMode.custom));
    }
  }

  /// Effects for the Settings explanation list.
  static List<ProfileEffect> effectsOf(PerformanceMode mode) {
    final s = apply(const AppSettings(), mode);
    final p = s.performance;
    return [
      ProfileEffect('settingAnimations', p.animations.name),
      ProfileEffect('settingBlur', p.blur.toString()),
      ProfileEffect('settingArtworkQuality', p.artworkQuality.name),
      ProfileEffect('settingPreloadNext', p.preloadNext.toString()),
      ProfileEffect('settingPrefetchArtwork', p.prefetchArtwork.toString()),
      ProfileEffect('settingBackgroundSync', p.backgroundSync.toString()),
      if (mode == PerformanceMode.dataSaver) ...[
        ProfileEffect('settingStreamingQuality', s.audioQuality.streaming.name),
        ProfileEffect('settingWifiOnly', s.downloads.wifiOnly.toString()),
      ],
    ];
  }

  /// Use after a granular performance change made by the user.
  static AppSettings markCustom(AppSettings s) =>
      s.performance.mode == PerformanceMode.custom ? s : s.copyWith(performance: s.performance.copyWith(mode: PerformanceMode.custom));
}

/// Derived values combining settings with platform and OS accessibility
/// preferences. Widgets should read these, not raw settings.
class EffectiveVisuals {
  const EffectiveVisuals({
    required this.animate,
    required this.reducedMotion,
    required this.blur,
    required this.glass,
    required this.glassIntensity,
    required this.artworkQuality,
  });

  factory EffectiveVisuals.from(AppSettings s, {required bool systemReduceMotion, required bool platformSupportsBlur}) {
    final reduced = switch (s.accessibility.motion) {
      MotionPreference.reduce => true,
      MotionPreference.full => false,
      MotionPreference.system => systemReduceMotion,
    };
    final animations = s.performance.animations;
    final blur = s.performance.blur && platformSupportsBlur;
    return EffectiveVisuals(
      animate: animations != AnimationLevel.off && !reduced,
      reducedMotion: reduced || animations == AnimationLevel.reduced,
      blur: blur,
      // Glass still renders without blur (translucent fallback).
      glass: s.appearance.liquidGlass,
      glassIntensity: s.appearance.glassIntensity,
      artworkQuality: s.performance.artworkQuality,
    );
  }

  final bool animate;
  final bool reducedMotion;
  final bool blur;
  final bool glass;
  final double glassIntensity;
  final ArtworkQuality artworkQuality;

  /// Standard animation duration scaled by preference.
  Duration duration(Duration base) {
    if (!animate) return Duration.zero;
    if (reducedMotion) return base * 0.5;
    return base;
  }

  /// Pixel size to request for artwork displayed at [logicalSize].
  int artworkPixels(double logicalSize, double devicePixelRatio) {
    final factor = switch (artworkQuality) {
      ArtworkQuality.low => 0.75,
      ArtworkQuality.medium => 1.0,
      ArtworkQuality.high => 1.5,
    };
    return (logicalSize * devicePixelRatio * factor).clamp(64, 1400).round();
  }
}
