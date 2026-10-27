import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/models/playback.dart';
import '../design/context_ext.dart';
import '../player/mini_player.dart';
import '../player/player_bar.dart';
import '../player/player_providers.dart';
import '../widgets/feedback/messages.dart';
import '../widgets/feedback/toast.dart';
import '../widgets/glass/ambient_backdrop.dart';
import '../widgets/glass/glass_surface.dart';
import 'destinations.dart';
import 'nav_rail.dart';
import 'shell_location.dart';
import 'sidebar.dart';

/// Responsive app chrome around the routed page:
/// * compact (< 600 dp): bottom navigation + docked mini-player,
/// * medium (600–1023 dp): navigation rail + bottom player bar,
/// * expanded (≥ 1024 dp): 248 px sidebar + 88 px player bar.
///
/// Paints the ambient backdrop behind the glass chrome. The routed [child]
/// keeps its state across breakpoint changes (window resizing). Navigation
/// never touches playback.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.location, required this.child});

  final Uri location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _contentKey = GlobalKey(debugLabel: 'shell-content');

  @override
  Widget build(BuildContext context) {
    final artwork = ref.watch(currentSnapshotProvider.select((s) => s.track?.artworkUrl));
    ref.listen<PlaybackFailed?>(playbackFailureProvider, (previous, next) {
      if (next == null || !next.skipped || identical(previous, next)) return;
      final l10n = context.l10n;
      final reason = failureReason(next);
      final message = reason == null
          ? l10n.playerSkippedUnplayable
          : '${l10n.playerSkippedUnplayable}: ${availabilityReasonText(l10n, reason)}';
      showFermataToast(context, message, icon: Icons.skip_next_rounded);
    });

    final content = KeyedSubtree(key: _contentKey, child: widget.child);
    final size = LayoutSize.of(context);
    final Widget layout = switch (size) {
      LayoutSize.compact => Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Expanded(child: content),
            const MiniPlayer(),
          ],
        ),
        bottomNavigationBar: _BottomNav(location: widget.location),
      ),
      LayoutSize.medium => Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  SafeArea(right: false, child: FermataNavRail(location: widget.location)),
                  Expanded(child: content),
                ],
              ),
            ),
            const SafeArea(top: false, child: PlayerBar()),
          ],
        ),
      ),
      LayoutSize.expanded => Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Sidebar(location: widget.location),
                  Expanded(child: content),
                ],
              ),
            ),
            const SafeArea(top: false, child: PlayerBar()),
          ],
        ),
      ),
    };

    return ShellLocation(
      uri: widget.location,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AmbientBackdrop(artworkUrl: artwork),
          layout,
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.location});

  final Uri location;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = NavDestination.compactItems;
    final selected = items.indexOf(NavDestination.compactFor(location.path));
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: GlassSurface(
        edges: GlassEdges.topOnly,
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          selectedIndex: selected < 0 ? 0 : selected,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) => context.go(items[i].path),
          destinations: [for (final d in items) NavigationDestination(icon: Icon(d.icon), label: d.label(l10n))],
        ),
      ),
    );
  }
}
