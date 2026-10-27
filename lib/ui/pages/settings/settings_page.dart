import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../settings/app_settings.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/controls/search_field.dart';
import '../../widgets/dialogs/dialogs.dart';
import '../../widgets/feedback/states.dart';
import '../../widgets/feedback/toast.dart';
import 'settings_catalog.dart';

/// Minimum content width for the two-pane (list + section) layout.
const double settingsTwoPaneMinWidth = 760;

/// Restores every setting except the onboarding state, the download folder
/// (moving files is a separate step), the volume and the output device, and
/// re-applies the side effects (login entry, global hotkeys, speed).
Future<void> restoreAllSettings(WidgetRef ref) async {
  final store = ref.read(settingsStoreProvider);
  final cur = store.current;
  await store.replace(
    AppSettings(onboardingCompleted: cur.onboardingCompleted).copyWith(
      downloads: const DownloadSettings().copyWith(directory: cur.downloads.directory),
      playback: const PlaybackSettings().copyWith(volume: cur.playback.volume, outputDeviceId: cur.playback.outputDeviceId),
    ),
  );
  final startup = ref.read(startupManagerProvider);
  if (startup.isSupported && cur.desktop.launchAtLogin) await startup.setEnabled(false);
  final hotkeys = ref.read(globalHotkeysProvider);
  if (hotkeys.isSupported) {
    const d = ShortcutSettings();
    await hotkeys.apply(d.bindings, enabled: d.globalHotkeysEnabled);
  }
  final playback = ref.read(playbackProvider);
  if (playback.supportsSpeed && cur.playback.speed != 1.0) await playback.setSpeed(1.0);
}

/// Settings. Wide windows show a section list next to the selected section;
/// narrow windows show the list at `/settings` and one section per page at
/// `/settings/<section>` (ids: `SettingsSections`).
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.section});

  final String? section;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _search = TextEditingController();
  String _query = '';
  late String? _selected = widget.section;

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.section != oldWidget.section) _selected = widget.section;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _restoreAll() async {
    final l10n = context.l10n;
    final ok = await ConfirmDialog.show(
      context,
      title: l10n.settingsRestoreAllTitle,
      message: l10n.settingsRestoreAllBody,
      confirmLabel: l10n.actionRestoreDefaults,
      destructive: true,
    );
    if (!ok) return;
    await restoreAllSettings(ref);
    if (mounted) showFermataToast(context, l10n.settingsRestoredToast, icon: Icons.check_rounded);
  }

  void _open(String id, {required bool wide}) {
    if (wide) {
      setState(() => _selected = id);
    } else {
      context.go(AppRoutes.settingsSection(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = ref.watch(platformInfoProvider);
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= settingsTwoPaneMinWidth;
      if (wide) {
        final requested = settingsSectionById(_selected);
        final section = requested ?? settingsCatalog.firstWhere((s) => s.visibleOn(platform));
        return Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 300, child: _sectionList(context, selected: section.id, wide: true)),
              VerticalDivider(width: 1, thickness: 1, color: context.colors.outlineSubtle),
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey('settings.body.${section.id}'),
                  child: section.visibleOn(platform) ? section.build(true) : const _UnavailableSection(),
                ),
              ),
            ],
          ),
        );
      }
      final section = settingsSectionById(widget.section);
      if (section == null) return Scaffold(body: SafeArea(child: _sectionList(context, selected: null, wide: false)));
      return Scaffold(
        appBar: AppBar(
          title: Text(section.title(context.l10n)),
          leading: IconButton(
            tooltip: context.l10n.settingsBack,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ),
        body: section.visibleOn(platform) ? section.build(false) : const _UnavailableSection(),
      );
    });
  }

  Widget _sectionList(BuildContext context, {required String? selected, required bool wide}) {
    final l10n = context.l10n;
    final c = context.colors;
    final platform = ref.watch(platformInfoProvider);
    final hits = searchSettings(l10n, platform, _query);
    final searching = _query.trim().isNotEmpty;
    return ListView(
      padding: EdgeInsets.fromLTRB(wide ? 16 : 16, 24, wide ? 12 : 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Semantics(header: true, child: Text(l10n.settingsTitle, style: context.type.headline)),
        ),
        const SizedBox(height: 16),
        SearchField(
          key: const ValueKey('settings.search'),
          controller: _search,
          hint: l10n.settingsSearchHint,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v),
          onCleared: () => setState(() => _query = ''),
        ),
        const SizedBox(height: 12),
        if (searching && hits.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.settingsSearchNoResults(_query.trim()), style: context.type.bodySmall),
          ),
        if (searching)
          for (final hit in hits)
            ListTile(
              key: ValueKey('settings.hit.${hit.section.id}.${hit.label}'),
              leading: Icon(hit.section.icon, color: c.textSecondary),
              title: Text(hit.label, style: context.type.body),
              subtitle: hit.label == hit.section.title(l10n) ? null : Text(hit.section.title(l10n), style: context.type.bodySmall),
              shape: RoundedRectangleBorder(borderRadius: context.radii.smAll),
              onTap: () => _open(hit.section.id, wide: wide),
            )
        else
          for (final s in settingsCatalog)
            if (s.visibleOn(platform))
              ListTile(
                key: ValueKey('settings.section.${s.id}'),
                leading: Icon(s.icon, color: s.id == selected ? c.accentText : c.textSecondary),
                title: Text(s.title(l10n), style: context.type.body),
                selected: s.id == selected,
                selectedTileColor: c.surfaceHigh,
                trailing: wide ? null : Icon(Icons.chevron_right_rounded, color: c.textTertiary),
                shape: RoundedRectangleBorder(borderRadius: context.radii.smAll),
                onTap: () => _open(s.id, wide: wide),
              ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FermataButton(
            key: const ValueKey('settings.restoreAll'),
            label: l10n.settingsRestoreAll,
            icon: Icons.restart_alt_rounded,
            variant: FermataButtonVariant.ghost,
            onPressed: _restoreAll,
          ),
        ),
      ],
    );
  }
}

class _UnavailableSection extends StatelessWidget {
  const _UnavailableSection();

  @override
  Widget build(BuildContext context) =>
      EmptyState(icon: Icons.devices_other_rounded, title: context.l10n.settingsSectionUnavailable);
}
