import 'dart:async';
import 'dart:io';

import 'package:fermata/core/contracts/playback.dart';
import 'package:fermata/core/models/playback.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/util/cancel_token.dart';

/// Shared helpers for the real-audio (libmpv) tests, also used by
/// `integration_test/playback_test.dart`.

/// Why real-audio tests cannot run here, or null when they can.
String? realAudioSkipReason() {
  if (!Platform.isLinux) return 'real-audio tests run on Linux only';
  final hasFfmpeg = Process.runSync('which', ['ffmpeg']).exitCode == 0;
  if (!hasFfmpeg) return 'ffmpeg not installed';
  final libs = ['/usr/lib/x86_64-linux-gnu/libmpv.so.2', '/usr/lib/x86_64-linux-gnu/libmpv.so', '/usr/lib/libmpv.so.2'];
  if (!libs.any((p) => File(p).existsSync())) return 'libmpv not installed';
  return null;
}

/// Generates a sine tone with ffmpeg (WAV or FLAC by extension).
Future<File> sineTone(Directory dir, String name, {required double seconds, int frequency = 440}) async {
  final file = File('${dir.path}/$name');
  final r = await Process.run('ffmpeg', [
    '-hide_banner',
    '-loglevel',
    'error',
    '-y',
    '-f',
    'lavfi',
    '-i',
    'sine=frequency=$frequency:duration=$seconds:sample_rate=44100',
    '-ac',
    '2',
    file.path,
  ]);
  if (r.exitCode != 0) throw StateError('ffmpeg failed: ${r.stderr}');
  return file;
}

Track fileTrack(File f, {Duration? duration}) => Track(
      sourceId: 'local',
      sourceTrackId: f.uri.pathSegments.last,
      title: f.uri.pathSegments.last,
      localPath: f.path,
      duration: duration,
      availability: const TrackAvailability.local(),
    );

/// Resolves local tracks to their files (the real resolver needs the whole
/// app graph; the file branch is covered by its own unit tests).
class LocalFileResolver implements StreamResolver {
  @override
  Future<ResolvedStream> resolve(Track track, {CancelToken? cancel}) async =>
      ResolvedStream(source: PlayableSource(uri: Uri.file(track.localPath!), isLocalFile: true), playedTrack: track);
}

/// Polls [condition] until true or [timeout].
Future<void> waitFor(bool Function() condition,
    {Duration timeout = const Duration(seconds: 10), String reason = 'condition'}) async {
  final sw = Stopwatch()..start();
  while (!condition()) {
    if (sw.elapsed > timeout) throw TimeoutException('Timed out waiting for $reason', timeout);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
