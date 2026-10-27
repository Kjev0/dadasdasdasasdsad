import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/library.dart';
import '../../../core/sources/source_ids.dart';
import '../../design/context_ext.dart';
import '../../widgets/chips/badges.dart';
import '../../widgets/controls/fermata_button.dart';
import '../library/shared/page_layout.dart';
import '../library/shared/track_helpers.dart';
import '../library/tracks/library_query.dart';
import 'smart_rules_model.dart';

/// Result of the smart playlist editor.
typedef SmartPlaylistDraft = ({String name, SmartPlaylistRules rules});

class _RuleDraft {
  _RuleDraft(this.id, this.field, this.op, Object? value) : text = TextEditingController(text: _initialText(field, value)), source = value is String ? value : null;

  final int id;
  SmartField field;
  SmartOperator op;
  final TextEditingController text;
  String? source;

  static String _initialText(SmartField field, Object? value) {
    if (value == null) return '';
    if (field == SmartField.duration && value is num) return '${(value / 60).round()}';
    return '$value';
  }

  SmartRule build() {
    final kind = valueKindOf(field, op);
    final raw = text.text.trim();
    final Object? value = switch (kind) {
      SmartValueKind.none => null,
      SmartValueKind.text => raw.isEmpty ? null : raw,
      SmartValueKind.source => source,
      SmartValueKind.minutes => int.tryParse(raw) == null ? null : int.parse(raw) * 60,
      SmartValueKind.number || SmartValueKind.days => int.tryParse(raw),
    };
    return SmartRule(field: field, op: op, value: value);
  }
}

/// Smart playlist rule editor: rows of field / operator / value, match
/// all or any, limit, sort, and a live count of matching tracks.
class SmartRuleEditor extends ConsumerStatefulWidget {
  const SmartRuleEditor({super.key, this.name, this.initial});

  final String? name;
  final SmartPlaylistRules? initial;

  static Future<SmartPlaylistDraft?> show(BuildContext context, {String? name, SmartPlaylistRules? initial}) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final editor = SmartRuleEditor(name: name, initial: initial);
    return showDialog<SmartPlaylistDraft>(
      context: context,
      builder: (_) => compact ? Dialog.fullscreen(child: editor) : Dialog(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720), child: editor)),
    );
  }

  @override
  ConsumerState<SmartRuleEditor> createState() => _SmartRuleEditorState();
}

class _SmartRuleEditorState extends ConsumerState<SmartRuleEditor> {
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _limit = TextEditingController(text: widget.initial?.limit?.toString() ?? '');
  final _drafts = <_RuleDraft>[];
  var _nextId = 0;
  late bool _matchAll = widget.initial?.matchAll ?? true;
  late TrackSortField _sort = widget.initial?.sort ?? TrackSortField.dateAdded;
  late bool _descending = widget.initial?.descending ?? true;
  Timer? _debounce;
  late SmartPlaylistRules _previewRules;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial?.rules ?? [defaultRuleFor(SmartField.artist)];
    for (final r in initial) {
      _drafts.add(_RuleDraft(_nextId++, r.field, r.op, r.value));
    }
    _previewRules = _rules();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    _limit.dispose();
    for (final d in _drafts) {
      d.text.dispose();
    }
    super.dispose();
  }

  SmartPlaylistRules _rules() => SmartPlaylistRules(
        rules: [for (final d in _drafts) d.build()],
        matchAll: _matchAll,
        limit: int.tryParse(_limit.text.trim()),
        sort: _sort,
        descending: _descending,
      );

  /// Rebuilds now and refreshes the preview after a short pause.
  void _changed() {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _previewRules = _rules());
    });
  }

  bool get _valid {
    if (_name.text.trim().isEmpty || _drafts.isEmpty) return false;
    return _drafts.every((d) => ruleIsComplete(d.build()));
  }

  void _addRule() {
    _drafts.add(_RuleDraft(_nextId++, SmartField.genre, operatorsFor(SmartField.genre).first, null));
    _changed();
  }

  void _removeRule(_RuleDraft d) {
    _drafts.remove(d);
    d.text.dispose();
    _changed();
  }

  void _setField(_RuleDraft d, SmartField field) {
    final def = defaultRuleFor(field);
    d.field = field;
    d.op = def.op;
    d.text.text = def.value is num ? '${def.value}' : '';
    d.source = def.value is String ? def.value as String : null;
    _changed();
  }

  Widget _valueInput(_RuleDraft d) {
    final l10n = context.l10n;
    final kind = valueKindOf(d.field, d.op);
    switch (kind) {
      case SmartValueKind.none:
        return const SizedBox.shrink();
      case SmartValueKind.source:
        final registry = ref.read(sourceRegistryProvider);
        final order = ref.read(settingsProvider).services.providerOrder;
        final ids = orderByPreference({SourceIds.local, for (final s in registry.all) s.id}, order);
        return DropdownButton<String>(
          key: ValueKey('rule-${d.id}-source'),
          value: ids.contains(d.source) ? d.source : null,
          hint: Text(l10n.smartPickSource),
          items: [for (final id in ids) DropdownMenuItem(value: id, child: Text(id == SourceIds.local ? l10n.libraryLocalFiles : sourceDisplayName(ref, id)))],
          onChanged: (v) {
            d.source = v;
            _changed();
          },
        );
      default:
        final numeric = kind != SmartValueKind.text;
        final suffix = switch (kind) {
          SmartValueKind.minutes => l10n.smartUnitMinutes,
          SmartValueKind.days => l10n.smartUnitDays,
          _ => null,
        };
        return SizedBox(
          width: numeric ? 120 : 200,
          child: TextField(
            key: ValueKey('rule-${d.id}-value'),
            controller: d.text,
            keyboardType: numeric ? TextInputType.number : TextInputType.text,
            inputFormatters: numeric ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)] : null,
            decoration: InputDecoration(isDense: true, hintText: l10n.smartValue, suffixText: suffix),
            onChanged: (_) => _changed(),
          ),
        );
    }
  }

  Widget _ruleRow(_RuleDraft d) {
    final l10n = context.l10n;
    return Padding(
      key: ValueKey('rule-${d.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<SmartField>(
                  key: ValueKey('rule-${d.id}-field'),
                  value: d.field,
                  items: [for (final f in smartFields) DropdownMenuItem(value: f, child: Text(smartFieldLabel(l10n, f)))],
                  onChanged: (f) => f == null ? null : _setField(d, f),
                ),
                DropdownButton<SmartOperator>(
                  key: ValueKey('rule-${d.id}-op'),
                  value: d.op,
                  items: [for (final o in operatorsFor(d.field)) DropdownMenuItem(value: o, child: Text(smartOperatorLabel(l10n, o)))],
                  onChanged: (o) {
                    if (o == null) return;
                    d.op = o;
                    _changed();
                  },
                ),
                _valueInput(d),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.smartRemoveRule,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            onPressed: _drafts.length > 1 ? () => _removeRule(d) : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = context.colors;
    final ctx = ref.watch(smartPreviewContextProvider);
    final preview = ctx.value == null ? null : evaluateSmartRules(_previewRules, ctx.value!);
    final previewText = preview == null
        ? l10n.smartPreviewLoading
        : (preview.approximate ? l10n.smartPreviewApprox(preview.count) : l10n.smartPreviewCount(preview.count));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
          child: Row(
            children: [
              Expanded(child: Text(widget.initial == null ? l10n.smartNewTitle : l10n.smartEditTitle, style: context.type.title)),
              IconButton(tooltip: l10n.actionClose, icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            children: [
              TextField(
                key: const ValueKey('smart-name'),
                controller: _name,
                decoration: InputDecoration(labelText: l10n.shellPlaylistNameHint),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.smartMatch, style: context.type.label),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: true, label: Text(l10n.smartMatchAll)),
                      ButtonSegment(value: false, label: Text(l10n.smartMatchAny)),
                    ],
                    selected: {_matchAll},
                    onSelectionChanged: (s) {
                      _matchAll = s.first;
                      _changed();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final d in _drafts) _ruleRow(d),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('smart-add-rule'),
                  onPressed: _addRule,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l10n.smartAddRule),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 160,
                    child: TextField(
                      key: const ValueKey('smart-limit'),
                      controller: _limit,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(5)],
                      decoration: InputDecoration(labelText: l10n.smartLimit, hintText: l10n.smartNoLimit, isDense: true),
                      onChanged: (_) => _changed(),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.pagesSort, style: context.type.label),
                      const SizedBox(width: 8),
                      DropdownButton<TrackSortField>(
                        key: const ValueKey('smart-sort'),
                        value: _sort,
                        items: [
                          for (final f in [...librarySortFields, TrackSortField.lastPlayed])
                            DropdownMenuItem(value: f, child: Text(sortFieldLabel(l10n, f))),
                        ],
                        onChanged: (f) {
                          if (f == null) return;
                          _sort = f;
                          _changed();
                        },
                      ),
                      IconButton(
                        tooltip: _descending ? l10n.pagesDescending : l10n.pagesAscending,
                        icon: Icon(_descending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded),
                        onPressed: () {
                          _descending = !_descending;
                          _changed();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.outlineSubtle))),
          child: Row(
            children: [
              Icon(Icons.filter_list_rounded, size: 18, color: c.accentText),
              const SizedBox(width: 8),
              Expanded(child: Text(previewText, key: const ValueKey('smart-preview'), style: context.type.bodySmall)),
              if (!isCompactWidth(context))
                FermataButton(label: l10n.actionCancel, variant: FermataButtonVariant.ghost, onPressed: () => Navigator.of(context).pop()),
              const SizedBox(width: 8),
              FermataButton(
                key: const ValueKey('smart-save'),
                label: l10n.actionSave,
                onPressed: _valid ? () => Navigator.of(context).pop((name: _name.text.trim(), rules: _rules())) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
