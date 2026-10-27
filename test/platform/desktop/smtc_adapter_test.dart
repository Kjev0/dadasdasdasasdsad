import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/platform/windows/smtc_adapter.dart';
import 'package:fermata/platform/windows/smtc_port.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakePlaybackController playback;
  late FakeSmtcPort port;
  late DateTime now;

  setUp(() {
    playback = FakePlaybackController();
    port = FakeSmtcPort();
    now = DateTime(2026, 1, 1, 12);
  });

  SmtcAdapter adapter({HostOs os = HostOs.windows}) => SmtcAdapter(
        playback: playback,
        platform: PlatformInfo(os: os),
        portFactory: () async => port,
        clock: () => now,
      );

  test('never touches SMTC off Windows', () async {
    var created = false;
    final a = SmtcAdapter(
      playback: playback,
      platform: const PlatformInfo(os: HostOs.linux),
      portFactory: () async {
        created = true;
        return port;
      },
    );
    await a.start();
    expect(created, isFalse);
    expect(a.isActive, isFalse);
    await a.stop();
  });

  test('initialization failure is swallowed', () async {
    final a = SmtcAdapter(
      playback: playback,
      platform: const PlatformInfo(os: HostOs.windows),
      portFactory: () async => throw UnsupportedError('no RustLib'),
    );
    await a.start();
    expect(a.isActive, isFalse);
  });

  test('mirrors metadata, status, shuffle/repeat and timeline', () async {
    final a = adapter();
    await a.start();
    expect(port.status, SmtcStatus.stopped);
    expect(port.calls, contains('config:play=false,next=false,prev=false'));

    playback.load([
      track('1',
          title: 'So What',
          artist: 'Miles Davis',
          album: 'Kind of Blue',
          duration: const Duration(minutes: 9),
          art: Uri.parse('https://img.example/kob.jpg')),
      track('2'),
    ]);
    await settle();
    expect(port.metadata['title'], 'So What');
    expect(port.metadata['artist'], 'Miles Davis');
    expect(port.metadata['album'], 'Kind of Blue');
    expect(port.metadata['thumbnail'], 'https://img.example/kob.jpg');
    expect(port.status, SmtcStatus.paused);
    expect(port.timelines.last, (0, const Duration(minutes: 9).inMilliseconds, 0));
    expect(port.calls, contains('config:play=true,next=true,prev=true'));

    await playback.play();
    await settle();
    expect(port.status, SmtcStatus.playing);

    await playback.setShuffle(true);
    await playback.setRepeat(RepeatMode.one);
    await settle();
    expect(port.calls, containsAll(['shuffle:true', 'repeat:one']));

    playback.load(const []);
    await settle();
    expect(port.calls, contains('clearMetadata'));
    expect(port.status, SmtcStatus.stopped);
    await a.stop();
    expect(port.calls.last, 'enabled:false');
    expect(port.disposed, isTrue);
  });

  test('timeline throttled to ~1 Hz, immediate on seek', () async {
    await adapter().start();
    playback.load([track('1', duration: const Duration(minutes: 3))], playing: true);
    await settle();
    final base = port.timelines.length;

    for (var i = 1; i <= 4; i++) {
      now = now.add(const Duration(milliseconds: 250));
      playback.emit(playback.snapshot.copyWith(position: Duration(milliseconds: 250 * i)));
      await settle();
    }
    expect(port.timelines.length, base + 1, reason: 'four 250 ms ticks → one update');

    now = now.add(const Duration(milliseconds: 250));
    playback.emit(playback.snapshot.copyWith(position: const Duration(minutes: 2)));
    await settle();
    expect(port.timelines.last.$3, const Duration(minutes: 2).inMilliseconds);
  });

  test('buttons and shuffle/repeat requests reach the player', () async {
    await adapter().start();
    playback.load([track('1'), track('2')]);
    await settle();
    port.buttonCtl.add(SmtcButton.play);
    port.buttonCtl.add(SmtcButton.pause);
    port.buttonCtl.add(SmtcButton.next);
    port.buttonCtl.add(SmtcButton.previous);
    port.buttonCtl.add(SmtcButton.stop);
    port.buttonCtl.add(SmtcButton.other);
    port.shuffleCtl.add(true);
    port.repeatCtl.add(RepeatMode.all);
    await settle();
    expect(playback.calls, ['play', 'pause', 'next', 'previous', 'stop', 'shuffle:true', 'repeat:all']);
  });

  test('only valid absolute http(s)/file URIs become thumbnails', () {
    expect(SmtcAdapter.thumbnailFor(track('1', art: Uri.parse('https://a.example/x.jpg'))), 'https://a.example/x.jpg');
    expect(SmtcAdapter.thumbnailFor(track('1', art: Uri.parse('file:///C:/Music/cover.jpg'))), 'file:///C:/Music/cover.jpg');
    expect(SmtcAdapter.thumbnailFor(track('1', art: Uri.parse('cover.jpg'))), isNull);
    expect(SmtcAdapter.thumbnailFor(track('1', art: Uri.parse('content://media/1'))), isNull);
    expect(SmtcAdapter.thumbnailFor(track('1', art: Uri.parse('https:///nohost'))), isNull);
    expect(SmtcAdapter.thumbnailFor(track('1')), isNull);
  });

  test('status mapping', () {
    final item = QueueItem(uid: 'u', track: track('1'));
    expect(SmtcAdapter.statusFor(const PlaybackSnapshot()), SmtcStatus.stopped);
    expect(SmtcAdapter.statusFor(PlaybackSnapshot(current: item, playing: true)), SmtcStatus.playing);
    expect(SmtcAdapter.statusFor(PlaybackSnapshot(current: item, status: PlayerStatus.loading)), SmtcStatus.changing);
    expect(SmtcAdapter.statusFor(PlaybackSnapshot(current: item, status: PlayerStatus.ready)), SmtcStatus.paused);
    expect(SmtcAdapter.statusFor(PlaybackSnapshot(current: item, status: PlayerStatus.idle)), SmtcStatus.stopped);
  });
}
