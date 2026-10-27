import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contracts/discovery.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/feedback/states.dart';
import '../library/folders/scan_controller.dart';
import '../library/shared/labels.dart';
import '../library/shared/page_layout.dart';
import '../library/shared/page_services.dart';
import 'home_providers.dart';
import 'shelf_views.dart';

/// Home: a time-of-day greeting and the recommendation shelves (continue
/// listening, daily mixes, discover weekly, trending, new releases,
/// recently added). Shows a first-run panel when there is nothing yet.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// Shelf opened in the in-page detail view.
  Shelf? _open;

  void _openShelf(Shelf shelf) => setState(() => _open = shelf);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final open = _open;
    if (open != null) {
      final title = shelfTitle(l10n, open);
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _open = null);
        },
        child: Scaffold(
          body: TrackCollectionView(
            key: ValueKey('shelf-${open.id}'),
            title: title,
            eyebrow: isMixShelf(open) ? l10n.homeMix : l10n.homeShelf,
            subtitle: shelfSubtitle(l10n, open),
            artworkUrl: open.artworkUrl,
            tracks: open.tracks,
            origin: 'shelf:${open.id}',
            onBack: () => setState(() => _open = null),
          ),
        ),
      );
    }

    final now = ref.watch(pageClockProvider)();
    final shelves = ref.watch(homeShelvesProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(homeShelvesProvider.future).then((_) {}, onError: (_) {}),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: greetingFor(l10n, now),
                subtitle: l10n.homeSubtitle,
              ),
            ),
            ...shelves.when(
              data: (list) => list.isEmpty ? [const SliverToBoxAdapter(child: FirstRunPanel())] : _shelfSlivers(context, list),
              error: (e, _) => [
                SliverToBoxAdapter(child: ErrorState(error: e, onRetry: () => ref.invalidate(homeShelvesProvider))),
              ],
              loading: () => [
                SliverPadding(
                  padding: pageInsets(context),
                  sliver: SliverList.list(children: const [
                    SkeletonShelf(),
                    SizedBox(height: 24),
                    SkeletonShelf(),
                  ]),
                ),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  List<Widget> _shelfSlivers(BuildContext context, List<Shelf> shelves) {
    final l10n = context.l10n;
    final insets = pageInsets(context);
    final mixes = [for (final s in shelves) if (isMixShelf(s)) s];
    final children = <Widget>[];
    var mixesPlaced = false;
    for (final s in shelves) {
      if (isMixShelf(s)) {
        if (mixesPlaced) continue;
        mixesPlaced = true;
        children.add(MixesRow(key: const ValueKey('mixes'), title: l10n.homeMadeForYou, shelves: mixes, onOpen: _openShelf));
      } else {
        final title = shelfTitle(l10n, s);
        children.add(TrackShelfRow(
          key: ValueKey('shelf-${s.id}'),
          title: title,
          subtitle: shelfSubtitle(l10n, s),
          tracks: s.tracks,
          origin: 'shelf:${s.id}',
          onSeeAll: s.tracks.length > 4 ? () => _openShelf(s) : null,
        ));
      }
      children.add(const SizedBox(height: 20));
    }
    return [SliverPadding(padding: insets, sliver: SliverList.list(children: children))];
  }
}

/// First-run panel: add a music folder, connect a service, or explore.
class FirstRunPanel extends ConsumerWidget {
  const FirstRunPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final c = context.colors;
    Widget option(IconData icon, String title, String body, Widget button) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: context.radii.mdAll,
              border: Border.all(color: c.outlineSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: c.accentText),
                const SizedBox(height: 12),
                Text(title, style: context.type.titleSmall),
                const SizedBox(height: 4),
                Text(body, style: context.type.bodySmall),
                const SizedBox(height: 12),
                button,
              ],
            ),
          ),
        );
    return Padding(
      padding: pageInsets(context).copyWith(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.homeFirstRunTitle, style: context.type.title),
          const SizedBox(height: 6),
          Text(l10n.homeFirstRunMessage, style: context.type.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              option(
                Icons.create_new_folder_rounded,
                l10n.homeAddFolderTitle,
                l10n.homeAddFolderBody,
                FermataButton(
                  label: l10n.libraryAddFolder,
                  icon: Icons.add_rounded,
                  onPressed: () async {
                    final added = await addMusicFolder(context, ref);
                    if (added && context.mounted) context.go(AppRoutes.library(tab: 'folders'));
                  },
                ),
              ),
              option(
                Icons.link_rounded,
                l10n.homeConnectTitle,
                l10n.homeConnectBody,
                FermataButton(
                  label: l10n.homeConnectAction,
                  variant: FermataButtonVariant.secondary,
                  onPressed: () => context.go(AppRoutes.settingsSection(SettingsSections.services)),
                ),
              ),
              option(
                Icons.explore_rounded,
                l10n.homeExploreTitle,
                l10n.homeExploreBody,
                FermataButton(
                  label: l10n.homeExploreAction,
                  variant: FermataButtonVariant.secondary,
                  onPressed: () => context.go(AppRoutes.explore),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
