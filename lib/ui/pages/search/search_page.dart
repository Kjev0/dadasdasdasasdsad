import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../design/context_ext.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/controls/search_field.dart';
import '../library/shared/page_layout.dart';
import '../library/shared/track_helpers.dart';
import 'link_card.dart';
import 'search_controller.dart';
import 'search_idle.dart';
import 'search_providers.dart';
import 'search_results.dart';

/// Search: debounced search-as-you-type over every ready source, results
/// streaming in per source and grouped (top result, tracks, artists,
/// albums, playlists) in provider-preference order; source filter chips;
/// recent searches and suggestions; share links open or import directly.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _text = TextEditingController(text: ref.read(searchControllerProvider).query);
  final _focus = FocusNode(debugLabel: 'search-field');

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  SearchPageController get _controller => ref.read(searchControllerProvider.notifier);

  /// Puts [query] in the field and searches immediately.
  void _searchFor(String query) {
    _text.value = TextEditingValue(text: query, selection: TextSelection.collapsed(offset: query.length));
    _controller.submit(query);
    recordSearch(ref, query);
  }

  void _submit(String value) {
    _controller.submit(value);
    recordSearch(ref, value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(searchControllerProvider);
    final insets = pageInsets(context);
    final showChips = state.activeQuery != null && state.link == null && state.query.isNotEmpty;

    Widget body;
    if (state.link != null) {
      body = ShareLinkCard(link: state.link!);
    } else if (state.query.isEmpty) {
      body = SearchIdleView(onSearch: _searchFor);
    } else if (state.typing) {
      body = SearchSuggestionsView(query: state.query, onSearch: _searchFor);
    } else {
      body = Listener(
        // Interacting with a result counts as "this search was useful".
        onPointerUp: (_) => recordSearch(ref, state.activeQuery ?? ''),
        child: SearchResultsView(state: state, onRetry: _controller.retry),
      );
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: insets.copyWith(top: isCompactWidth(context) ? 16 : 24, bottom: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SearchField(
                controller: _text,
                focusNode: _focus,
                autofocus: true,
                hint: l10n.searchHint,
                onChanged: _controller.setQuery,
                onSubmitted: _submit,
              ),
            ),
          ),
          if (showChips) _SourceChips(state: state, onSelected: _controller.setFilter),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// "All" + one chip per searchable source, in preference order.
class _SourceChips extends ConsumerWidget {
  const _SourceChips({required this.state, required this.onSelected});

  final SearchState state;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final registry = ref.watch(sourceRegistryProvider);
    final order = ref.watch(settingsProvider.select((s) => s.services.providerOrder));
    final ids = orderByPreference([for (final s in registry.ordered) if (isSearchable(s)) s.id], order);
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: pageInsets(context).copyWith(top: 4, bottom: 4),
        children: [
          ChoiceChip(
            label: Text(l10n.searchFilterAll),
            selected: state.filter == null,
            onSelected: (_) => onSelected(null),
          ),
          for (final id in ids) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              label: Text(sourceDisplayName(ref, id)),
              selected: state.filter == id,
              avatar: state.pending.contains(id) ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)) : null,
              onSelected: (_) => onSelected(state.filter == id ? null : id),
            ),
          ],
        ],
      ),
    );
  }
}
