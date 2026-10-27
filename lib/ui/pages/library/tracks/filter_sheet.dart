import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/sources/source_ids.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/chips/badges.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/dialogs/sheet.dart';
import '../shared/track_helpers.dart';
import 'library_query.dart';

/// Opens the Library filter sheet (changes apply live).
Future<void> showLibraryFilterSheet(BuildContext context) =>
    showFermataSheet<void>(context, builder: (_) => const LibraryFilterSheet());

/// Source, offline, favorites, genre, year and duration filters.
class LibraryFilterSheet extends ConsumerStatefulWidget {
  const LibraryFilterSheet({super.key});

  @override
  ConsumerState<LibraryFilterSheet> createState() => _LibraryFilterSheetState();
}

class _LibraryFilterSheetState extends ConsumerState<LibraryFilterSheet> {
  late final LibraryFilters _initial = ref.read(libraryFiltersProvider);
  late final _minYear = TextEditingController(text: _initial.minYear?.toString() ?? '');
  late final _maxYear = TextEditingController(text: _initial.maxYear?.toString() ?? '');
  late final _minDur = TextEditingController(text: _initial.minDuration == null ? '' : '${_initial.minDuration!.inMinutes}');
  late final _maxDur = TextEditingController(text: _initial.maxDuration == null ? '' : '${_initial.maxDuration!.inMinutes}');

  @override
  void dispose() {
    for (final c in [_minYear, _maxYear, _minDur, _maxDur]) {
      c.dispose();
    }
    super.dispose();
  }

  LibraryFiltersController get _ctl => ref.read(libraryFiltersProvider.notifier);

  Widget _number(TextEditingController c, String label, void Function(int? v) onChanged, {String? key}) => SizedBox(
        width: 120,
        child: TextField(
          key: key == null ? null : ValueKey(key),
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: InputDecoration(labelText: label, isDense: true),
          onChanged: (v) => onChanged(int.tryParse(v)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final f = ref.watch(libraryFiltersProvider);
    final registry = ref.watch(sourceRegistryProvider);
    final order = ref.watch(settingsProvider.select((s) => s.services.providerOrder));
    final sourceIds = orderByPreference({SourceIds.local, for (final s in registry.all) s.id}, order);
    final genres = ref.watch(libraryGenresProvider).value ?? const <String>[];

    Widget toggle(String label, bool value, void Function(bool v) set, String key) => FilterChip(
          key: ValueKey(key),
          label: Text(label),
          selected: value,
          onSelected: set,
        );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.pagesFilter, style: context.type.title)),
              if (f.activeCount > 0)
                TextButton(
                  onPressed: () {
                    _ctl.set(f.cleared());
                    for (final c in [_minYear, _maxYear, _minDur, _maxDur]) {
                      c.clear();
                    }
                  },
                  child: Text(l10n.pagesClearFilters),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(l10n.libraryFilterAvailability, style: context.type.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              toggle(l10n.libraryFilterDownloaded, f.downloadedOnly, (v) => _ctl.update((x) => x.copyWith(downloadedOnly: v)), 'f-downloaded'),
              toggle(l10n.libraryFilterLocal, f.localFilesOnly, (v) => _ctl.update((x) => x.copyWith(localFilesOnly: v)), 'f-local'),
              toggle(l10n.libraryFilterOffline, f.offlineOnly, (v) => _ctl.update((x) => x.copyWith(offlineOnly: v)), 'f-offline'),
              toggle(l10n.libraryFilterFavorites, f.favoritesOnly, (v) => _ctl.update((x) => x.copyWith(favoritesOnly: v)), 'f-favorites'),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.libraryFilterSource, style: context.type.label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in sourceIds)
                FilterChip(
                  key: ValueKey('f-source-$id'),
                  label: Text(id == SourceIds.local ? l10n.libraryLocalFiles : sourceDisplayName(ref, id)),
                  selected: f.sources?.contains(id) ?? false,
                  onSelected: (v) => _ctl.update((x) {
                    final next = {...?x.sources};
                    v ? next.add(id) : next.remove(id);
                    return next.isEmpty ? x.copyWith(clearSources: true) : x.copyWith(sources: next);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.libraryFilterGenre, style: context.type.label),
          const SizedBox(height: 4),
          DropdownButton<String?>(
            key: const ValueKey('f-genre'),
            value: genres.contains(f.genre) ? f.genre : null,
            isExpanded: true,
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(l10n.libraryAnyGenre)),
              for (final g in genres) DropdownMenuItem<String?>(value: g, child: Text(g, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (g) => _ctl.update((x) => g == null ? x.copyWith(clearGenre: true) : x.copyWith(genre: g)),
          ),
          const SizedBox(height: 16),
          Text(l10n.libraryFilterYear, style: context.type.label),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _number(_minYear, l10n.libraryFrom, key: 'f-min-year',
                  (v) => _ctl.update((x) => v == null ? x.copyWith(clearMinYear: true) : x.copyWith(minYear: v))),
              _number(_maxYear, l10n.libraryTo, key: 'f-max-year',
                  (v) => _ctl.update((x) => v == null ? x.copyWith(clearMaxYear: true) : x.copyWith(maxYear: v))),
            ],
          ),
          const SizedBox(height: 16),
          Text(l10n.libraryFilterDuration, style: context.type.label),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _number(_minDur, l10n.libraryMinMinutes, key: 'f-min-dur', (v) => _ctl.update((x) =>
                  v == null ? x.copyWith(clearMinDuration: true) : x.copyWith(minDuration: Duration(minutes: v)))),
              _number(_maxDur, l10n.libraryMaxMinutes, key: 'f-max-dur', (v) => _ctl.update((x) =>
                  v == null ? x.copyWith(clearMaxDuration: true) : x.copyWith(maxDuration: Duration(minutes: v)))),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: FermataButton(label: context.l10n.actionDone, onPressed: () => Navigator.of(context).pop()),
          ),
        ],
      ),
    );
  }
}
