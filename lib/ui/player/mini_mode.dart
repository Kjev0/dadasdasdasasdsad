import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/providers.dart';
import '../design/context_ext.dart';
import '../widgets/artwork/artwork_image.dart';
import 'seek_bar.dart';
import 'transport_controls.dart';

final _log = Logger('ui.player.mini');

/// Resizes the desktop window for the mini player.
///
/// Bootstrap should override [miniWindowControllerProvider] with an adapter
/// over the desktop lifecycle controller's `setMiniMode` (which also stops
/// window-bounds persistence while mini). The default is a direct
/// `window_manager` fallback.
abstract class MiniWindowController {
  Future<void> setMiniMode(bool enabled, {Size size = miniWindowSize, bool alwaysOnTop = true});
}

/// Mini player window size.
const miniWindowSize = Size(380, 132);

/// Fallback [MiniWindowController] using `window_manager` directly.
class WindowManagerMiniWindow implements MiniWindowController {
  Rect? _before;

  /// Restored minimum size when leaving mini mode.
  static const normalMinimumSize = Size(380, 600);

  @override
  Future<void> setMiniMode(bool enabled, {Size size = miniWindowSize, bool alwaysOnTop = true}) async {
    try {
      if (enabled) {
        _before = await windowManager.getBounds();
        await windowManager.setMinimumSize(size);
        final o = _before?.topLeft ?? Offset.zero;
        await windowManager.setBounds(o & size);
        await windowManager.setAlwaysOnTop(alwaysOnTop);
      } else {
        await windowManager.setAlwaysOnTop(false);
        await windowManager.setMinimumSize(normalMinimumSize);
        if (_before != null) await windowManager.setBounds(_before);
      }
    } catch (e, st) {
      _log.warning('Mini mode window change failed', e, st);
    }
  }
}

/// Null on platforms without a resizable window (Android).
final miniWindowControllerProvider = Provider<MiniWindowController?>(
  (ref) => ref.watch(platformInfoProvider).isDesktop ? WindowManagerMiniWindow() : null,
);

@immutable
class MiniModeState {
  const MiniModeState({this.active = false, this.alwaysOnTop = true});

  final bool active;
  final bool alwaysOnTop;

  MiniModeState copyWith({bool? active, bool? alwaysOnTop}) =>
      MiniModeState(active: active ?? this.active, alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop);
}

/// Desktop mini-player mode. While active, `FermataApp` shows
/// [MiniModeView] instead of the shell (the shell stays mounted offstage).
class MiniModeNotifier extends Notifier<MiniModeState> {
  @override
  MiniModeState build() => const MiniModeState();

  bool get isSupported => ref.read(miniWindowControllerProvider) != null;

  Future<void> enter() async {
    final window = ref.read(miniWindowControllerProvider);
    if (window == null || state.active) return;
    state = state.copyWith(active: true);
    await window.setMiniMode(true, alwaysOnTop: state.alwaysOnTop);
  }

  Future<void> exit() async {
    final window = ref.read(miniWindowControllerProvider);
    if (!state.active) return;
    state = state.copyWith(active: false);
    await window?.setMiniMode(false);
  }

  Future<void> toggle() => state.active ? exit() : enter();

  Future<void> setAlwaysOnTop(bool value) async {
    state = state.copyWith(alwaysOnTop: value);
    final window = ref.read(miniWindowControllerProvider);
    if (state.active) await window?.setMiniMode(true, alwaysOnTop: value);
  }
}

final miniModeProvider = NotifierProvider<MiniModeNotifier, MiniModeState>(MiniModeNotifier.new);

/// Toolbar button entering mini mode (hidden where unsupported).
class MiniModeButton extends ConsumerWidget {
  const MiniModeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(miniWindowControllerProvider) == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: context.l10n.playerMiniPlayer,
      icon: const Icon(Icons.picture_in_picture_alt_rounded),
      onPressed: () => ref.read(miniModeProvider.notifier).enter(),
    );
  }
}

/// The compact window content shown in mini mode (~380×132).
class MiniModeView extends ConsumerWidget {
  const MiniModeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final l10n = context.l10n;
    final snap = ref.watch(currentSnapshotProvider);
    final mini = ref.watch(miniModeProvider);
    final track = snap.track;
    return Material(
      color: c.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ArtworkImage(uri: track?.artworkUrl, size: 96, borderRadius: context.radii.mdAll),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track?.title ?? l10n.playerNothingPlaying,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (track != null)
                      Text(track.artistLine, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.bodySmall),
                    const Spacer(),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: TransportControls(playSize: 34, showShuffleRepeat: false),
                    ),
                    SeekBar(
                      position: snap.position,
                      duration: snap.duration,
                      showLabels: false,
                      thickness: 3,
                      onSeek: (d) => ref.read(playbackProvider).seek(d),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: l10n.playerExitMiniPlayer,
                    icon: const Icon(Icons.open_in_full_rounded, size: 20),
                    onPressed: () => ref.read(miniModeProvider.notifier).exit(),
                  ),
                  IconButton(
                    tooltip: l10n.playerAlwaysOnTop,
                    isSelected: mini.alwaysOnTop,
                    icon: const Icon(Icons.push_pin_outlined, size: 20),
                    selectedIcon: const Icon(Icons.push_pin_rounded, size: 20),
                    onPressed: () => ref.read(miniModeProvider.notifier).setAlwaysOnTop(!mini.alwaysOnTop),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
