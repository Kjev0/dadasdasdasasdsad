import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/models/track.dart';
import '../actions/routes.dart';
import '../design/context_ext.dart';
import '../widgets/feedback/states.dart';
import '../widgets/glass/ambient_backdrop.dart';
import 'lyrics_view.dart';
import 'now_playing_parts.dart';
import 'player_menus.dart';
import 'playing_from.dart';
import 'queue_page.dart';
import 'seek_bar.dart';
import 'transport_controls.dart';
import 'volume_control.dart';

/// What the now-playing view shows next to (wide) or instead of (narrow)
/// the artwork.
enum NowPlayingPanel {
  artwork,
  lyrics,
  queue;

  /// Parses the `?view=` query parameter.
  static NowPlayingPanel parse(String? value) =>
      NowPlayingPanel.values.where((p) => p.name == value).firstOrNull ?? NowPlayingPanel.artwork;
}

/// Full-screen now playing (`/now-playing?view=artwork|lyrics|queue`):
/// large artwork over an artwork-derived backdrop, title/artist/album,
/// availability chips, transport, seek, volume (desktop), like / add to
/// playlist / download / open on provider, sleep timer, speed, lyrics and
/// queue panels, "Playing from …" and an error banner for unplayable tracks.
/// Swipe down (or Esc) closes.
class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key, this.initialPanel = NowPlayingPanel.artwork});

  final NowPlayingPanel initialPanel;

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage> {
  late NowPlayingPanel _panel = widget.initialPanel;

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  void _toggle(NowPlayingPanel panel) => setState(() => _panel = _panel == panel ? NowPlayingPanel.artwork : panel);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final track = ref.watch(currentSnapshotProvider.select((s) => s.track));
    final queue = ref.watch(queueStateProvider).value ?? ref.watch(playbackProvider).queue;
    final backdropOn = ref.watch(settingsProvider.select((s) => s.appearance.artworkBackdrop));
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 900 && size.height >= 560;
    final origin = playingFromLabel(context, queue);

    final topBar = Row(
      children: [
        IconButton(
          tooltip: l10n.playerCloseNowPlaying,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
          onPressed: _close,
        ),
        Expanded(
          child: Text(
            origin == null ? l10n.navNowPlaying : l10n.playerPlayingFrom(origin),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.label.copyWith(color: c.textSecondary),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );

    Widget body;
    if (track == null) {
      body = Column(
        children: [
          topBar,
          Expanded(
            child: EmptyState(
              icon: Icons.music_note_rounded,
              title: l10n.playerNothingPlaying,
              message: l10n.playerNothingPlayingHint,
            ),
          ),
        ],
      );
    } else {
      body = wide ? _wide(context, track, topBar) : _narrow(context, track, topBar);
    }

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: c.bg,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (backdropOn && track != null) AmbientBackdrop(artworkUrl: track.artworkUrl, forceArtwork: true),
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onVerticalDragEnd: wide
                    ? null
                    : (d) {
                        if ((d.primaryVelocity ?? 0) > 300) _close();
                      },
                child: SafeArea(child: body),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _panelToggles(BuildContext context) {
    final l10n = context.l10n;
    return [
      IconButton(
        tooltip: _panel == NowPlayingPanel.lyrics ? l10n.playerShowArtwork : l10n.playerShowLyrics,
        isSelected: _panel == NowPlayingPanel.lyrics,
        icon: const Icon(Icons.lyrics_rounded),
        onPressed: () => _toggle(NowPlayingPanel.lyrics),
      ),
      IconButton(
        tooltip: _panel == NowPlayingPanel.queue ? l10n.playerShowArtwork : l10n.playerShowQueue,
        isSelected: _panel == NowPlayingPanel.queue,
        icon: const Icon(Icons.queue_music_rounded),
        onPressed: () => _toggle(NowPlayingPanel.queue),
      ),
      const SleepTimerButton(),
      const SpeedButton(),
    ];
  }

  Widget _seek() => Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(currentSnapshotProvider);
          return SeekBar(
            position: s.position,
            duration: s.duration,
            buffered: s.bufferedPosition,
            onSeek: (d) => ref.read(playbackProvider).seek(d),
          );
        },
      );

  Widget _narrow(BuildContext context, Track track, Widget topBar) {
    final main = switch (_panel) {
      NowPlayingPanel.artwork => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: NowPlayingArtwork(track: track),
        ),
      NowPlayingPanel.lyrics => LyricsView(track: track),
      NowPlayingPanel.queue => const QueueList(padding: EdgeInsets.zero),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          topBar,
          const PlaybackErrorBanner(),
          Expanded(child: main),
          const SizedBox(height: 12),
          NowPlayingInfo(track: track),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: NowPlayingChips(track: track)),
          const SizedBox(height: 8),
          _seek(),
          const FittedBox(fit: BoxFit.scaleDown, child: TransportControls(playSize: 60)),
          NowPlayingActions(track: track, extra: _panelToggles(context)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _wide(BuildContext context, Track track, Widget topBar) {
    final desktop = ref.watch(platformInfoProvider).isDesktop;
    final side = switch (_panel) {
      NowPlayingPanel.queue => const QueueList(padding: EdgeInsets.zero),
      _ => LyricsView(track: track),
    };
    return Column(
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: topBar),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 8, 40, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      const PlaybackErrorBanner(),
                      Expanded(child: NowPlayingArtwork(track: track)),
                      const SizedBox(height: 24),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: Column(
                          children: [
                            NowPlayingInfo(track: track),
                            const SizedBox(height: 10),
                            Align(alignment: Alignment.centerLeft, child: NowPlayingChips(track: track)),
                            const SizedBox(height: 12),
                            _seek(),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Expanded(child: SizedBox()),
                                const TransportControls(playSize: 56),
                                Expanded(
                                  child: desktop
                                      ? const Align(alignment: Alignment.centerRight, child: FittedBox(child: VolumeControl(sliderWidth: 90)))
                                      : const SizedBox(),
                                ),
                              ],
                            ),
                            NowPlayingActions(track: track, extra: _panelToggles(context)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(flex: 4, child: side),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
