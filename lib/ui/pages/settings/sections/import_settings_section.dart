import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../core/contracts/music_source.dart';
import '../../../../core/models/matching.dart';
import '../../../../settings/app_settings.dart';
import '../../../actions/routes.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../widgets/section_frame.dart';
import '../widgets/setting_tiles.dart';

/// [ImportSettings] with an explicit [preferredSource] (`copyWith` cannot
/// clear it).
ImportSettings withPreferredSource(ImportSettings s, String? id) => ImportSettings(
      reviewMode: s.reviewMode,
      autoAcceptThreshold: s.autoAcceptThreshold,
      skipUnavailable: s.skipUnavailable,
      preferredSource: id,
      allowPreviewOnly: s.allowPreviewOnly,
    );

/// Settings → Playlist import & matching.
class ImportSettingsSection extends ConsumerWidget {
  const ImportSettingsSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final imp = ref.watch(settingsProvider.select((s) => s.import));
    final registry = ref.watch(sourceRegistryProvider);
    final targets = [
      for (final s in registry.ordered)
        if (s.supports(SourceCapability.searchTracks) &&
            (s.supports(SourceCapability.stream) || s.supports(SourceCapability.previewOnly)))
          s,
    ];
    void set(ImportSettings Function(ImportSettings i) change) => updateSettings(ref, (s) => s.copyWith(import: change(s.import)));

    return SectionFrame(
      title: l10n.shellSectionImport,
      intro: l10n.settingsImportIntro,
      showHeading: showHeading,
      onRestoreDefaults: () => updateSettings(ref, (s) => s.copyWith(import: const ImportSettings())),
      children: [
        SettingsGroup(children: [
          SettingChoice<ReviewMode>(
            key: const ValueKey('setting.reviewMode'),
            title: l10n.settingsReviewMode,
            value: imp.reviewMode,
            forceDropdown: true,
            options: [
              SettingOption(ReviewMode.autoAcceptHigh, l10n.settingsReviewAuto, description: l10n.settingsReviewAutoHint),
              SettingOption(ReviewMode.reviewAll, l10n.settingsReviewAll, description: l10n.settingsReviewAllHint),
            ],
            onChanged: (v) => set((i) => i.copyWith(reviewMode: v)),
          ),
          SettingSlider(
            key: const ValueKey('setting.autoAcceptThreshold'),
            title: l10n.settingsAutoAcceptThreshold,
            subtitle: l10n.settingsAutoAcceptThresholdHint,
            value: imp.autoAcceptThreshold,
            min: 0.6,
            max: 1.0,
            divisions: 40,
            format: (v) => '${(v * 100).round()} %',
            disabledReason: l10n.settingsAutoAcceptThresholdDisabled,
            onChanged: imp.reviewMode == ReviewMode.autoAcceptHigh
                ? (v) => set((i) => i.copyWith(autoAcceptThreshold: (v * 100).round() / 100))
                : null,
          ),
          SettingSwitch(
            key: const ValueKey('setting.skipUnavailable'),
            title: l10n.settingsSkipUnavailable,
            subtitle: l10n.settingsSkipUnavailableHint,
            value: imp.skipUnavailable,
            onChanged: (v) => set((i) => i.copyWith(skipUnavailable: v)),
          ),
          SettingChoice<String>(
            key: const ValueKey('setting.preferredProvider'),
            title: l10n.settingsPreferredProvider,
            subtitle: l10n.settingsPreferredProviderHint,
            value: imp.preferredSource ?? '',
            forceDropdown: true,
            options: [
              SettingOption('', l10n.settingsNoPreference),
              for (final s in targets) SettingOption(s.id, s.displayName),
              if (imp.preferredSource != null && !targets.any((t) => t.id == imp.preferredSource))
                SettingOption(imp.preferredSource!, registry.byId(imp.preferredSource!)?.displayName ?? imp.preferredSource!),
            ],
            onChanged: (v) => set((i) => withPreferredSource(i, v.isEmpty ? null : v)),
          ),
          SettingSwitch(
            key: const ValueKey('setting.allowPreviewOnly'),
            title: l10n.settingsAllowPreviewOnly,
            subtitle: l10n.settingsAllowPreviewOnlyHint,
            value: imp.allowPreviewOnly,
            onChanged: (v) => set((i) => i.copyWith(allowPreviewOnly: v)),
          ),
        ]),
        SettingNote(text: l10n.settingsImportVersionsNote),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: FermataButton(
              key: const ValueKey('settings.importPlaylist'),
              label: l10n.settingsImportPlaylist,
              icon: Icons.playlist_add_rounded,
              onPressed: () => context.go(AppRoutes.import),
            ),
          ),
        ),
      ],
    );
  }
}
