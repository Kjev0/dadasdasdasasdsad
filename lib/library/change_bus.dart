import 'dart:async';

import '../core/contracts/library.dart';

/// Broadcasts coarse library change notifications. Changes notified in the
/// same microtask are coalesced into one event, so a bulk operation (a scan
/// batch, a backup import) produces a single refresh in the UI.
class LibraryChangeBusImpl implements LibraryChangeBus {
  final _controller = StreamController<Set<LibraryTopic>>.broadcast();
  Set<LibraryTopic>? _pending;

  @override
  Stream<Set<LibraryTopic>> get changes => _controller.stream;

  /// Notifies listeners that [topics] changed.
  void notify(Set<LibraryTopic> topics) {
    if (topics.isEmpty || _controller.isClosed) return;
    final pending = _pending;
    if (pending != null) {
      pending.addAll(topics);
      return;
    }
    _pending = {...topics};
    scheduleMicrotask(() {
      final batch = _pending;
      _pending = null;
      if (batch != null && !_controller.isClosed) _controller.add(Set.unmodifiable(batch));
    });
  }

  Future<void> dispose() => _controller.close();
}

/// Notifies [bus] when it is a [LibraryChangeBusImpl] (other implementations
/// of the contract are read-only from the library's point of view).
void notifyLibrary(LibraryChangeBus bus, Set<LibraryTopic> topics) {
  if (bus is LibraryChangeBusImpl) bus.notify(topics);
}
