import 'package:dbus/dbus.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/platform/linux/mpris_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../desktop/fakes.dart';

void main() {
  test('track ids are valid, unique object paths for any uid', () {
    final ids = {
      for (final uid in ['a', 'b', 'uid-1', '550e8400-e29b-41d4-a716-446655440000', 'ü/ /..', ''])
        uid: MprisModel.trackIdFor(uid),
    };
    for (final path in ids.values) {
      expect(() => DBusObjectPath(path), returnsNormally);
    }
    expect(ids[''], MprisModel.noTrackPath);
    expect(MprisModel.trackIdFor(null), MprisModel.noTrackPath);
    expect(ids.values.toSet(), hasLength(ids.length));
  });

  test('playback status', () {
    final item = QueueItem(uid: 'u', track: track('1'));
    expect(MprisModel.playbackStatus(const PlaybackSnapshot()), 'Stopped');
    expect(MprisModel.playbackStatus(PlaybackSnapshot(current: item, playing: true)), 'Playing');
    expect(MprisModel.playbackStatus(PlaybackSnapshot(current: item, status: PlayerStatus.ready)), 'Paused');
    expect(MprisModel.playbackStatus(PlaybackSnapshot(current: item, status: PlayerStatus.idle)), 'Stopped');
    expect(MprisModel.playbackStatus(PlaybackSnapshot(current: item, status: PlayerStatus.completed)), 'Stopped');
  });

  test('loop status round-trips', () {
    for (final mode in RepeatMode.values) {
      expect(MprisModel.repeatModeFor(MprisModel.loopStatus(mode)), mode);
    }
    expect(MprisModel.loopStatus(RepeatMode.off), 'None');
    expect(MprisModel.loopStatus(RepeatMode.one), 'Track');
    expect(MprisModel.loopStatus(RepeatMode.all), 'Playlist');
    expect(MprisModel.repeatModeFor('none'), isNull);
  });

  test('metadata omits unknown fields and only exposes safe art URLs', () {
    final s = PlaybackSnapshot(
      current: QueueItem(uid: 'u', track: track('1', art: Uri.parse('content://x/y'), duration: Duration.zero)),
    );
    final m = MprisModel.metadata(s);
    expect(m.containsKey('mpris:length'), isFalse);
    expect(m.containsKey('mpris:artUrl'), isFalse);
    expect(m.containsKey('xesam:album'), isFalse);
    expect(m['xesam:artist']!.asStringArray(), ['Artist']);
  });
}
