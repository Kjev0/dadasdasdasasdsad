import 'dart:async';

import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/util/cancel_token.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:fermata/sources/registry/source_registry_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late SettingsStore settings;
  late SourceRegistryImpl registry;

  SettingsStore withServices(List<String> order, {Set<String> disabled = const {}}) => SettingsStore.inMemory(
    AppSettings(
      services: ServicesSettings(providerOrder: order, disabledSources: disabled),
    ),
  );

  tearDown(() => registry.dispose());

  group('ordering', () {
    test('follows providerOrder, unknown sources last in registration order, disabled excluded', () {
      settings = withServices(['soundcloud', 'audius', 'local', 'deezer'], disabled: {'deezer'});
      registry = SourceRegistryImpl(settings: settings);
      for (final id in ['local', 'deezer', 'plugin-b', 'audius', 'plugin-a', 'soundcloud']) {
        registry.register(FakeSource(id));
      }
      expect(registry.ordered.map((s) => s.id), ['soundcloud', 'audius', 'local', 'plugin-b', 'plugin-a']);
      expect(registry.all.map((s) => s.id), ['local', 'deezer', 'plugin-b', 'audius', 'plugin-a', 'soundcloud']);
      expect(registry.byId('deezer'), isNotNull, reason: 'disabled sources stay reachable by id');
      expect(registry.isEnabled('deezer'), isFalse);
      expect(registry.require('audius').id, 'audius');
      expect(() => registry.require('nope'), throwsStateError);
      expect(() => registry.register(FakeSource('local')), throwsArgumentError);
    });

    test('reacts to settings changes', () async {
      settings = withServices(['a', 'b', 'c']);
      registry = SourceRegistryImpl(settings: settings);
      for (final id in ['a', 'b', 'c']) {
        registry.register(FakeSource(id));
      }
      var changes = 0;
      registry.changes.listen((_) => changes++);
      await settings.update((s) => s.copyWith(services: s.services.copyWith(providerOrder: ['c', 'a', 'b'])));
      await pumpEventQueue();
      expect(registry.ordered.map((s) => s.id), ['c', 'a', 'b']);
      expect(changes, 1);
      await settings.update((s) => s.copyWith(services: s.services.copyWith(disabledSources: {'a'})));
      await pumpEventQueue();
      expect(registry.ordered.map((s) => s.id), ['c', 'b']);
      expect(changes, 2);
      // Unrelated settings changes do not emit.
      await settings.update((s) => s.copyWith(onboardingCompleted: true));
      await pumpEventQueue();
      expect(changes, 2);
    });
  });

  test('changes merges auth state changes of every source', () async {
    settings = withServices(['a', 'b']);
    registry = SourceRegistryImpl(settings: settings);
    final a = FakeSource('a');
    final b = FakeSource('b');
    registry
      ..register(a)
      ..register(b);
    var changes = 0;
    registry.changes.listen((_) => changes++);
    a.setAuth(const SourceAuthState(status: SourceConnectionStatus.connected));
    b.setAuth(const SourceAuthState(status: SourceConnectionStatus.expired));
    await pumpEventQueue();
    expect(changes, 2);
    registry.unregister('a');
    await pumpEventQueue();
    a.setAuth(const SourceAuthState(status: SourceConnectionStatus.notConnected));
    await pumpEventQueue();
    expect(changes, 3, reason: 'unregister emits once; later events of a are ignored');
  });

  group('searchAll', () {
    test('queries ready sources concurrently and yields results as they complete', () async {
      settings = withServices(['slow', 'fast', 'off', 'notready']);
      registry = SourceRegistryImpl(settings: settings);
      final slow = FakeSource('slow', delay: const Duration(milliseconds: 150));
      final fast = FakeSource('fast', delay: const Duration(milliseconds: 10));
      final notReady = FakeSource('notready', ready: false);
      registry
        ..register(slow)
        ..register(fast)
        ..register(notReady);
      final sw = Stopwatch()..start();
      final results = await registry.searchAll('daft punk').toList();
      sw.stop();
      expect(results.map((r) => r.sourceId), ['fast', 'slow'], reason: 'arrival order, not preference order');
      expect(results.first.tracks.items.single.title, 'daft punk on fast');
      expect(results.first.artists.items.single.name, 'Artist fast');
      expect(results.every((r) => r.error == null), isTrue);
      expect(notReady.calls, isEmpty);
      expect(sw.elapsedMilliseconds, lessThan(400), reason: 'concurrent, not sequential');
    });

    test('a failing source reports error while others succeed', () async {
      settings = withServices(['ok', 'broken']);
      registry = SourceRegistryImpl(settings: settings);
      registry
        ..register(FakeSource('ok'))
        ..register(FakeSource('broken', failWith: const ApiException(500, 'boom')));
      final results = {for (final r in await registry.searchAll('q').toList()) r.sourceId: r};
      expect(results['ok']!.error, isNull);
      expect(results['ok']!.tracks.items, hasLength(1));
      expect(results['broken']!.error, isA<ApiException>());
      expect(results['broken']!.tracks.items, isEmpty);
    });

    test('per-source timeout produces a timeout error and does not block others', () async {
      settings = withServices(['hang', 'ok']);
      registry = SourceRegistryImpl(settings: settings, searchTimeout: const Duration(milliseconds: 100));
      final hang = FakeSource('hang', delay: const Duration(seconds: 30), ignoreCancel: true);
      registry
        ..register(hang)
        ..register(FakeSource('ok'));
      final sw = Stopwatch()..start();
      final results = {for (final r in await registry.searchAll('q').toList()) r.sourceId: r};
      expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
      expect(results['ok']!.error, isNull);
      expect(results['hang']!.error, isA<NetworkException>().having((e) => e.isTimeout, 'isTimeout', isTrue));
    });

    test('default timeout is 10 s', () {
      registry = SourceRegistryImpl(settings: withServices(const []));
      expect(registry.searchTimeout, const Duration(seconds: 10));
    });

    test('filters by onlySources and by search capabilities', () async {
      settings = withServices(['a', 'b', 'c']);
      registry = SourceRegistryImpl(settings: settings);
      final a = FakeSource('a');
      final b = FakeSource('b');
      final c = FakeSource('c', caps: const {SourceCapability.searchArtists});
      registry
        ..register(a)
        ..register(b)
        ..register(c);
      final r1 = await registry.searchAll('q', onlySources: {'b'}).toList();
      expect(r1.map((r) => r.sourceId), ['b']);
      expect(a.calls, isEmpty);

      final r2 = await registry.searchAll('q', types: {SearchType.tracks}).toList();
      expect(r2.map((r) => r.sourceId).toSet(), {'a', 'b'}, reason: 'c cannot search tracks');
      expect(b.calls, ['tracks:q', 'artists:q', 'tracks:q']);
      expect(c.calls, isEmpty);

      expect(await registry.searchAll('   ').toList(), isEmpty);
    });

    test('honours CancelToken: stops yielding and cancels sources', () async {
      settings = withServices(['fast', 'slow']);
      registry = SourceRegistryImpl(settings: settings);
      final slow = FakeSource('slow', delay: const Duration(seconds: 5));
      registry
        ..register(FakeSource('fast'))
        ..register(slow);
      final cancel = CancelToken();
      final received = <String>[];
      final done = Completer<void>();
      registry.searchAll('q', cancel: cancel).listen((r) {
        received.add(r.sourceId);
        cancel.cancel();
      }, onDone: done.complete);
      await done.future.timeout(const Duration(seconds: 2));
      expect(received, ['fast']);

      final pre = CancelToken()..cancel();
      expect(await registry.searchAll('q', cancel: pre).toList(), isEmpty);
    });
  });

  test('initAll survives a failing source', () async {
    registry = SourceRegistryImpl(settings: withServices(['x', 'y']));
    final y = FakeSource('y');
    registry
      ..register(_ThrowingInit())
      ..register(y);
    await registry.initAll();
    expect(registry.all, hasLength(2));
  });
}

class _ThrowingInit extends FakeSource {
  _ThrowingInit() : super('x');

  @override
  Future<void> init() async => throw StateError('broken');
}
