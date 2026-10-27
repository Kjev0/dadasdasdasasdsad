import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/models/library.dart';
import '../../core/models/track.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../actions/command_registry.dart';
import '../actions/fuzzy.dart';
import '../actions/routes.dart';
import '../actions/shortcut_binding.dart';
import '../design/context_ext.dart';
import '../player/mini_mode.dart';
import '../widgets/controls/search_field.dart';
import '../widgets/playlists/playlist_providers.dart';

bool _paletteOpen = false;

/// Opens the command palette (Ctrl+K). No-op when it is already open.
Future<void> showCommandPalette(BuildContext context) async {
  if (_paletteOpen) return;
  _paletteOpen = true;
  try {
    await showDialog<void>(
      context: context,
      barrierColor: context.colors.scrim,
      builder: (_) => const CommandPalette(),
    );
  } finally {
    _paletteOpen = false;
  }
}

/// One palette row.
class PaletteEntry {
  const PaletteEntry({
    required this.id,
    required this.category,
    required this.title,
    required this.icon,
    required this.run,
    this.subtitle,
    this.keywords = const [],
    this.shortcut,
  });

  final String id;
  final CommandCategory category;
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<String> keywords;

  /// Display form of the bound shortcut (e.g. `Ctrl+K`).
  final String? shortcut;
  final FutureOr<void> Function(CommandContext ctx) run;
}

/// Fuzzy-filters [entries] by title and keywords (best match first).
List<PaletteEntry> filterPaletteEntries(List<PaletteEntry> entries, String query, {int limit = 40}) =>
    fuzzyFilter(entries, query, (e) => [e.title, ...e.keywords, ?e.subtitle], limit: limit);

/// Static entries (commands) for the palette.
List<PaletteEntry> commandPaletteEntries(
  AppLocalizations l10n, {
  required Map<String, String> bindings,
  bool miniPlayerSupported = false,
  FutureOr<void> Function(CommandContext ctx)? onToggleMiniPlayer,
}) {
  final categoryLabel = {
    CommandCategory.navigation: l10n.paletteGroupNavigation,
    CommandCategory.player: l10n.paletteGroupPlayer,
    CommandCategory.settings: l10n.paletteGroupSettings,
  };
  return [
    for (final c in CommandRegistry.commands(l10n, miniPlayerSupported: miniPlayerSupported, onToggleMiniPlayer: onToggleMiniPlayer))
      PaletteEntry(
        id: c.id,
        category: c.category,
        title: c.label,
        subtitle: categoryLabel[c.category],
        icon: c.icon,
        keywords: c.keywords,
        shortcut: c.shortcutAction == null
            ? null
            : ShortcutBinding.format(bindings[c.shortcutAction] ?? ShortcutActions.defaults[c.shortcutAction]),
        run: c.run,
      ),
  ];
}

/// Ctrl+K palette: fuzzy search over navigation destinations, player
/// commands, settings sections, playlists and library tracks.
class CommandPalette extends ConsumerStatefulWidget {
  const CommandPalette({super.key});

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  static const _rowHeight = 48.0;

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  int _selected = 0;
  bool _ran = false;
  List<Track> _tracks = const [];
  Timer? _debounce;
  int _searchGeneration = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _query = value;
      _selected = 0;
    });
    _debounce?.cancel();
    final q = value.trim();
    if (q.length < 2) {
      setState(() => _tracks = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 200), () => _searchTracks(q));
  }

  Future<void> _searchTracks(String q) async {
    final generation = ++_searchGeneration;
    try {
      final result = await ref.read(trackRepositoryProvider).query(TrackQuery(text: q, limit: 8));
      if (!mounted || generation != _searchGeneration) return;
      setState(() => _tracks = result);
    } catch (_) {
      // Library search is best effort in the palette.
    }
  }

  List<PaletteEntry> _entries(AppLocalizations l10n) {
    final bindings = ref.watch(settingsProvider.select((s) => s.shortcuts.bindings));
    final miniSupported = ref.watch(miniWindowControllerProvider) != null;
    final playlists = ref.watch(userPlaylistsProvider).value ?? const [];
    final base = [
      ...commandPaletteEntries(
        l10n,
        bindings: bindings,
        miniPlayerSupported: miniSupported,
        onToggleMiniPlayer: (c) => c.read(miniModeProvider.notifier).toggle(),
      ),
      for (final p in playlists)
        PaletteEntry(
          id: 'playlist.${p.id}',
          category: CommandCategory.playlist,
          title: p.name,
          subtitle: l10n.paletteGroupPlaylists,
          icon: Icons.queue_music_rounded,
          run: (c) => c.router.go(AppRoutes.playlist(p.id)),
        ),
    ];
    final filtered = _query.trim().isEmpty ? base : filterPaletteEntries(base, _query);
    final tracks = [
      for (final t in _tracks)
        PaletteEntry(
          id: 'track.${t.id}',
          category: CommandCategory.track,
          title: t.title,
          subtitle: t.artistLine.isEmpty ? l10n.paletteGroupTracks : '${t.artistLine} · ${l10n.paletteGroupTracks}',
          icon: Icons.music_note_rounded,
          run: (c) => c.trackActions.play([t], origin: 'library'),
        ),
    ];
    return [...filtered, ...tracks];
  }

  Future<void> _run(PaletteEntry entry) async {
    if (_ran) return;
    _ran = true;
    final container = ProviderScope.containerOf(context, listen: false);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);
    final rootContext = navigator.context;
    navigator.pop();
    await entry.run(CommandContext(container: container, router: router, context: rootContext));
  }

  void _move(int delta, int count) {
    if (count == 0) return;
    // Dart's % is non-negative for a positive divisor, so this wraps.
    setState(() => _selected = (_selected + delta) % count);
    final target = _selected * _rowHeight;
    if (_scroll.hasClients) {
      final p = _scroll.position;
      if (target < p.pixels) {
        _scroll.jumpTo(target);
      } else if (target + _rowHeight > p.pixels + p.viewportDimension) {
        _scroll.jumpTo((target + _rowHeight - p.viewportDimension).clamp(0.0, p.maxScrollExtent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l10n = context.l10n;
    final entries = _entries(l10n);
    if (_selected >= entries.length) _selected = entries.isEmpty ? 0 : entries.length - 1;
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: EdgeInsets.only(top: size.height < 600 ? 16 : 72, left: 16, right: 16, bottom: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 620, maxHeight: (size.height * 0.7).clamp(240.0, 560.0)),
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyUpEvent) return KeyEventResult.ignored;
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowDown) {
              _move(1, entries.length);
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.arrowUp) {
              _move(-1, entries.length);
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
              if (entries.isNotEmpty) _run(entries[_selected]);
              return KeyEventResult.handled;
            }
            if (key == LogicalKeyboardKey.escape) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: SearchField(
                  controller: _controller,
                  autofocus: true,
                  hint: l10n.paletteHint,
                  textInputAction: TextInputAction.go,
                  onChanged: _onChanged,
                  onSubmitted: (_) {
                    if (entries.isNotEmpty) _run(entries[_selected]);
                  },
                ),
              ),
              Divider(height: 1, color: c.outlineSubtle),
              Flexible(
                child: entries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(l10n.paletteNoResults, textAlign: TextAlign.center, style: context.type.body.copyWith(color: c.textSecondary)),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemExtent: _rowHeight,
                        itemCount: entries.length,
                        itemBuilder: (context, i) => _PaletteRow(
                          entry: entries[i],
                          selected: i == _selected,
                          onTap: () => _run(entries[i]),
                          onHover: () => setState(() => _selected = i),
                        ),
                      ),
              ),
              Divider(height: 1, color: c.outlineSubtle),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(l10n.paletteFooter, style: context.type.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({required this.entry, required this.selected, required this.onTap, required this.onHover});

  final PaletteEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return MouseRegion(
      onHover: (_) {
        if (!selected) onHover();
      },
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? c.accent.withValues(alpha: 0.14) : null,
              borderRadius: context.radii.smAll,
            ),
            child: Row(
              children: [
                Icon(entry.icon, size: 20, color: selected ? c.accentText : c.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.body),
                ),
                if (entry.subtitle != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(entry.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.type.caption),
                  ),
                ],
                if (entry.shortcut != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(border: Border.all(color: c.outline), borderRadius: context.radii.xsAll),
                    child: Text(entry.shortcut!, style: context.type.caption.copyWith(fontSize: 11)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
