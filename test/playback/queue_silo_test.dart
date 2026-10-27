import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/playback/queue_silo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a SoundCloud stream binds the queue to SoundCloud (+ local files)', () {
    final silo = QueueSilo();
    expect(silo.allows(SourceIds.audius), isTrue); // undetermined
    silo.commit(SourceIds.soundcloud);
    expect(silo.current, SourceIds.soundcloud);
    expect(silo.allows(SourceIds.soundcloud), isTrue);
    expect(silo.allows(SourceIds.local), isTrue);
    expect(silo.allows(SourceIds.audius), isFalse);
    expect(silo.allows(SourceIds.deezer), isFalse);
  });

  test('another service makes an open queue that excludes SoundCloud', () {
    final silo = QueueSilo()..commit(SourceIds.audius);
    expect(silo.current, isNull);
    expect(silo.isDetermined, isTrue);
    expect(silo.allows(SourceIds.jamendo), isTrue);
    expect(silo.allows(SourceIds.soundcloud), isFalse);
  });

  test('local files never determine the silo; reset starts over', () {
    final silo = QueueSilo()..commit(SourceIds.local);
    expect(silo.isDetermined, isFalse);
    silo
      ..commit(SourceIds.soundcloud)
      ..reset();
    expect(silo.isDetermined, isFalse);
    expect(silo.allows(SourceIds.audius), isTrue);
  });
}
