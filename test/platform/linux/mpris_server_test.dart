// MPRIS integration test: runs the real MprisServer on a private dbus-daemon
// and drives it with the dbus package client and with `playerctl`.
//
//   source /opt/sdk/env.sh && flutter test test/platform/linux/mpris_server_test.dart
@TestOn('linux')
library;

import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/platform/linux/mpris_model.dart';
import 'package:fermata/platform/linux/mpris_server.dart';
import 'package:flutter_test/flutter_test.dart';

import '../desktop/fakes.dart';
import 'test_bus.dart';

const _player = MprisServer.playerInterface;
const _root = MprisServer.rootInterface;

void main() {
  if (!TestBus.available) {
    test('MPRIS integration', () {}, skip: 'dbus-daemon not installed');
    return;
  }
  final hasPlayerctl = Process.runSync('which', ['playerctl']).exitCode == 0;

  late TestBus bus;
  late DBusClient serverClient;
  late DBusClient client;
  late FakePlaybackController playback;
  late MprisServer server;
  late DBusRemoteObject remote;
  var raised = 0;
  var quits = 0;
  final opened = <String>[];

  setUpAll(() async {
    bus = await TestBus.start();
  });

  tearDownAll(() async {
    await bus.stop();
  });

  setUp(() async {
    raised = 0;
    quits = 0;
    opened.clear();
    playback = FakePlaybackController();
    playback.load([
      track('1',
          title: 'Blue in Green',
          artist: 'Miles Davis',
          album: 'Kind of Blue',
          duration: const Duration(minutes: 5, seconds: 37),
          art: Uri.parse('https://example.com/kob.jpg'),
          path: '/music/Kind of Blue/03 Blue in Green.flac'),
      track('2', title: 'All Blues', artist: 'Miles Davis'),
      track('3', title: 'Flamenco Sketches', artist: 'Miles Davis'),
    ]);
    serverClient = bus.client();
    client = bus.client();
    server = MprisServer(
      playback: playback,
      client: serverClient,
      onRaise: () async => raised++,
      onQuit: () async => quits++,
      onOpenFile: (path) async => opened.add(path),
    );
    await server.start();
    remote = DBusRemoteObject(client, name: MprisServer.baseBusName, path: DBusObjectPath(MprisServer.objectPath));
  });

  tearDown(() async {
    await server.stop();
    await serverClient.close();
    await client.close();
  });

  Future<DBusValue> prop(String iface, String name) => remote.getProperty(iface, name);

  Future<Map<String, DBusValue>> metadata() async =>
      (await prop(_player, 'Metadata')).asStringVariantDict();

  Future<ProcessResult> playerctl(List<String> args) =>
      Process.run('playerctl', ['-p', 'fermata', ...args], environment: bus.environment);

  /// Subscribes to [interface].[name] signals from the player and waits for
  /// the match rule to be active.
  Future<List<DBusSignal>> collect(String interface, String name) async {
    final out = <DBusSignal>[];
    final stream = DBusRemoteObjectSignalStream(object: remote, interface: interface, name: name);
    final sub = stream.listen(out.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return out;
  }

  Future<void> waitFor(bool Function() condition, {Duration timeout = const Duration(seconds: 3)}) async {
    final end = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(end)) fail('condition not met within $timeout');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  test('owns org.mpris.MediaPlayer2.fermata with the root properties', () async {
    expect(server.busName, 'org.mpris.MediaPlayer2.fermata');
    expect(await client.nameHasOwner('org.mpris.MediaPlayer2.fermata'), isTrue);
    final all = await remote.getAllProperties(_root);
    expect(all['Identity'], const DBusString('Fermata'));
    expect(all['DesktopEntry'], const DBusString('app.fermata.player'));
    expect(all['CanRaise'], const DBusBoolean(true));
    expect(all['CanQuit'], const DBusBoolean(true));
    expect(all['CanSetFullscreen'], const DBusBoolean(false));
    expect(all['HasTrackList'], const DBusBoolean(false));
    expect(all['SupportedUriSchemes']!.asStringArray(), ['file']);
    expect(all['SupportedMimeTypes']!.asStringArray(), containsAll(['audio/mpeg', 'audio/flac', 'audio/ogg']));
  });

  test('introspection lists both MPRIS interfaces', () async {
    final node = await remote.introspect();
    final names = node.interfaces.map((i) => i.name).toList();
    expect(names, containsAll([_root, _player, 'org.freedesktop.DBus.Properties']));
    final playerIface = node.interfaces.firstWhere((i) => i.name == _player);
    expect(playerIface.methods.map((m) => m.name), containsAll(['PlayPause', 'Seek', 'SetPosition', 'OpenUri']));
    expect(playerIface.signals.map((s) => s.name), ['Seeked']);
  });

  test('Metadata maps the current queue entry', () async {
    final m = await metadata();
    final trackId = m['mpris:trackid']!.asObjectPath().value;
    expect(trackId, MprisModel.trackIdFor(playback.queue.current!.uid));
    expect(trackId, startsWith('/app/fermata/player/track/t'));
    expect(m['mpris:length'], DBusInt64(const Duration(minutes: 5, seconds: 37).inMicroseconds));
    expect(m['xesam:title'], const DBusString('Blue in Green'));
    expect(m['xesam:artist']!.asStringArray(), ['Miles Davis']);
    expect(m['xesam:album'], const DBusString('Kind of Blue'));
    expect(m['xesam:url'], DBusString(Uri.file('/music/Kind of Blue/03 Blue in Green.flac').toString()));
    expect(m['mpris:artUrl'], const DBusString('https://example.com/kob.jpg'));
  });

  test('player properties reflect the playback state', () async {
    final all = await remote.getAllProperties(_player);
    expect(all['PlaybackStatus'], const DBusString('Paused'));
    expect(all['LoopStatus'], const DBusString('None'));
    expect(all['Shuffle'], const DBusBoolean(false));
    expect(all['Rate'], const DBusDouble(1.0));
    expect(all['MinimumRate'], const DBusDouble(0.5));
    expect(all['MaximumRate'], const DBusDouble(2.0));
    expect(all['Volume'], const DBusDouble(1.0));
    expect(all['Position'], const DBusInt64(0));
    for (final cap in ['CanGoNext', 'CanGoPrevious', 'CanPlay', 'CanPause', 'CanSeek', 'CanControl']) {
      expect(all[cap], const DBusBoolean(true), reason: cap);
    }
  });

  test('nothing loaded → Stopped, NoTrack and no transport', () async {
    playback.load(const []);
    expect(await prop(_player, 'PlaybackStatus'), const DBusString('Stopped'));
    final m = await metadata();
    expect(m['mpris:trackid']!.asObjectPath().value, MprisModel.noTrackPath);
    expect(await prop(_player, 'CanPlay'), const DBusBoolean(false));
    expect(await prop(_player, 'CanGoNext'), const DBusBoolean(false));
    expect(await prop(_player, 'CanSeek'), const DBusBoolean(false));
  });

  test('transport methods control playback', () async {
    await remote.callMethod(_player, 'Play', const []);
    expect(playback.snapshot.playing, isTrue);
    expect(await prop(_player, 'PlaybackStatus'), const DBusString('Playing'));
    await remote.callMethod(_player, 'Pause', const []);
    expect(playback.snapshot.playing, isFalse);
    await remote.callMethod(_player, 'PlayPause', const []);
    expect(playback.snapshot.playing, isTrue);
    await remote.callMethod(_player, 'Next', const []);
    expect(playback.queue.currentIndex, 1);
    expect((await metadata())['xesam:title'], const DBusString('All Blues'));
    await remote.callMethod(_player, 'Previous', const []);
    expect(playback.queue.currentIndex, 0);
    await remote.callMethod(_player, 'Stop', const []);
    expect(playback.calls, contains('stop'));
    expect(await prop(_player, 'PlaybackStatus'), const DBusString('Stopped'));
  });

  test('Next at the end of the queue is a no-op unless repeating all', () async {
    playback.load([track('a'), track('b')], index: 1);
    expect(await prop(_player, 'CanGoNext'), const DBusBoolean(false));
    await remote.callMethod(_player, 'Next', const []);
    expect(playback.calls.where((c) => c == 'next'), isEmpty);
    await playback.setRepeat(RepeatMode.all);
    expect(await prop(_player, 'CanGoNext'), const DBusBoolean(true));
  });

  test('settable LoopStatus, Shuffle, Rate and Volume', () async {
    await remote.setProperty(_player, 'LoopStatus', const DBusString('Track'));
    expect(playback.snapshot.repeat, RepeatMode.one);
    await remote.setProperty(_player, 'LoopStatus', const DBusString('Playlist'));
    expect(playback.snapshot.repeat, RepeatMode.all);
    expect(await prop(_player, 'LoopStatus'), const DBusString('Playlist'));
    await remote.setProperty(_player, 'Shuffle', const DBusBoolean(true));
    expect(playback.snapshot.shuffle, isTrue);
    await remote.setProperty(_player, 'Rate', const DBusDouble(3.0));
    expect(playback.snapshot.speed, 2.0, reason: 'clamped to MaximumRate');
    await remote.setProperty(_player, 'Rate', const DBusDouble(0.25));
    expect(playback.snapshot.speed, 0.5, reason: 'clamped to MinimumRate');
    await remote.setProperty(_player, 'Volume', const DBusDouble(0.4));
    expect(playback.snapshot.volume, closeTo(0.4, 1e-9));
    await remote.setProperty(_player, 'Volume', const DBusDouble(1.7));
    expect(playback.snapshot.volume, 1.0);

    await expectLater(
      remote.setProperty(_player, 'LoopStatus', const DBusString('Forever')),
      throwsA(isA<DBusInvalidArgsException>()),
    );
    await expectLater(
      remote.setProperty(_player, 'PlaybackStatus', const DBusString('Playing')),
      throwsA(isA<DBusPropertyReadOnlyException>()),
    );
  });

  test('without speed support the rate is fixed at 1.0', () async {
    playback.speedSupported = false;
    expect(await prop(_player, 'MinimumRate'), const DBusDouble(1.0));
    expect(await prop(_player, 'MaximumRate'), const DBusDouble(1.0));
    await remote.setProperty(_player, 'Rate', const DBusDouble(1.5));
    expect(playback.calls.where((c) => c.startsWith('speed')), isEmpty);
  });

  test('PropertiesChanged is emitted for changed properties only (never Position)', () async {
    final signals = await collect('org.freedesktop.DBus.Properties', 'PropertiesChanged');
    await playback.play();
    await waitFor(() => signals.isNotEmpty);
    final first = DBusPropertiesChangedSignal(signals.first);
    expect(first.propertiesInterface, _player);
    expect(first.changedProperties.keys, ['PlaybackStatus']);
    expect(first.changedProperties['PlaybackStatus'], const DBusString('Playing'));

    signals.clear();
    // Position ticks alone change nothing that is signalled.
    playback.emit(playback.snapshot.copyWith(position: const Duration(milliseconds: 250)));
    playback.emit(playback.snapshot.copyWith(position: const Duration(milliseconds: 500)));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(signals, isEmpty);

    await playback.next();
    await waitFor(() => signals.isNotEmpty);
    final changed = DBusPropertiesChangedSignal(signals.last).changedProperties;
    expect(changed.containsKey('Metadata'), isTrue);
    expect(changed.containsKey('Position'), isFalse);
    expect(changed['Metadata']!.asStringVariantDict()['xesam:title'], const DBusString('All Blues'));
  });

  test('Seek emits Seeked and seeking past the end goes to the next track', () async {
    final seeked = await collect(_player, 'Seeked');
    playback.emit(playback.snapshot.copyWith(position: const Duration(seconds: 10)));
    await waitFor(() => seeked.isNotEmpty); // the jump 0 → 10 s itself
    seeked.clear();
    await remote.callMethod(_player, 'Seek', [DBusInt64(const Duration(seconds: 20).inMicroseconds)]);
    expect(playback.snapshot.position, const Duration(seconds: 30));
    await waitFor(() => seeked.isNotEmpty);
    expect(seeked.single.values.single, DBusInt64(const Duration(seconds: 30).inMicroseconds));

    await remote.callMethod(_player, 'Seek', [DBusInt64(const Duration(minutes: 20).inMicroseconds)]);
    expect(playback.queue.currentIndex, 1);

    await remote.callMethod(_player, 'Seek', [DBusInt64(-const Duration(minutes: 20).inMicroseconds)]);
    expect(playback.snapshot.position, Duration.zero);
  });

  test('SetPosition seeks only for the current track id', () async {
    final seeked = await collect(_player, 'Seeked');
    final current = DBusObjectPath(MprisModel.trackIdFor(playback.queue.current!.uid));
    final stale = DBusObjectPath(MprisModel.trackIdFor('some-other-uid'));
    final pos = DBusInt64(const Duration(seconds: 42).inMicroseconds);

    await remote.callMethod(_player, 'SetPosition', [stale, pos]);
    expect(playback.calls.where((c) => c.startsWith('seek')), isEmpty);

    await remote.callMethod(_player, 'SetPosition', [current, pos]);
    expect(playback.snapshot.position, const Duration(seconds: 42));
    await waitFor(() => seeked.isNotEmpty);
    expect(seeked.single.values.single, pos);

    // Beyond the track length → ignored.
    await remote.callMethod(_player, 'SetPosition', [current, DBusInt64(const Duration(hours: 1).inMicroseconds)]);
    expect(playback.snapshot.position, const Duration(seconds: 42));
  });

  test('position jumps from other sources emit Seeked; normal progress does not', () async {
    final seeked = await collect(_player, 'Seeked');
    await playback.play();
    playback.emit(playback.snapshot.copyWith(position: const Duration(milliseconds: 100)));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    playback.emit(playback.snapshot.copyWith(position: const Duration(milliseconds: 350)));
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(seeked, isEmpty);

    playback.emit(playback.snapshot.copyWith(position: const Duration(minutes: 2)));
    await waitFor(() => seeked.isNotEmpty);
    expect(seeked.single.values.single, DBusInt64(const Duration(minutes: 2).inMicroseconds));
  });

  test('Position is read on demand and extrapolated while playing', () async {
    await playback.play();
    playback.emit(playback.snapshot.copyWith(position: const Duration(seconds: 5)));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final us = (await prop(_player, 'Position')).asInt64();
    expect(us, greaterThan(const Duration(seconds: 5, milliseconds: 200).inMicroseconds));
    expect(us, lessThan(const Duration(seconds: 7).inMicroseconds));
  });

  test('Raise, Quit and OpenUri use the callbacks', () async {
    await remote.callMethod(_root, 'Raise', const []);
    expect(raised, 1);
    await remote.callMethod(_root, 'Quit', const []);
    await waitFor(() => quits == 1);

    await remote.callMethod(_player, 'OpenUri', [DBusString(Uri.file('/music/a b.flac').toString())]);
    expect(opened, ['/music/a b.flac']);
    await expectLater(
      remote.callMethod(_player, 'OpenUri', const [DBusString('https://example.com/x.mp3')]),
      throwsA(isA<DBusNotSupportedException>()),
    );
  });

  test('a second instance falls back to org.mpris.MediaPlayer2.fermata.instance<pid>', () async {
    final otherClient = bus.client();
    final other = MprisServer(playback: FakePlaybackController(), client: otherClient, processId: 4242);
    await other.start();
    expect(other.busName, 'org.mpris.MediaPlayer2.fermata.instance4242');
    expect(await client.nameHasOwner('org.mpris.MediaPlayer2.fermata.instance4242'), isTrue);
    await other.stop();
    expect(await client.nameHasOwner('org.mpris.MediaPlayer2.fermata.instance4242'), isFalse);
    await otherClient.close();
  });

  test('stop releases the bus name', () async {
    await server.stop();
    expect(await client.nameHasOwner(MprisServer.baseBusName), isFalse);
  });

  group('playerctl', () {
    test('status, metadata, play-pause, next, previous', () async {
      var r = await playerctl(['status']);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect((r.stdout as String).trim(), 'Paused');

      r = await playerctl(['metadata', '--format', '{{title}}|{{artist}}|{{album}}|{{mpris:length}}']);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect((r.stdout as String).trim(),
          'Blue in Green|Miles Davis|Kind of Blue|${const Duration(minutes: 5, seconds: 37).inMicroseconds}');

      r = await playerctl(['play-pause']);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(playback.snapshot.playing, isTrue);
      expect(((await playerctl(['status'])).stdout as String).trim(), 'Playing');

      r = await playerctl(['next']);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(playback.queue.currentIndex, 1);
      expect(((await playerctl(['metadata', 'title'])).stdout as String).trim(), 'All Blues');

      r = await playerctl(['previous']);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect(playback.queue.currentIndex, 0);
    });

    test('loop, shuffle, volume and position', () async {
      expect((await playerctl(['loop', 'Playlist'])).exitCode, 0);
      expect(playback.snapshot.repeat, RepeatMode.all);
      expect(((await playerctl(['loop'])).stdout as String).trim(), 'Playlist');

      expect((await playerctl(['shuffle', 'On'])).exitCode, 0);
      expect(playback.snapshot.shuffle, isTrue);

      expect((await playerctl(['volume', '0.3'])).exitCode, 0);
      expect(playback.snapshot.volume, closeTo(0.3, 1e-9));

      expect((await playerctl(['position', '61'])).exitCode, 0);
      expect(playback.snapshot.position, const Duration(seconds: 61));
      expect(double.parse(((await playerctl(['position'])).stdout as String).trim()), closeTo(61, 1.5));
    });
  }, skip: hasPlayerctl ? false : 'playerctl not installed');
}
