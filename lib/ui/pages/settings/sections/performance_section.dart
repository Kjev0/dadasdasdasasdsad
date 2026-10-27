import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../settings/app_settings.dart';
import '../../../../settings/performance_profiles.dart';
import '../../../actions/routes.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../settings_format.dart';
import '../widgets/section_frame.dart';
import '../widgets/setting_tiles.dart';

/// Localized name of a performance mode.
String performanceModeLabel(AppLocalizations l10n, PerformanceMode m) => switch (m) {
      PerformanceMode.balanced => l10n.settingsModeBalanced,
      PerformanceMode.performance => l10n.settingsModePerformance,
      PerformanceMode.batterySaver => l10n.settingsModeBatterySaver,
      PerformanceMode.dataSaver => l10n.settingsModeDataSaver,
      PerformanceMode.visualQuality => l10n.settingsModeVisualQuality,
      PerformanceMode.custom => l10n.settingsModeCustom,
    };

/// One-sentence description of a mode. Wording describes what changes, never
/// promises a measured gain.
String performanceModeDescription(AppLocalizations l10n, PerformanceMode m) => switch (m) {
      PerformanceMode.balanced => l10n.settingsModeBalancedHint,
      PerformanceMode.performance => l10n.settingsModePerformanceHint,
      PerformanceMode.batterySaver => l10n.settingsModeBatterySaverHint,
      PerformanceMode.dataSaver => l10n.settingsModeDataSaverHint,
      PerformanceMode.visualQuality => l10n.settingsModeVisualQualityHint,
      PerformanceMode.custom => l10n.settingsModeCustomHint,
    };

/// "Animations: reduced · Blur: off · …" for a preset.
String effectsSummary(AppLocalizations l10n, PerformanceMode mode) => [
      for (final e in PerformanceProfiles.effectsOf(mode))
        '${effectSettingLabel(l10n, e.settingKey)}: ${effectValueLabel(l10n, e.valueLabel)}',
    ].join(' · ');

/// Selectable card for one performance mode.
class PerformanceModeCard extends StatelessWidget {
  const PerformanceModeCard({super.key, required this.mode, required this.selected, required this.onSelect});

  final PerformanceMode mode;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final effects = mode == PerformanceMode.custom ? null : effectsSummary(l10n, mode);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: ValueKey('settings.mode.${mode.name}'),
        borderRadius: context.radii.mdAll,
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? c.accent.withValues(alpha: 0.10) : c.surface,
            borderRadius: context.radii.mdAll,
            border: Border.all(color: selected ? c.accent : c.outlineSubtle, width: selected ? 1.5 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(performanceModeLabel(l10n, mode), style: context.type.titleSmall)),
                if (selected) Icon(Icons.check_circle_rounded, size: 20, color: c.accentText),
              ]),
              const SizedBox(height: 4),
              Text(performanceModeDescription(l10n, mode), style: context.type.bodySmall),
              if (effects != null) ...[
                const SizedBox(height: 8),
                Text(effects, style: context.type.caption.copyWith(color: c.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

const _intervals = [15, 30, 60, 120, 360, 720, 1440];

/// Settings → Performance.
class PerformanceSection extends ConsumerWidget {
  const PerformanceSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final p = ref.watch(settingsProvider.select((s) => s.performance));
    final store = ref.read(settingsStoreProvider);
    final intervals = {..._intervals, p.syncIntervalMinutes}.toList()..sort();

    return SectionFrame(
      title: l10n.shellSectionPerformance,
      intro: l10n.settingsPerformanceIntro,
      showHeading: showHeading,
      onRestoreDefaults: () => store.applyPerformanceMode(PerformanceMode.balanced),
      children: [
        LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 640 ? 2 : 1;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final mode in PerformanceMode.values)
                  SizedBox(
                    width: width,
                    child: PerformanceModeCard(
                      mode: mode,
                      selected: p.mode == mode,
                      onSelect: () => store.applyPerformanceMode(mode),
                    ),
                  ),
              ],
            ),
          );
        }),
        const ActiveNowSummary(),
        SettingsGroup(
          title: l10n.settingsGranularGroup,
          description: l10n.settingsGranularIntro,
          children: [
            SettingChoice<AnimationLevel>(
              key: const ValueKey('setting.animations'),
              title: l10n.settingAnimations,
              subtitle: l10n.settingsAnimationsHint,
              value: p.animations,
              options: [for (final a in AnimationLevel.values) SettingOption(a, animationLabel(l10n, a))],
              onChanged: (v) => store.updatePerformance((p) => p.copyWith(animations: v)),
            ),
            SettingSwitch(
              key: const ValueKey('setting.blur'),
              title: l10n.settingBlur,
              subtitle: l10n.settingsBlurHint,
              value: p.blur,
              onChanged: (v) => store.updatePerformance((p) => p.copyWith(blur: v)),
            ),
            SettingChoice<ArtworkQuality>(
              key: const ValueKey('setting.artworkQuality'),
              title: l10n.settingArtworkQuality,
              subtitle: l10n.settingsArtworkQualityHint,
              value: p.artworkQuality,
              options: [for (final q in ArtworkQuality.values) SettingOption(q, artworkQualityLabel(l10n, q))],
              onChanged: (v) => store.updatePerformance((p) => p.copyWith(artworkQuality: v)),
            ),
            SettingSwitch(
              key: const ValueKey('setting.preloadNext'),
              title: l10n.settingPreloadNext,
              subtitle: l10n.settingsPreloadNextHint,
              value: p.preloadNext,
              onChanged: (v) => store.updatePerformance((p) => p.copyWith(preloadNext: v)),
            ),
            SettingSwitch(
              key: const ValueKey('setting.prefetchArtwork'),
              title: l10n.settingPrefetchArtwork,
              subtitle: l10n.settingsPrefetchArtworkHint,
              value: p.prefetchArtwork,
              onChanged: (v) => store.updatePerformance((p) => p.copyWith(prefetchArtwork: v)),
            ),
            SettingSwitch(
              key: const ValueKey('setting.backgroundSync'),
              title: l10n.settingBackgroundSync,
              subtitle: l10n.settingsBackgroundSyncHint,
              value: p.backgroundSync,
              onChanged: (v) => store.updatePerformance((p) => p.copyWith(backgroundSync: v)),
            ),
            SettingChoice<int>(
              key: const ValueKey('setting.syncInterval'),
              title: l10n.settingsSyncInterval,
              value: p.syncIntervalMinutes,
              forceDropdown: true,
              disabledReason: l10n.settingsSyncIntervalDisabled,
              options: [for (final m in intervals) SettingOption(m, intervalLabel(l10n, m))],
              onChanged: p.backgroundSync ? (v) => store.updatePerformance((p) => p.copyWith(syncIntervalMinutes: v)) : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// What is in effect right now, after combining the mode with the OS
/// reduce-motion preference and the accessibility motion setting.
class ActiveNowSummary extends ConsumerWidget {
  const ActiveNowSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final v = ref.watch(effectiveVisualsProvider);
    final systemReduce = ref.watch(systemReduceMotionProvider);
    final p = s.performance;
    final motion = !v.animate
        ? l10n.settingsOff
        : v.reducedMotion
            ? l10n.settingsValueReduced
            : l10n.settingsValueFull;
    String onOff(bool b) => b ? l10n.settingsOn : l10n.settingsOff;
    final items = [
      '${l10n.settingAnimations}: $motion',
      '${l10n.settingBlur}: ${onOff(v.blur)}',
      '${l10n.settingArtworkQuality}: ${artworkQualityLabel(l10n, v.artworkQuality)}',
      '${l10n.settingPreloadNext}: ${onOff(p.preloadNext)}',
      '${l10n.settingPrefetchArtwork}: ${onOff(p.prefetchArtwork)}',
      '${l10n.settingBackgroundSync}: ${p.backgroundSync ? intervalLabel(l10n, p.syncIntervalMinutes) : l10n.settingsOff}',
    ];
    final motionOverride = s.accessibility.motion == MotionPreference.reduce ||
        (s.accessibility.motion == MotionPreference.system && systemReduce);
    return SettingsGroup(
      title: l10n.settingsActiveNow(performanceModeLabel(l10n, p.mode)),
      children: [
        Padding(
          key: const ValueKey('settings.activeNow'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(items.join(' · '), style: context.type.bodySmall),
              if (motionOverride && p.animations != AnimationLevel.off) ...[
                const SizedBox(height: 8),
                Text(l10n.settingsActiveNowReducedMotion, style: context.type.caption),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Settings → Battery & data saver: shortcuts into the same presets.
class SaversSection extends ConsumerWidget {
  const SaversSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(settingsProvider.select((s) => s.performance.mode));
    final store = ref.read(settingsStoreProvider);
    final platform = ref.watch(platformInfoProvider);

    Widget saver(PerformanceMode m, String note) {
      final active = mode == m;
      return SettingsGroup(
        title: performanceModeLabel(l10n, m),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(performanceModeDescription(l10n, m), style: context.type.body),
                const SizedBox(height: 6),
                Text(effectsSummary(l10n, m), style: context.type.caption),
                const SizedBox(height: 6),
                Text(note, style: context.type.bodySmall),
                const SizedBox(height: 12),
                FermataButton(
                  key: ValueKey('settings.saver.${m.name}'),
                  label: active ? l10n.settingsSaverTurnOff : l10n.settingsSaverTurnOn,
                  icon: active ? Icons.close_rounded : Icons.check_rounded,
                  variant: active ? FermataButtonVariant.secondary : FermataButtonVariant.primary,
                  onPressed: () => store.applyPerformanceMode(active ? PerformanceMode.balanced : m),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return SectionFrame(
      title: l10n.shellSectionSavers,
      intro: l10n.settingsSaversIntro,
      showHeading: showHeading,
      onRestoreDefaults: () => store.applyPerformanceMode(PerformanceMode.balanced),
      children: [
        saver(PerformanceMode.batterySaver, l10n.settingsBatterySaverNote),
        saver(PerformanceMode.dataSaver, l10n.settingsDataSaverNote),
        if (platform.isAndroid)
          SettingNote(
            text: l10n.settingsSaversAndroidNote,
            action: FermataButton(
              label: l10n.shellSectionBackground,
              variant: FermataButtonVariant.ghost,
              onPressed: () => context.go(AppRoutes.settingsSection(SettingsSections.background)),
            ),
          ),
        SettingNote(text: l10n.settingsSaversCustomNote),
      ],
    );
  }
}
