import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../../settings/app_settings.dart';
import '../../../actions/routes.dart';
import '../../../design/context_ext.dart';
import '../../../design/fermata_colors.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/glass/glass_preview.dart';
import '../widgets/section_frame.dart';
import '../widgets/setting_tiles.dart';

/// Localized accent names (also used as swatch semantics labels).
String accentLabel(AppLocalizations l10n, AccentChoice a) => switch (a) {
      AccentChoice.gold => l10n.settingsAccentGold,
      AccentChoice.coral => l10n.settingsAccentCoral,
      AccentChoice.mint => l10n.settingsAccentMint,
      AccentChoice.ice => l10n.settingsAccentIce,
      AccentChoice.mono => l10n.settingsAccentMono,
    };

/// Settings → Appearance & theme.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final s = ref.watch(settingsProvider);
    final a = s.appearance;
    return SectionFrame(
      title: l10n.shellSectionAppearance,
      showHeading: showHeading,
      onRestoreDefaults: () => updateSettings(
        ref,
        (s) => s.copyWith(
          appearance: const AppearanceSettings().copyWith(liquidGlass: s.appearance.liquidGlass, glassIntensity: s.appearance.glassIntensity),
          accessibility: s.accessibility.copyWith(highContrast: false),
        ),
      ),
      children: [
        SettingsGroup(children: [
          SettingChoice<AppThemeMode>(
            key: const ValueKey('setting.themeMode'),
            title: l10n.settingsThemeMode,
            value: a.themeMode,
            options: [
              SettingOption(AppThemeMode.dark, l10n.settingsThemeDark),
              SettingOption(AppThemeMode.light, l10n.settingsThemeLight),
              SettingOption(AppThemeMode.system, l10n.settingsThemeSystem),
            ],
            onChanged: (v) => updateSettings(ref, (s) => s.copyWith(appearance: s.appearance.copyWith(themeMode: v))),
          ),
          _AccentPicker(
            value: a.accent,
            onChanged: (v) => updateSettings(ref, (s) => s.copyWith(appearance: s.appearance.copyWith(accent: v))),
          ),
          SettingChoice<UiDensity>(
            key: const ValueKey('setting.density'),
            title: l10n.settingsDensity,
            value: a.density,
            options: [
              SettingOption(UiDensity.comfortable, l10n.settingsDensityComfortable),
              SettingOption(UiDensity.compact, l10n.settingsDensityCompact),
            ],
            onChanged: (v) => updateSettings(ref, (s) => s.copyWith(appearance: s.appearance.copyWith(density: v))),
          ),
          SettingSwitch(
            key: const ValueKey('setting.artworkBackdrop'),
            title: l10n.settingsArtworkBackdrop,
            subtitle: l10n.settingsArtworkBackdropHint,
            value: a.artworkBackdrop,
            onChanged: (v) => updateSettings(ref, (s) => s.copyWith(appearance: s.appearance.copyWith(artworkBackdrop: v))),
          ),
          SettingSwitch(
            key: const ValueKey('setting.highContrast'),
            title: l10n.settingsHighContrast,
            subtitle: l10n.settingsHighContrastHint,
            value: s.accessibility.highContrast,
            onChanged: (v) => updateSettings(ref, (s) => s.copyWith(accessibility: s.accessibility.copyWith(highContrast: v))),
          ),
        ]),
      ],
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.value, required this.onChanged});

  final AccentChoice value;
  final ValueChanged<AccentChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.settingsAccent, style: context.type.body),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final accent in AccentChoice.values)
                Semantics(
                  button: true,
                  selected: accent == value,
                  label: accentLabel(l10n, accent),
                  child: Tooltip(
                    message: accentLabel(l10n, accent),
                    child: InkWell(
                      key: ValueKey('setting.accent.${accent.name}'),
                      customBorder: const CircleBorder(),
                      onTap: () => onChanged(accent),
                      child: Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: accent == value ? c.textPrimary : Colors.transparent, width: 2),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: FermataColors.resolve(brightness: brightness, accent: accent).accent,
                          ),
                          child: accent == value
                              ? Icon(Icons.check_rounded,
                                  size: 18, color: FermataColors.resolve(brightness: brightness, accent: accent).onAccent)
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Settings → Liquid Glass (default off) with a live preview.
class GlassSection extends ConsumerStatefulWidget {
  const GlassSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  ConsumerState<GlassSection> createState() => _GlassSectionState();
}

class _GlassSectionState extends ConsumerState<GlassSection> {
  /// Intensity while the slider is dragged (preview only).
  double? _previewIntensity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final appearance = ref.watch(settingsProvider.select((s) => s.appearance));
    final visuals = ref.watch(effectiveVisualsProvider);
    final blurOff = !visuals.blur;
    return SectionFrame(
      title: l10n.shellSectionGlass,
      intro: l10n.settingsGlassIntro,
      showHeading: widget.showHeading,
      onRestoreDefaults: () => updateSettings(
        ref,
        (s) => s.copyWith(appearance: s.appearance.copyWith(liquidGlass: false, glassIntensity: const AppearanceSettings().glassIntensity)),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: GlassPreview(key: const ValueKey('settings.glassPreview'), intensity: _previewIntensity),
        ),
        SettingsGroup(children: [
          SettingSwitch(
            key: const ValueKey('setting.liquidGlass'),
            title: l10n.settingsGlassToggle,
            subtitle: l10n.settingsGlassToggleHint,
            value: appearance.liquidGlass,
            onChanged: (v) => updateSettings(ref, (s) => s.copyWith(appearance: s.appearance.copyWith(liquidGlass: v))),
          ),
          SettingSlider(
            key: const ValueKey('setting.glassIntensity'),
            title: l10n.settingsGlassIntensity,
            subtitle: l10n.settingsGlassIntensityHint,
            value: appearance.glassIntensity,
            min: 0,
            max: 1,
            divisions: 20,
            format: (v) => '${(v * 100).round()} %',
            disabledReason: l10n.settingsGlassIntensityDisabled,
            onPreview: (v) => setState(() => _previewIntensity = v),
            onChanged: appearance.liquidGlass
                ? (v) => updateSettings(ref, (s) => s.copyWith(appearance: s.appearance.copyWith(glassIntensity: v)))
                : null,
          ),
        ]),
        if (appearance.liquidGlass && blurOff)
          SettingNote(
            key: const ValueKey('settings.glassBlurOffNote'),
            text: l10n.settingsGlassBlurOff,
            action: FermataButton(
              label: l10n.shellSectionPerformance,
              variant: FermataButtonVariant.ghost,
              onPressed: () => context.go(AppRoutes.settingsSection(SettingsSections.performance)),
            ),
          ),
        SettingNote(text: l10n.settingsGlassReadability),
      ],
    );
  }
}
