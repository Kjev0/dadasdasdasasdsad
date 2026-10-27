import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/models/playback.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../settings/app_settings.dart';
import '../../../design/context_ext.dart';
import '../widgets/section_frame.dart';
import '../widgets/setting_tiles.dart';

String _seconds(AppLocalizations l10n, double v) => v <= 0 ? l10n.settingsOff : l10n.settingsSecondsShort(v.round());

/// Settings → Playback.
class PlaybackSection extends ConsumerWidget {
  const PlaybackSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = ref.watch(settingsProvider.select((s) => s.playback));
    final platform = ref.watch(platformInfoProvider);
    final controller = ref.watch(playbackProvider);
    Future<void> set(PlaybackSettings Function(PlaybackSettings p) change) =>
        updateSettings(ref, (s) => s.copyWith(playback: change(s.playback)));
    final crossfading = p.crossfadeSeconds > 0;

    return SectionFrame(
      title: l10n.shellSectionPlayback,
      showHeading: showHeading,
      onRestoreDefaults: () async {
        const d = PlaybackSettings();
        await updateSettings(
          ref,
          (s) => s.copyWith(
            playback: d.copyWith(volume: s.playback.volume, outputDeviceId: s.playback.outputDeviceId),
          ),
        );
        if (controller.supportsSpeed) await controller.setSpeed(d.speed);
      },
      children: [
        SettingsGroup(title: l10n.settingsTransitionsGroup, children: [
          SettingSlider(
            key: const ValueKey('setting.crossfade'),
            title: l10n.settingsCrossfade,
            subtitle: l10n.settingsCrossfadeHint,
            value: p.crossfadeSeconds,
            min: 0,
            max: 12,
            divisions: 12,
            format: (v) => _seconds(l10n, v),
            onChanged: (v) => set((p) => p.copyWith(crossfadeSeconds: v.roundToDouble())),
          ),
          SettingSwitch(
            key: const ValueKey('setting.gapless'),
            title: l10n.settingsGapless,
            subtitle: l10n.settingsGaplessHint,
            value: p.gapless,
            disabledReason: l10n.settingsGaplessCrossfadeNote,
            onChanged: crossfading ? null : (v) => set((p) => p.copyWith(gapless: v)),
          ),
          SettingSlider(
            key: const ValueKey('setting.previousThreshold'),
            title: l10n.settingsPreviousThreshold,
            subtitle: p.previousRestartThresholdSeconds == 0
                ? l10n.settingsPreviousThresholdAlways
                : l10n.settingsPreviousThresholdHint(p.previousRestartThresholdSeconds),
            value: p.previousRestartThresholdSeconds.toDouble(),
            min: 0,
            max: 15,
            divisions: 15,
            format: (v) => _seconds(l10n, v),
            onChanged: (v) => set((p) => p.copyWith(previousRestartThresholdSeconds: v.round())),
          ),
        ]),
        SettingsGroup(title: l10n.settingsVolumeGroup, children: [
          SettingSwitch(
            key: const ValueKey('setting.normalize'),
            title: l10n.settingsNormalize,
            subtitle: l10n.settingsNormalizeHint,
            value: p.normalizeVolume,
            onChanged: (v) => set((p) => p.copyWith(normalizeVolume: v)),
          ),
          SettingChoice<NormalizationMode>(
            key: const ValueKey('setting.normalizationMode'),
            title: l10n.settingsNormalizationMode,
            value: !platform.isDesktop && p.normalizationMode == NormalizationMode.loudness
                ? NormalizationMode.replayGainTrack
                : p.normalizationMode,
            forceDropdown: true,
            disabledReason: l10n.settingsNormalizationModeDisabled,
            options: [
              SettingOption(NormalizationMode.replayGainTrack, l10n.settingsNormalizationTrack,
                  description: l10n.settingsNormalizationTrackHint),
              SettingOption(NormalizationMode.replayGainAlbum, l10n.settingsNormalizationAlbum,
                  description: l10n.settingsNormalizationAlbumHint),
              // Real-time loudness analysis needs libmpv (desktop only).
              if (platform.isDesktop)
                SettingOption(NormalizationMode.loudness, l10n.settingsNormalizationLoudness,
                    description: l10n.settingsNormalizationLoudnessHint),
            ],
            onChanged: p.normalizeVolume ? (v) => set((p) => p.copyWith(normalizationMode: v)) : null,
          ),
          SettingSlider(
            key: const ValueKey('setting.preamp'),
            title: l10n.settingsPreamp,
            subtitle: l10n.settingsPreampHint,
            value: p.preampDb,
            min: -12,
            max: 12,
            divisions: 24,
            format: (v) => '${v > 0 ? '+' : ''}${v.round()} dB',
            disabledReason: l10n.settingsNormalizationModeDisabled,
            onChanged: p.normalizeVolume ? (v) => set((p) => p.copyWith(preampDb: v.roundToDouble())) : null,
          ),
          if (controller.supportsSpeed)
            SettingSlider(
              key: const ValueKey('setting.speed'),
              title: l10n.settingsSpeed,
              subtitle: l10n.settingsSpeedHint,
              value: p.speed,
              min: 0.5,
              max: 2.0,
              divisions: 30,
              format: (v) => '${v.toStringAsFixed(2)}×',
              onChanged: (v) async {
                final speed = (v * 20).round() / 20;
                await set((p) => p.copyWith(speed: speed));
                await controller.setSpeed(speed);
              },
            ),
        ]),
        SettingsGroup(title: l10n.settingsStartupQueueGroup, children: [
          SettingSwitch(
            key: const ValueKey('setting.restoreQueue'),
            title: l10n.settingsRestoreQueue,
            subtitle: l10n.settingsRestoreQueueHint,
            value: p.restoreQueueOnStartup,
            onChanged: (v) => set((p) => p.copyWith(restoreQueueOnStartup: v)),
          ),
          SettingSwitch(
            key: const ValueKey('setting.autoplay'),
            title: l10n.settingsAutoplay,
            subtitle: l10n.settingsAutoplayHint,
            value: p.autoPlayOnStartup && p.restoreQueueOnStartup,
            disabledReason: l10n.settingsAutoplayDisabled,
            onChanged: p.restoreQueueOnStartup ? (v) => set((p) => p.copyWith(autoPlayOnStartup: v)) : null,
          ),
          SettingSwitch(
            key: const ValueKey('setting.smartQueue'),
            title: l10n.settingsSmartQueue,
            subtitle: l10n.settingsSmartQueueHint,
            value: p.smartQueue,
            onChanged: (v) => set((p) => p.copyWith(smartQueue: v)),
          ),
          SettingSwitch(
            key: const ValueKey('setting.skipUnplayable'),
            title: l10n.settingsSkipUnplayable,
            subtitle: l10n.settingsSkipUnplayableHint,
            value: p.skipUnplayable,
            onChanged: (v) => set((p) => p.copyWith(skipUnplayable: v)),
          ),
        ]),
        SettingsGroup(title: l10n.settingsExtrasGroup, children: [
          SettingSwitch(
            key: const ValueKey('setting.sleepFade'),
            title: l10n.settingsSleepFade,
            subtitle: l10n.settingsSleepFadeHint,
            value: p.sleepTimerFadeOut,
            onChanged: (v) => set((p) => p.copyWith(sleepTimerFadeOut: v)),
          ),
          SettingSwitch(
            key: const ValueKey('setting.lyrics'),
            title: l10n.settingsLyrics,
            subtitle: l10n.settingsLyricsHint,
            value: p.lyricsEnabled,
            onChanged: (v) => set((p) => p.copyWith(lyricsEnabled: v)),
          ),
        ]),
        // Audio focus / "becoming noisy" events only exist on Android.
        if (platform.isAndroid)
          SettingsGroup(title: l10n.settingsInterruptionsGroup, children: [
            SettingSwitch(
              key: const ValueKey('setting.pauseOnDisconnect'),
              title: l10n.settingsPauseOnDisconnect,
              subtitle: l10n.settingsPauseOnDisconnectHint,
              value: p.pauseOnHeadphonesDisconnect,
              onChanged: (v) => set((p) => p.copyWith(pauseOnHeadphonesDisconnect: v)),
            ),
            SettingSwitch(
              key: const ValueKey('setting.resumeAfterInterruption'),
              title: l10n.settingsResumeAfterInterruption,
              subtitle: l10n.settingsResumeAfterInterruptionHint,
              value: p.resumeAfterInterruption,
              onChanged: (v) => set((p) => p.copyWith(resumeAfterInterruption: v)),
            ),
            SettingSwitch(
              key: const ValueKey('setting.duck'),
              title: l10n.settingsDuck,
              subtitle: l10n.settingsDuckHint,
              value: p.duckOnTransientInterruption,
              onChanged: (v) => set((p) => p.copyWith(duckOnTransientInterruption: v)),
            ),
          ]),
      ],
    );
  }
}

/// Localized audio quality label.
String qualityLabel(AppLocalizations l10n, AudioQuality q) => switch (q) {
      AudioQuality.low => l10n.settingsValueLow,
      AudioQuality.normal => l10n.settingsValueNormal,
      AudioQuality.high => l10n.settingsValueHigh,
      AudioQuality.lossless => l10n.settingsValueLossless,
    };

/// Output devices for Settings → Audio quality (desktop).
final outputDevicesProvider = FutureProvider.autoDispose<List<AudioOutputDevice>>((ref) async {
  final playback = ref.watch(playbackProvider);
  if (!playback.supportsOutputDeviceSelection) return const [];
  return playback.outputDevices();
});

/// Settings → Audio quality.
class AudioQualitySection extends ConsumerWidget {
  const AudioQualitySection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final q = ref.watch(settingsProvider.select((s) => s.audioQuality));
    final deviceId = ref.watch(settingsProvider.select((s) => s.playback.outputDeviceId));
    final controller = ref.watch(playbackProvider);
    final options = [for (final v in AudioQuality.values) SettingOption(v, qualityLabel(l10n, v))];
    void set(AudioQualitySettings Function(AudioQualitySettings q) change) =>
        updateSettings(ref, (s) => s.copyWith(audioQuality: change(s.audioQuality)));

    return SectionFrame(
      title: l10n.shellSectionAudioQuality,
      intro: l10n.settingsQualityIntro,
      showHeading: showHeading,
      onRestoreDefaults: () => updateSettings(ref, (s) => s.copyWith(audioQuality: const AudioQualitySettings())),
      children: [
        SettingsGroup(children: [
          SettingChoice<AudioQuality>(
            key: const ValueKey('setting.streamingQuality'),
            title: l10n.settingStreamingQuality,
            subtitle: l10n.settingsStreamingQualityHint,
            value: q.streaming,
            options: options,
            onChanged: (v) => set((q) => q.copyWith(streaming: v)),
          ),
          SettingChoice<AudioQuality>(
            key: const ValueKey('setting.mobileQuality'),
            title: l10n.settingsMobileQuality,
            subtitle: l10n.settingsMobileQualityHint,
            value: q.mobileStreaming,
            options: options,
            onChanged: (v) => set((q) => q.copyWith(mobileStreaming: v)),
          ),
          SettingChoice<AudioQuality>(
            key: const ValueKey('setting.downloadQuality'),
            title: l10n.settingsDownloadQuality,
            subtitle: l10n.settingsDownloadQualityHint,
            value: q.download,
            options: options,
            onChanged: (v) => set((q) => q.copyWith(download: v)),
          ),
        ]),
        SettingNote(text: l10n.settingsQualityProviders),
        if (controller.supportsOutputDeviceSelection)
          SettingsGroup(title: l10n.settingsOutputGroup, children: [
            ref.watch(outputDevicesProvider).when(
                  loading: () => SettingInfo(title: l10n.settingsOutputDevice, value: '…'),
                  error: (e, _) => SettingInfo(title: l10n.settingsOutputDevice, value: l10n.settingsOutputDevicesFailed),
                  data: (devices) {
                    if (devices.isEmpty) return SettingInfo(title: l10n.settingsOutputDevice, value: l10n.settingsOutputDeviceSystem);
                    final selected = devices.where((d) => d.id == deviceId).firstOrNull ??
                        devices.where((d) => d.isDefault).firstOrNull ??
                        devices.first;
                    return SettingChoice<String>(
                      key: const ValueKey('setting.outputDevice'),
                      title: l10n.settingsOutputDevice,
                      subtitle: l10n.settingsOutputDeviceHint,
                      value: selected.id,
                      forceDropdown: true,
                      options: [
                        for (final d in devices)
                          SettingOption(d.id, d.isDefault ? l10n.settingsOutputDeviceDefault(d.name) : d.name),
                      ],
                      onChanged: (id) => runWithToast(context, () => controller.setOutputDevice(id),
                          errorMessage: l10n.settingsOutputDeviceFailed),
                    );
                  },
                ),
          ]),
      ],
    );
  }
}
