import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../../app/providers.dart';
import '../../../core/contracts/music_source.dart';
import '../../../core/errors.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/matching.dart';
import '../../../core/models/track.dart';
import '../../../core/sources/source_ids.dart';
import '../../../core/util/cancel_token.dart';
import '../../actions/routes.dart';
import '../../design/context_ext.dart';
import '../../widgets/controls/fermata_button.dart';
import '../../widgets/feedback/messages.dart';
import '../../widgets/feedback/toast.dart';
import '../settings/settings_hooks.dart';
import 'import_format.dart';
import 'import_steps.dart';

final _log = Logger('ui.import');

/// Most liked tracks fetched for one import (pages of the provider's size).
const maxLikedTracks = 10000;

sealed class _What {
  const _What();
}

class _PlaylistWhat extends _What {
  const _PlaylistWhat(this.playlist);
  final Playlist playlist;
}

class _LinkWhat extends _What {
  const _LinkWhat(this.link);
  final String link;
}

class _LikedWhat extends _What {
  const _LikedWhat();
}

class _M3uWhat extends _What {
  const _M3uWhat(this.name, this.tracks);
  final String name;
  final List<Track> tracks;
}

/// Playlist import wizard: source → playlist / liked tracks / link / M3U
/// file → targets and options → start (then the review page shows live
/// progress and the review).
class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  int _step = 0;
  MusicSource? _source;
  _What? _what;
  List<ImportTarget> _targets = [];
  late ReviewMode _reviewMode;
  late double _threshold;
  late bool _skipUnavailable;
  String? _preferred;
  late bool _allowPreview;
  bool _starting = false;
  int? _fetched;
  CancelToken? _cancel;

  @override
  void initState() {
    super.initState();
    final imp = ref.read(settingsProvider).import;
    _reviewMode = imp.reviewMode;
    _threshold = imp.autoAcceptThreshold;
    _skipUnavailable = imp.skipUnavailable;
    _preferred = imp.preferredSource;
    _allowPreview = imp.allowPreviewOnly;
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  String? get _originId => _what is _M3uWhat ? SourceIds.local : _source?.id;

  void _computeTargets() {
    final eligible = eligibleImportTargets(
      ref.read(sourceRegistryProvider).ordered,
      ref.read(settingsProvider),
      origin: _originId,
      allowPreviewOnly: _allowPreview,
    );
    _targets = mergeTargets(_targets, eligible);
  }

  void _choose(_What what) {
    setState(() {
      _what = what;
      _computeTargets();
      _step = 2;
    });
  }

  Future<void> _pickM3u() async {
    final l10n = context.l10n;
    final file = await ref.read(fileDialogsProvider).pickFile(title: l10n.importM3uTitle, extensions: const ['m3u', 'm3u8']);
    if (file == null || !mounted) return;
    final path = file.path;
    if (path == null) {
      showFermataToast(context, l10n.importM3uUnreadable, isError: true);
      return;
    }
    try {
      final tracks = await ref.read(localLibraryProvider).importM3u(path);
      if (!mounted) return;
      if (tracks.isEmpty) {
        showFermataToast(context, l10n.importM3uEmpty, isError: true);
        return;
      }
      setState(() => _source = null);
      _choose(_M3uWhat(p.basenameWithoutExtension(file.name), tracks));
    } catch (e) {
      _log.info('M3U import failed: $e');
      if (mounted) showFermataToast(context, l10n.importM3uUnreadable, isError: true);
    }
  }

  Future<List<Track>> _fetchLiked(MusicSource source, CancelToken cancel) async {
    final tracks = <Track>[];
    String? cursor;
    do {
      cancel.throwIfCanceled();
      final page = await source.userLikedTracks(cursor: cursor, cancel: cancel);
      tracks.addAll(page.items);
      if (mounted) setState(() => _fetched = tracks.length);
      cursor = page.nextCursor;
    } while (cursor != null && tracks.length < maxLikedTracks);
    return tracks;
  }

  Future<void> _start() async {
    final l10n = context.l10n;
    final what = _what;
    if (what == null) return;
    final imports = ref.read(playlistImportProvider);
    final options = MatchOptions(
      targetSources: targetIds(_targets),
      reviewMode: _reviewMode,
      autoAcceptThreshold: _threshold,
      skipUnavailable: _skipUnavailable,
      preferredSource: _preferred != null && targetIds(_targets).contains(_preferred) ? _preferred : null,
      allowPreviewOnly: _allowPreview,
    );
    final cancel = _cancel = CancelToken();
    setState(() {
      _starting = true;
      _fetched = null;
    });
    try {
      final String id;
      switch (what) {
        case _PlaylistWhat(:final playlist):
          id = await imports.start(sourceId: _source!.id, playlistIdOrUrl: playlist.sourcePlaylistId ?? playlist.id, options: options);
        case _LinkWhat(:final link):
          id = await imports.start(sourceId: _source!.id, playlistIdOrUrl: link, options: options);
        case _LikedWhat():
          final tracks = await _fetchLiked(_source!, cancel);
          if (tracks.isEmpty) throw StateError('empty');
          id = await imports.startWithTracks(
            sourceId: _source!.id,
            name: l10n.importLikedName(_source!.displayName),
            tracks: tracks,
            options: options,
          );
        case _M3uWhat(:final name, :final tracks):
          id = await imports.startWithTracks(sourceId: SourceIds.local, name: name, tracks: tracks, options: options);
      }
      if (mounted) context.go(AppRoutes.importSession(id));
    } on OperationCanceledException {
      // The user canceled fetching liked tracks.
    } catch (e) {
      _log.info('Starting import failed: ${e.runtimeType}');
      if (mounted) {
        final registry = ref.read(sourceRegistryProvider);
        final msg = e is StateError
            ? l10n.importNothingToImport
            : errorMessageFor(l10n, e, sourceName: (id) => registry.byId(id)?.displayName ?? id) ?? l10n.importStartFailed;
        showFermataToast(context, msg, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
          _fetched = null;
        });
      }
    }
  }

  String _summary() {
    final l10n = context.l10n;
    return switch (_what) {
      _PlaylistWhat(:final playlist) => l10n.importSummaryPlaylist(playlist.name, _source!.displayName),
      _LinkWhat() => l10n.importSummaryLink(_source!.displayName),
      _LikedWhat() => l10n.importSummaryLiked(_source!.displayName),
      _M3uWhat(:final name, :final tracks) => l10n.importSummaryM3u(name, tracks.length),
      null => '',
    };
  }

  void _back() {
    setState(() {
      if (_step == 2 && _what is _M3uWhat) {
        _step = 0;
      } else {
        _step = (_step - 1).clamp(0, 2);
      }
      if (_step == 0) _source = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final Widget body = switch (_step) {
      0 => ImportSourceStep(
          onSource: (s) => setState(() {
            _source = s;
            _step = 1;
          }),
          onM3u: _pickM3u,
        ),
      1 => ImportWhatStep(
          source: _source!,
          onPlaylist: (p) => _choose(_PlaylistWhat(p)),
          onLiked: () => _choose(const _LikedWhat()),
          onLink: (l) => _choose(_LinkWhat(l)),
        ),
      _ => ImportOptionsStep(
          summary: _summary(),
          targets: _targets,
          onTargetsChanged: () => setState(() {}),
          reviewMode: _reviewMode,
          onReviewMode: (v) => setState(() => _reviewMode = v),
          threshold: _threshold,
          onThreshold: (v) => setState(() => _threshold = v),
          skipUnavailable: _skipUnavailable,
          onSkipUnavailable: (v) => setState(() => _skipUnavailable = v),
          preferred: _preferred,
          onPreferred: (v) => setState(() => _preferred = v),
          allowPreview: _allowPreview,
          onAllowPreview: (v) => setState(() {
            _allowPreview = v;
            _computeTargets();
          }),
        ),
    };
    final steps = [l10n.importStepSource, l10n.importStepPlaylist, l10n.importStepOptions];

    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final pad = constraints.maxWidth < 600 ? 16.0 : 32.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      if (_step > 0)
                        IconButton(
                          key: const ValueKey('import.back'),
                          tooltip: l10n.importBack,
                          onPressed: _starting ? null : _back,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      Expanded(child: Semantics(header: true, child: Text(l10n.importTitle, style: context.type.headline))),
                    ]),
                    const SizedBox(height: 8),
                    Semantics(
                      label: l10n.importStepOf(_step + 1, steps.length, steps[_step]),
                      excludeSemantics: true,
                      // Narrow windows only label the current step.
                      child: Row(children: [
                        for (var i = 0; i < steps.length; i++) ...[
                          if (i > 0) Expanded(child: Divider(color: i <= _step ? c.accent : c.outlineSubtle)),
                          _StepDot(
                            index: i,
                            label: constraints.maxWidth >= 520 || i == _step ? steps[i] : null,
                            active: i == _step,
                            done: i < _step,
                          ),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 24),
                    body,
                    if (_step == 2) ...[
                      const SizedBox(height: 8),
                      if (_starting && _fetched != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(l10n.importFetchingLiked(_fetched!), style: context.type.bodySmall),
                        ),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        FermataButton(
                          key: const ValueKey('import.start'),
                          label: l10n.importStart,
                          icon: Icons.playlist_add_check_rounded,
                          busy: _starting,
                          onPressed: readyTargets(_targets) == 0 ? null : _start,
                        ),
                        if (_starting && _what is _LikedWhat)
                          FermataButton(
                            label: l10n.actionCancel,
                            variant: FermataButtonVariant.secondary,
                            onPressed: () => _cancel?.cancel(),
                          ),
                      ]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.index, required this.label, required this.active, required this.done});

  final int index;
  final String? label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = active || done;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: on ? c.accent : c.surfaceHigh),
        child: done
            ? Icon(Icons.check_rounded, size: 14, color: c.onAccent)
            : Text('${index + 1}', style: context.type.caption.copyWith(color: on ? c.onAccent : c.textSecondary)),
      ),
      if (label != null) ...[
        const SizedBox(width: 6),
        Text(label!, style: context.type.caption.copyWith(color: active ? c.textPrimary : c.textSecondary)),
      ],
      const SizedBox(width: 6),
    ]);
  }
}
