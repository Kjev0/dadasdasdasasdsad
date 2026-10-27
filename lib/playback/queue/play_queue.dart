import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../../core/models/playback.dart';
import '../../core/models/track.dart';

/// Origin used for items appended by the smart queue.
const smartQueueOrigin = 'smart-queue';

/// Result of [PlayQueue.remove].
class QueueRemoval {
  const QueueRemoval({required this.item, required this.wasCurrent});

  final QueueItem item;

  /// True when the removed item was the current one; the queue then points
  /// at the item that followed it (or the new last item).
  final bool wasCurrent;
}

/// The play queue: pure Dart, no I/O, no timers.
///
/// Keeps two lists of the same [QueueItem]s:
/// * the *original order* (as the user/collection defined it), and
/// * the *play order* ([state].items) which equals the original order unless
///   shuffle is on.
///
/// Shuffle (Fisher–Yates) keeps the current item playing as the first item
/// and keeps manually added upcoming items ("Play next"/"Add to queue")
/// directly after it; turning shuffle off restores the original order and
/// moves the current position to where the current item sits there.
class PlayQueue {
  PlayQueue({math.Random? random, String Function()? newUid})
      : _random = random ?? math.Random(),
        _newUid = newUid ?? _uuidV4;

  static String _uuidV4() => const Uuid().v4();

  final math.Random _random;
  final String Function() _newUid;

  final List<QueueItem> _order = [];
  final List<QueueItem> _original = [];
  int _index = -1;
  bool _shuffle = false;
  String? _originLabel;

  /// Repeat mode used by [advance]/[peekNext]/[goPrevious].
  RepeatMode repeat = RepeatMode.off;

  QueueState get state =>
      QueueState(items: List.unmodifiable(_order), currentIndex: _index, originLabel: _originLabel);

  List<QueueItem> get items => List.unmodifiable(_order);
  List<QueueItem> get originalOrder => List.unmodifiable(_original);
  int get currentIndex => _index;
  int get length => _order.length;
  bool get isEmpty => _order.isEmpty;
  bool get shuffle => _shuffle;
  String? get originLabel => _originLabel;

  QueueItem? get current => _index >= 0 && _index < _order.length ? _order[_index] : null;

  // ---------------------------------------------------------------- editing

  /// Replaces everything. [startIndex] refers to [tracks]. With [shuffle] the
  /// start item plays first and the rest is shuffled.
  List<QueueItem> replace(
    List<Track> tracks, {
    int startIndex = 0,
    String? origin,
    String? originLabel,
    bool shuffle = false,
  }) {
    final created = [for (final t in tracks) QueueItem(uid: _newUid(), track: t, origin: origin)];
    _order
      ..clear()
      ..addAll(created);
    _original
      ..clear()
      ..addAll(created);
    _originLabel = originLabel;
    _index = created.isEmpty ? -1 : startIndex.clamp(0, created.length - 1);
    _shuffle = false;
    if (shuffle) setShuffle(true);
    return created;
  }

  /// Appends [tracks] to the end (both orders).
  List<QueueItem> enqueue(List<Track> tracks, {String? origin, bool manual = true}) {
    final created = [
      for (final t in tracks) QueueItem(uid: _newUid(), track: t, origin: origin, addedManually: manual),
    ];
    // When nothing is current the index stays -1; the engine decides whether
    // to start playing.
    _order.addAll(created);
    _original.addAll(created);
    return created;
  }

  /// Inserts [tracks] directly after the current item (both orders).
  List<QueueItem> playNext(List<Track> tracks, {String? origin}) {
    final created = [
      for (final t in tracks) QueueItem(uid: _newUid(), track: t, origin: origin, addedManually: true),
    ];
    final cur = current;
    _order.insertAll(cur == null ? 0 : _index + 1, created);
    final originalPos = cur == null ? 0 : _original.indexOf(cur) + 1;
    _original.insertAll(originalPos, created);
    return created;
  }

  /// Removes the item with [uid]. Returns null when not found.
  QueueRemoval? remove(String uid) {
    final pos = _order.indexWhere((i) => i.uid == uid);
    if (pos < 0) return null;
    final item = _order.removeAt(pos);
    _original.removeWhere((i) => i.uid == uid);
    final wasCurrent = pos == _index;
    if (pos < _index) {
      _index--;
    } else if (wasCurrent) {
      if (_order.isEmpty) {
        _index = -1;
      } else if (_index >= _order.length) {
        _index = _order.length - 1;
      }
    }
    if (_order.isEmpty) _originLabel = null;
    return QueueRemoval(item: item, wasCurrent: wasCurrent);
  }

  /// Moves the item at play-order index [from] so that it ends up at index
  /// [to] (list semantics: remove, then insert). Returns false for invalid
  /// indices. `ReorderableListView` callers must subtract one from `newIndex`
  /// when it is greater than `oldIndex`.
  bool move(int from, int to) {
    if (from < 0 || from >= _order.length || to < 0 || to >= _order.length) return false;
    if (from == to) return true;
    final item = _order.removeAt(from);
    _order.insert(to, item);
    if (_index == from) {
      _index = to;
    } else if (from < _index && to >= _index) {
      _index--;
    } else if (from > _index && to <= _index) {
      _index++;
    }
    if (!_shuffle) {
      // Play order is the original order: keep them identical.
      _original
        ..clear()
        ..addAll(_order);
    }
    return true;
  }

  /// Clears the queue; keeps only the current item when [keepCurrent].
  void clear({bool keepCurrent = true}) {
    final cur = current;
    _order.clear();
    _original.clear();
    if (keepCurrent && cur != null) {
      _order.add(cur);
      _original.add(cur);
      _index = 0;
    } else {
      _index = -1;
      _originLabel = null;
    }
  }

  void setShuffle(bool enabled) {
    if (enabled == _shuffle) return;
    _shuffle = enabled;
    final cur = current;
    if (enabled) {
      final manualUpcoming = <QueueItem>[
        for (var i = _index + 1; i < _order.length; i++)
          if (_order[i].addedManually) _order[i],
      ];
      final keep = {?cur, ...manualUpcoming};
      final rest = [for (final i in _order) if (!keep.contains(i)) i];
      _fisherYates(rest);
      _order
        ..clear()
        ..addAll([?cur, ...manualUpcoming, ...rest]);
      _index = cur == null ? -1 : 0;
    } else {
      _order
        ..clear()
        ..addAll(_original);
      _index = cur == null ? -1 : _order.indexOf(cur);
    }
  }

  void _fisherYates(List<QueueItem> list) {
    for (var i = list.length - 1; i > 0; i--) {
      final j = _random.nextInt(i + 1);
      final tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }

  /// Makes [index] (play order) current. Returns false when out of range.
  bool skipToIndex(int index) {
    if (index < 0 || index >= _order.length) return false;
    _index = index;
    return true;
  }

  // ------------------------------------------------------------- navigation

  /// Index that [advance] would move to, or null when the queue would end.
  /// [manual] is a user "next" (ignores repeat-one, wraps like repeat-all).
  int? peekNextIndex({bool manual = false}) {
    if (_order.isEmpty) return null;
    if (_index < 0) return 0;
    if (!manual && repeat == RepeatMode.one) return _index;
    if (_index + 1 < _order.length) return _index + 1;
    final wrap = repeat == RepeatMode.all || (manual && repeat == RepeatMode.one);
    return wrap ? 0 : null;
  }

  QueueItem? peekNext({bool manual = false}) {
    final i = peekNextIndex(manual: manual);
    return i == null ? null : _order[i];
  }

  /// Moves to the next item. Returns the new current item or null when the
  /// queue ended (the position is then left unchanged).
  QueueItem? advance({bool manual = false}) {
    final i = peekNextIndex(manual: manual);
    if (i == null) return null;
    _index = i;
    return _order[i];
  }

  int? peekPreviousIndex() {
    if (_order.isEmpty) return null;
    if (_index > 0) return _index - 1;
    if (_index == 0 && repeat != RepeatMode.off && _order.length > 1) return _order.length - 1;
    return null;
  }

  /// Moves to the previous item; null when there is none (caller restarts).
  QueueItem? goPrevious() {
    final i = peekPreviousIndex();
    if (i == null) return null;
    _index = i;
    return _order[i];
  }

  /// Most recent items up to and including the current one (newest last).
  List<Track> recentTracks({int limit = 20}) {
    if (_index < 0) return const [];
    final start = math.max(0, _index + 1 - limit);
    return [for (final i in _order.sublist(start, _index + 1)) i.track];
  }

  // ------------------------------------------------------------ persistence

  Map<String, Object?> toJson() => {
        'items': [for (final i in _order) i.toJson()],
        'original': [for (final i in _original) i.uid],
        'index': _index,
        'shuffle': _shuffle,
        'repeat': repeat.name,
        if (_originLabel != null) 'originLabel': _originLabel,
      };

  /// Restores a queue written by [toJson]. Tolerates partial/corrupt data.
  void restoreJson(Map<String, Object?> json) {
    final items = <QueueItem>[];
    for (final raw in (json['items'] as List? ?? const [])) {
      if (raw is! Map) continue;
      try {
        items.add(QueueItem.fromJson(raw.cast<String, Object?>()));
      } catch (_) {
        // Skip unreadable entries rather than losing the whole queue.
      }
    }
    final byUid = {for (final i in items) i.uid: i};
    final originalUids = (json['original'] as List? ?? const []).whereType<String>().toList();
    final original = [for (final uid in originalUids) ?byUid[uid]];
    final consistent = original.length == items.length && original.toSet().length == items.length;

    _order
      ..clear()
      ..addAll(items);
    _original
      ..clear()
      ..addAll(consistent ? original : items);
    _shuffle = consistent && (json['shuffle'] as bool? ?? false);
    repeat = RepeatMode.values.asNameMap()[json['repeat']] ?? RepeatMode.off;
    _originLabel = json['originLabel'] as String?;
    final idx = (json['index'] as num?)?.toInt() ?? -1;
    _index = items.isEmpty ? -1 : idx.clamp(-1, items.length - 1);
  }
}
