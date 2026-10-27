import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/contracts/music_source.dart';
import '../../../../core/sources/source_ids.dart';
import '../../../../settings/app_settings.dart';
import '../../../design/context_ext.dart';
import '../services/source_card.dart';
import '../widgets/section_frame.dart';
import '../widgets/setting_tiles.dart';

/// Registered source ids in the user's preference order (unknown ids in
/// the stored order are dropped, newly registered sources are appended).
List<String> effectiveProviderOrder(List<String> stored, Iterable<String> registered) {
  final ids = registered.toSet();
  return [
    for (final id in stored) if (ids.contains(id)) id,
    for (final id in registered) if (!stored.contains(id)) id,
  ];
}

/// Settings → Connected services.
class ServicesSection extends ConsumerWidget {
  const ServicesSection({super.key, this.showHeading = true});

  final bool showHeading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final registry = ref.watch(sourceRegistryProvider);
    ref.watch(sourcesRevisionProvider);
    final services = ref.watch(settingsProvider.select((s) => s.services));
    final tokens = ref.watch(tokenStoreProvider);
    final sources = registry.all;
    final order = effectiveProviderOrder(services.providerOrder, sources.map((s) => s.id));
    final hasSoundCloud = sources.any((s) => s.id == SourceIds.soundcloud);

    return SectionFrame(
      title: l10n.shellSectionServices,
      intro: l10n.settingsServicesIntro,
      showHeading: showHeading,
      onRestoreDefaults: () => updateSettings(ref, (s) => s.copyWith(services: const ServicesSettings())),
      children: [
        if (!tokens.isPersistent)
          SettingNote(key: const ValueKey('settings.tokenNotice'), text: l10n.settingsTokensNotPersistent, tone: NoteTone.warning),
        SettingNote(text: l10n.settingsNoPasswords, icon: Icons.lock_outline_rounded),
        for (final source in _cardOrder(sources, order)) SourceCard(source: source),
        const SizedBox(height: 8),
        SettingsGroup(
          title: l10n.settingsProviderOrder,
          description: l10n.settingsProviderOrderHint,
          children: [
            _ProviderOrderList(
              order: order,
              sources: {for (final s in sources) s.id: s},
              disabled: services.disabledSources,
            ),
          ],
        ),
        if (hasSoundCloud)
          SettingsGroup(children: [
            SettingSwitch(
              key: const ValueKey('setting.preferSoundCloud'),
              title: l10n.settingsPreferSoundCloud,
              subtitle: l10n.settingsPreferSoundCloudHint,
              value: services.preferSoundCloudInDiscovery,
              onChanged: (v) =>
                  updateSettings(ref, (s) => s.copyWith(services: s.services.copyWith(preferSoundCloudInDiscovery: v))),
            ),
          ]),
      ],
    );
  }

  static List<MusicSource> _cardOrder(List<MusicSource> sources, List<String> order) {
    final list = [...sources];
    list.sort((a, b) => order.indexOf(a.id).compareTo(order.indexOf(b.id)));
    return list;
  }
}

class _ProviderOrderList extends ConsumerWidget {
  const _ProviderOrderList({required this.order, required this.sources, required this.disabled});

  final List<String> order;
  final Map<String, MusicSource> sources;
  final Set<String> disabled;

  void _write(WidgetRef ref, List<String> next) {
    updateSettings(ref, (s) {
      // Keep ids of sources that are not registered right now (plugins).
      final rest = [for (final id in s.services.providerOrder) if (!next.contains(id)) id];
      return s.copyWith(services: s.services.copyWith(providerOrder: [...next, ...rest]));
    });
  }

  void _move(WidgetRef ref, int from, int to) {
    if (to < 0 || to >= order.length || from == to) return;
    final next = [...order];
    final id = next.removeAt(from);
    next.insert(to, id);
    _write(ref, next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: (from, to) => _move(ref, from, to),
      children: [
        for (var i = 0; i < order.length; i++)
          Padding(
            key: ValueKey('settings.order.${order[i]}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              ReorderableDragStartListener(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.drag_indicator_rounded, color: c.textTertiary, semanticLabel: l10n.settingsDragToReorder),
                ),
              ),
              SizedBox(
                width: 28,
                child: Text('${i + 1}', style: context.type.label.copyWith(color: c.textSecondary)),
              ),
              Expanded(
                child: Text(
                  sources[order[i]]?.displayName ?? order[i],
                  style: context.type.body.copyWith(color: disabled.contains(order[i]) ? c.textTertiary : c.textPrimary),
                ),
              ),
              IconButton(
                key: ValueKey('settings.order.${order[i]}.up'),
                tooltip: l10n.settingsMoveUp,
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                onPressed: i == 0 ? null : () => _move(ref, i, i - 1),
              ),
              IconButton(
                key: ValueKey('settings.order.${order[i]}.down'),
                tooltip: l10n.settingsMoveDown,
                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                onPressed: i == order.length - 1 ? null : () => _move(ref, i, i + 1),
              ),
              Semantics(
                label: l10n.settingsSourceEnabled(sources[order[i]]?.displayName ?? order[i]),
                child: Switch(
                  key: ValueKey('settings.order.${order[i]}.enabled'),
                  value: !disabled.contains(order[i]),
                  onChanged: (on) => updateSettings(ref, (s) {
                    final next = {...s.services.disabledSources};
                    on ? next.remove(order[i]) : next.add(order[i]);
                    return s.copyWith(services: s.services.copyWith(disabledSources: next));
                  }),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}
