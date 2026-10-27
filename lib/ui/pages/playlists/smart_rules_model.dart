import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/library.dart';
import '../../../core/models/track.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../widgets/util/async_utils.dart';

/// Value kinds of smart-rule fields (decides operators and the input).
enum SmartValueKind { text, number, minutes, days, source, none }

/// Fields offered by the rule editor, in display order.
const smartFields = [
  SmartField.title,
  SmartField.artist,
  SmartField.album,
  SmartField.genre,
  SmartField.year,
  SmartField.duration,
  SmartField.playCount,
  SmartField.lastPlayed,
  SmartField.dateAdded,
  SmartField.source,
  SmartField.favorite,
  SmartField.downloaded,
];

/// Operators valid for [field].
List<SmartOperator> operatorsFor(SmartField field) => switch (field) {
      SmartField.title || SmartField.artist || SmartField.album || SmartField.genre => const [
          SmartOperator.contains,
          SmartOperator.notContains,
          SmartOperator.equals,
          SmartOperator.notEquals,
          SmartOperator.startsWith,
        ],
      SmartField.year || SmartField.duration || SmartField.playCount => const [
          SmartOperator.equals,
          SmartOperator.notEquals,
          SmartOperator.greaterThan,
          SmartOperator.lessThan,
        ],
      SmartField.lastPlayed || SmartField.dateAdded => const [SmartOperator.inLastDays, SmartOperator.notInLastDays],
      SmartField.source => const [SmartOperator.equals, SmartOperator.notEquals],
      SmartField.favorite || SmartField.downloaded => const [SmartOperator.isTrue, SmartOperator.isFalse],
    };

/// The input kind for [field] + [op].
SmartValueKind valueKindOf(SmartField field, SmartOperator op) {
  if (op == SmartOperator.isTrue || op == SmartOperator.isFalse) return SmartValueKind.none;
  return switch (field) {
    SmartField.year || SmartField.playCount => SmartValueKind.number,
    SmartField.duration => SmartValueKind.minutes,
    SmartField.lastPlayed || SmartField.dateAdded => SmartValueKind.days,
    SmartField.source => SmartValueKind.source,
    SmartField.favorite || SmartField.downloaded => SmartValueKind.none,
    _ => SmartValueKind.text,
  };
}

/// A sensible new rule for [field].
SmartRule defaultRuleFor(SmartField field) {
  final op = operatorsFor(field).first;
  final value = switch (valueKindOf(field, op)) {
    SmartValueKind.days => 30,
    SmartValueKind.source => 'local',
    SmartValueKind.none => null,
    _ => null,
  };
  return SmartRule(field: field, op: op, value: value);
}

/// Whether [rule] has a usable value.
bool ruleIsComplete(SmartRule rule) => switch (valueKindOf(rule.field, rule.op)) {
      SmartValueKind.none => true,
      SmartValueKind.text || SmartValueKind.source => (rule.value as String?)?.trim().isNotEmpty ?? false,
      _ => rule.value is num,
    };

String smartFieldLabel(AppLocalizations l10n, SmartField f) => switch (f) {
      SmartField.title => l10n.smartFieldTitle,
      SmartField.artist => l10n.smartFieldArtist,
      SmartField.album => l10n.smartFieldAlbum,
      SmartField.genre => l10n.smartFieldGenre,
      SmartField.year => l10n.smartFieldYear,
      SmartField.duration => l10n.smartFieldDuration,
      SmartField.playCount => l10n.smartFieldPlayCount,
      SmartField.lastPlayed => l10n.smartFieldLastPlayed,
      SmartField.dateAdded => l10n.smartFieldDateAdded,
      SmartField.source => l10n.smartFieldSource,
      SmartField.favorite => l10n.smartFieldFavorite,
      SmartField.downloaded => l10n.smartFieldDownloaded,
    };

String smartOperatorLabel(AppLocalizations l10n, SmartOperator op) => switch (op) {
      SmartOperator.contains => l10n.smartOpContains,
      SmartOperator.notContains => l10n.smartOpNotContains,
      SmartOperator.equals => l10n.smartOpEquals,
      SmartOperator.notEquals => l10n.smartOpNotEquals,
      SmartOperator.startsWith => l10n.smartOpStartsWith,
      SmartOperator.greaterThan => l10n.smartOpGreaterThan,
      SmartOperator.lessThan => l10n.smartOpLessThan,
      SmartOperator.inLastDays => l10n.smartOpInLastDays,
      SmartOperator.notInLastDays => l10n.smartOpNotInLastDays,
      SmartOperator.isTrue => l10n.smartOpIsTrue,
      SmartOperator.isFalse => l10n.smartOpIsFalse,
    };

/// Library facts needed to evaluate rules in the editor's live preview.
@immutable
class SmartPreviewContext {
  const SmartPreviewContext({
    required this.tracks,
    required this.favorites,
    required this.downloaded,
    required this.playCounts,
    required this.lastPlayed,
    required this.now,
  });

  final List<Track> tracks;
  final Set<String> favorites;
  final Set<String> downloaded;
  final Map<String, int> playCounts;
  final Map<String, DateTime> lastPlayed;
  final DateTime now;
}

/// Preview result: matching count, and whether it is approximate (rules on
/// "date added" can't be evaluated outside the library database).
@immutable
class SmartPreview {
  const SmartPreview(this.count, {this.approximate = false});

  final int count;
  final bool approximate;
}

/// Evaluates [rules] against [ctx] (the library applies the same rules in
/// SQL when the playlist is opened).
SmartPreview evaluateSmartRules(SmartPlaylistRules rules, SmartPreviewContext ctx) {
  final usable = [for (final r in rules.rules) if (ruleIsComplete(r)) r];
  final approximate = usable.any((r) => r.field == SmartField.dateAdded);
  var count = 0;
  for (final t in ctx.tracks) {
    if (usable.isEmpty) {
      count++;
      continue;
    }
    final results = usable.map((r) => _matches(r, t, ctx));
    if (rules.matchAll ? results.every((x) => x) : results.any((x) => x)) count++;
  }
  if (rules.limit != null && count > rules.limit!) count = rules.limit!;
  return SmartPreview(count, approximate: approximate);
}

String _fold(String s) => s.toLowerCase().trim();

bool _text(SmartOperator op, List<String> haystacks, String needle) {
  final n = _fold(needle);
  bool one(String h) => switch (op) {
        SmartOperator.contains => _fold(h).contains(n),
        SmartOperator.equals => _fold(h) == n,
        SmartOperator.startsWith => _fold(h).startsWith(n),
        _ => false,
      };
  return switch (op) {
    SmartOperator.notContains => !haystacks.any((h) => _fold(h).contains(n)),
    SmartOperator.notEquals => !haystacks.any((h) => _fold(h) == n),
    _ => haystacks.any(one),
  };
}

bool _number(SmartOperator op, num? actual, num expected) {
  if (actual == null) return op == SmartOperator.notEquals;
  return switch (op) {
    SmartOperator.equals => actual == expected,
    SmartOperator.notEquals => actual != expected,
    SmartOperator.greaterThan => actual > expected,
    SmartOperator.lessThan => actual < expected,
    _ => false,
  };
}

bool _matches(SmartRule r, Track t, SmartPreviewContext ctx) {
  final v = r.value;
  switch (r.field) {
    case SmartField.title:
      return _text(r.op, [t.title], v as String);
    case SmartField.artist:
      return _text(r.op, [for (final a in t.artists) a.name, ?t.albumArtist], v as String);
    case SmartField.album:
      return _text(r.op, [t.album ?? ''], v as String);
    case SmartField.genre:
      return _text(r.op, [t.genre ?? ''], v as String);
    case SmartField.source:
      return r.op == SmartOperator.equals ? t.sourceId == v : t.sourceId != v;
    case SmartField.year:
      return _number(r.op, t.year, v as num);
    case SmartField.duration:
      return _number(r.op, t.duration?.inSeconds, v as num);
    case SmartField.playCount:
      return _number(r.op, ctx.playCounts[t.id] ?? 0, v as num);
    case SmartField.lastPlayed:
      final last = ctx.lastPlayed[t.id];
      final since = ctx.now.subtract(Duration(days: (v as num).toInt()));
      final recent = last != null && last.isAfter(since);
      return r.op == SmartOperator.inLastDays ? recent : !recent;
    case SmartField.dateAdded:
      return true; // Not known outside the database (preview is approximate).
    case SmartField.favorite:
      final fav = ctx.favorites.contains(t.id);
      return r.op == SmartOperator.isTrue ? fav : !fav;
    case SmartField.downloaded:
      final dl = ctx.downloaded.contains(t.id);
      return r.op == SmartOperator.isTrue ? dl : !dl;
  }
}

/// Loads the preview context once per editor session.
final smartPreviewContextProvider = FutureProvider.autoDispose<SmartPreviewContext>(
  (ref) async {
    final tracks = await ref.watch(trackRepositoryProvider).query(const TrackQuery());
    final favorites = (await ref.watch(favoritesRepositoryProvider).favorites()).map((t) => t.id).toSet();
    final dm = ref.watch(downloadManagerProvider);
    final downloaded = {for (final t in tracks) if (dm.isDownloaded(t.id)) t.id};
    final history = await ref.watch(historyRepositoryProvider).history(limit: 5000);
    final counts = <String, int>{};
    final last = <String, DateTime>{};
    for (final r in history) {
      counts[r.track.id] = (counts[r.track.id] ?? 0) + 1;
      final prev = last[r.track.id];
      if (prev == null || r.playedAt.isAfter(prev)) last[r.track.id] = r.playedAt;
    }
    return SmartPreviewContext(
      tracks: tracks,
      favorites: favorites,
      downloaded: downloaded,
      playCounts: counts,
      lastPlayed: last,
      now: DateTime.now(),
    );
  },
  retry: noRetry,
);
