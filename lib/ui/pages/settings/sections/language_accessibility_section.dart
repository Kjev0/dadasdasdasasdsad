import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../settings/app_settings.dart';
import '../../../design/context_ext.dart';
import '../widgets/section_frame.dart';
import '../widgets/setting_tiles.dart';

/// Settings → Language: System / English / Dansk.
class LanguageSection extends ConsumerWidget {
  const LanguageSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final code = ref.watch(settingsProvider.select((s) => s.localeCode));
    // Language names are written in their own language on purpose.
    final options = <(String?, String, String?)>[
      (null, l10n.settingsLanguageSystem, l10n.settingsLanguageSystemHint),
      ('en', 'English', null),
      ('da', 'Dansk', null),
    ];
    return SectionFrame(
      title: l10n.shellSectionLanguage,
      showHeading: showHeading,
      onRestoreDefaults: () => updateSettings(ref, (s) => s.copyWith(clearLocale: true)),
      children: [
        SettingsGroup(children: [
          RadioGroup<String?>(
            groupValue: code,
            onChanged: (v) => updateSettings(ref, (s) => v == null ? s.copyWith(clearLocale: true) : s.copyWith(localeCode: v)),
            child: Column(
              children: [
                for (final (value, label, hint) in options)
                  RadioListTile<String?>(
                    key: ValueKey('setting.language.${value ?? 'system'}'),
                    value: value,
                    title: Text(label, style: context.type.body),
                    subtitle: hint == null ? null : Text(hint, style: context.type.bodySmall),
                  ),
              ],
            ),
          ),
        ]),
      ],
    );
  }
}

/// Settings → Accessibility.
class AccessibilitySection extends ConsumerStatefulWidget {
  const AccessibilitySection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  ConsumerState<AccessibilitySection> createState() => _AccessibilitySectionState();
}

class _AccessibilitySectionState extends ConsumerState<AccessibilitySection> {
  double? _previewScale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final a = ref.watch(settingsProvider.select((s) => s.accessibility));
    void set(AccessibilitySettings Function(AccessibilitySettings a) change) =>
        updateSettings(ref, (s) => s.copyWith(accessibility: change(s.accessibility)));
    final scale = _previewScale ?? a.textScale;
    final systemScale = MediaQuery.textScalerOf(context).scale(1) / a.textScale;

    return SectionFrame(
      title: l10n.shellSectionAccessibility,
      showHeading: widget.showHeading,
      onRestoreDefaults: () => updateSettings(ref, (s) => s.copyWith(accessibility: const AccessibilitySettings())),
      children: [
        SettingsGroup(children: [
          SettingChoice<MotionPreference>(
            key: const ValueKey('setting.motion'),
            title: l10n.settingsMotion,
            subtitle: l10n.settingsMotionHint,
            value: a.motion,
            options: [
              SettingOption(MotionPreference.system, l10n.settingsMotionSystem),
              SettingOption(MotionPreference.reduce, l10n.settingsMotionReduce),
              SettingOption(MotionPreference.full, l10n.settingsMotionFull),
            ],
            onChanged: (v) => set((a) => a.copyWith(motion: v)),
          ),
          SettingSwitch(
            key: const ValueKey('setting.a11yHighContrast'),
            title: l10n.settingsHighContrast,
            subtitle: l10n.settingsHighContrastHint,
            value: a.highContrast,
            onChanged: (v) => set((a) => a.copyWith(highContrast: v)),
          ),
          SettingSlider(
            key: const ValueKey('setting.textScale'),
            title: l10n.settingsTextScale,
            subtitle: l10n.settingsTextScaleHint,
            value: a.textScale,
            min: 0.8,
            max: 1.6,
            divisions: 8,
            format: (v) => '${(v * 100).round()} %',
            onPreview: (v) => setState(() => _previewScale = v),
            onChanged: (v) => set((a) => a.copyWith(textScale: (v * 10).round() / 10)),
          ),
          Padding(
            key: const ValueKey('settings.textScalePreview'),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: MediaQuery(
              // Preview the dragged value on top of the system scale.
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(systemScale * scale)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: context.colors.surfaceHigh, borderRadius: context.radii.smAll),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.settingsTextScalePreviewTitle, style: context.type.titleSmall),
                    const SizedBox(height: 4),
                    Text(l10n.settingsTextScalePreviewBody, style: context.type.bodySmall),
                  ],
                ),
              ),
            ),
          ),
          SettingSwitch(
            key: const ValueKey('setting.largerTargets'),
            title: l10n.settingsLargerTargets,
            subtitle: l10n.settingsLargerTargetsHint,
            value: a.largerTargets,
            onChanged: (v) => set((a) => a.copyWith(largerTargets: v)),
          ),
        ]),
        SettingNote(text: l10n.settingsAccessibilityNote),
      ],
    );
  }
}
