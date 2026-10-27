import 'dart:io';

import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/platform/app_paths.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/library/library_module.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _ffi = false;

/// FFI factory without the background isolate (fast, deterministic tests).
DatabaseFactory testDbFactory() {
  if (!_ffi) {
    sqfliteFfiInit();
    _ffi = true;
  }
  return databaseFactoryFfiNoIsolate;
}

/// A temp directory deleted by [TestLibrary.dispose].
Future<Directory> tempDir(String prefix) => Directory.systemTemp.createTemp('fermata_lib_$prefix');

class TestLibrary {
  TestLibrary(this.module, this.root, this.paths);

  final LibraryModule module;
  final Directory root;
  final AppPaths paths;

  Future<void> dispose() async {
    await module.close();
    if (await root.exists()) await root.delete(recursive: true);
  }
}

/// In-memory library with temp app paths.
Future<TestLibrary> openTestLibrary({
  PlatformInfo platform = const PlatformInfo(os: HostOs.linux),
  SettingsStore? settings,
  Duration watchDebounce = const Duration(milliseconds: 300),
  bool onDisk = false,
}) async {
  final root = await tempDir('lib');
  final paths = AppPaths.forTesting(root);
  final module = await LibraryModule.open(
    paths: paths,
    platform: platform,
    settings: settings,
    inMemory: !onDisk,
    databaseFactory: testDbFactory(),
    watchDebounce: watchDebounce,
  );
  return TestLibrary(module, root, paths);
}

Track remoteTrack(
  String id, {
  String source = 'soundcloud',
  String? title,
  List<String> artists = const ['Artist'],
  String? album,
  String? albumArtist,
  String? genre,
  int? year,
  int? seconds,
  String? isrc,
  Uri? artwork,
}) =>
    Track(
      sourceId: source,
      sourceTrackId: id,
      title: title ?? 'Title $id',
      artists: [for (final a in artists) ArtistRef(a)],
      album: album,
      albumArtist: albumArtist,
      genre: genre,
      year: year,
      duration: seconds == null ? null : Duration(seconds: seconds),
      isrc: isrc,
      artworkUrl: artwork,
      availability: const TrackAvailability(playback: PlaybackRights.full, offline: OfflineRights.streamOnly),
    );

Track localTrack(String id, String path, {String? title, List<String> artists = const ['Local Artist'], int? seconds}) => Track(
      sourceId: 'local',
      sourceTrackId: id,
      title: title ?? 'Local $id',
      artists: [for (final a in artists) ArtistRef(a)],
      duration: seconds == null ? null : Duration(seconds: seconds),
      localPath: path,
      availability: const TrackAvailability.local(),
    );

/// Whether ffmpeg is installed (scanner tests generate real audio with it).
bool get hasFfmpeg {
  try {
    return Process.runSync('ffmpeg', ['-version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

/// Generates a short sine-wave file with ffmpeg. [tags] become
/// `-metadata k=v`; [cover] embeds an attached picture (mp3/flac/m4a).
Future<File> makeAudio(
  String path, {
  Map<String, String> tags = const {},
  String? cover,
  double seconds = 2,
  int frequency = 440,
  List<String> extraArgs = const [],
}) async {
  await Directory(File(path).parent.path).create(recursive: true);
  final ext = path.split('.').last.toLowerCase();
  final codec = switch (ext) {
    'mp3' => ['-c:a', 'libmp3lame', '-b:a', '96k', '-id3v2_version', '3'],
    'flac' => ['-c:a', 'flac'],
    'm4a' => ['-c:a', 'aac', '-b:a', '96k'],
    'ogg' => ['-c:a', 'libvorbis'],
    'opus' => ['-c:a', 'libopus'],
    'wav' => ['-c:a', 'pcm_s16le'],
    'aiff' => ['-c:a', 'pcm_s16be'],
    _ => <String>[],
  };
  final args = [
    '-y', '-hide_banner', '-loglevel', 'error',
    '-f', 'lavfi', '-i', 'sine=frequency=$frequency:duration=$seconds',
    if (cover != null) ...['-i', cover, '-map', '0', '-map', '1', if (ext == 'm4a') ...['-c:v', 'png'], '-disposition:v', 'attached_pic'],
    if (cover == null) ...['-map_metadata', '-1'],
    ...codec,
    for (final e in tags.entries) ...['-metadata', '${e.key}=${e.value}'],
    ...extraArgs,
    path,
  ];
  final r = await Process.run('ffmpeg', args);
  if (r.exitCode != 0) throw StateError('ffmpeg failed for $path: ${r.stderr}');
  return File(path);
}

/// A tiny PNG made with ffmpeg.
Future<File> makePng(String path, {String color = 'red'}) async {
  final r = await Process.run('ffmpeg', [
    '-y', '-hide_banner', '-loglevel', 'error',
    '-f', 'lavfi', '-i', 'color=c=$color:s=32x32:d=1', '-frames:v', '1', path,
  ]);
  if (r.exitCode != 0) throw StateError('ffmpeg png failed: ${r.stderr}');
  return File(path);
}
