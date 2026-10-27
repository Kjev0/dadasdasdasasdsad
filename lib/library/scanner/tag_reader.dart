import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/models/track.dart';
import '../../core/sources/source_ids.dart';
import 'artwork_store.dart';
import 'audio_formats.dart';
import 'filename_parser.dart';

/// Tags extracted from a file, format-independent.
class ParsedTags {
  String? title;
  List<String> artists = [];
  String? album;
  String? albumArtist;
  int? year;
  String? genre;
  int? trackNumber;
  int? discNumber;
  Duration? duration;
  int? bitrate;
  int? sampleRate;
  String? isrc;
  double? replayGainTrackDb;
  double? replayGainAlbumDb;
  Picture? picture;
}

/// One file to parse in the background isolate.
class ParseRequest {
  const ParseRequest(this.path, this.size, this.mtimeMs, {this.folderArt});

  final String path;
  final int size;
  final int mtimeMs;
  final String? folderArt;
}

/// Result of parsing one file. [track] is null when the file could not be
/// read at all (then [error] says why).
class ScannedFile {
  const ScannedFile({required this.path, required this.size, required this.mtimeMs, this.hash, this.track, this.error, this.tagError});

  final String path;
  final int size;
  final int mtimeMs;

  /// SHA-1 of the first MiB plus the file size (duplicate detection).
  final String? hash;
  final Track? track;
  final String? error;

  /// Tag parsing failed; [track] was built from the file name.
  final String? tagError;
}

/// `local:<sha1(canonical absolute path)>` id part for a local file.
String localTrackIdFor(String path) => sha1.convert(utf8.encode(p.canonicalize(path))).toString();

/// SHA-1 of the first MiB of the file plus its size.
String fastFileHash(String path, int size) {
  final raf = File(path).openSync();
  try {
    final head = raf.readSync(1 << 20);
    final builder = BytesBuilder(copy: false)
      ..add(head)
      ..add(utf8.encode(':$size'));
    return sha1.convert(builder.takeBytes()).toString();
  } finally {
    raf.closeSync();
  }
}

/// Parses a batch of files (synchronous; run in a background isolate).
List<ScannedFile> parseAudioBatch(List<ParseRequest> batch, String artworkDir) => [
      for (final r in batch) parseAudioFile(r, artworkDir),
    ];

/// Reads tags, artwork and hash of one file and builds its [Track].
ScannedFile parseAudioFile(ParseRequest r, String artworkDir) {
  final String hash;
  try {
    hash = fastFileHash(r.path, r.size);
  } on FileSystemException catch (e) {
    return ScannedFile(path: r.path, size: r.size, mtimeMs: r.mtimeMs, error: e.message);
  }
  ParsedTags tags;
  String? tagError;
  try {
    tags = readTags(File(r.path));
  } catch (e) {
    tags = ParsedTags();
    tagError = e.toString();
  }
  final fromName = parseFilename(r.path);
  final title = _clean(tags.title) ?? fromName.title;
  var artists = [for (final a in tags.artists) ?_clean(a)];
  if (artists.isEmpty && fromName.artist != null) artists = [fromName.artist!];

  Uri? artwork;
  final pic = tags.picture;
  if (pic != null) {
    artwork = saveEmbeddedArtwork(
      artworkDir,
      pic.bytes,
      pic.mimetype,
      albumKey: albumArtworkKey(tags.albumArtist ?? (artists.isEmpty ? null : artists.first), tags.album),
    );
  }
  artwork ??= r.folderArt == null ? null : Uri.file(r.folderArt!);

  final ext = extensionOf(r.path);
  final durationMs = tags.duration?.inMilliseconds;
  int? kbps;
  if (durationMs != null && durationMs > 0) {
    kbps = (r.size * 8 / durationMs).round(); // bits per ms == kbit/s
  } else if (tags.bitrate != null) {
    kbps = tags.bitrate! > 10000 ? tags.bitrate! ~/ 1000 : tags.bitrate;
  }

  final track = Track(
    sourceId: SourceIds.local,
    sourceTrackId: localTrackIdFor(r.path),
    title: title,
    artists: [for (final a in artists) ArtistRef(a)],
    album: _clean(tags.album),
    albumArtist: _clean(tags.albumArtist),
    duration: (durationMs == null || durationMs <= 0) ? null : tags.duration,
    isrc: _clean(tags.isrc),
    year: (tags.year != null && tags.year! > 0) ? tags.year : null,
    genre: _clean(tags.genre),
    trackNumber: (tags.trackNumber != null && tags.trackNumber! > 0) ? tags.trackNumber : fromName.trackNumber,
    discNumber: (tags.discNumber != null && tags.discNumber! > 0) ? tags.discNumber : fromName.discNumber,
    artworkUrl: artwork,
    localPath: r.path,
    availability: const TrackAvailability.local(),
    format: AudioFormatInfo(
      codec: codecForExtension(ext),
      bitrateKbps: kbps,
      sampleRateHz: tags.sampleRate,
      fileSizeBytes: r.size,
    ),
    replayGainTrackDb: tags.replayGainTrackDb,
    replayGainAlbumDb: tags.replayGainAlbumDb,
  );
  return ScannedFile(path: r.path, size: r.size, mtimeMs: r.mtimeMs, hash: hash, track: track, tagError: tagError);
}

String? _clean(String? s) {
  if (s == null) return null;
  final t = s.replaceAll('\u0000', ' ').trim();
  return t.isEmpty ? null : t;
}

/// Reads the tags of [file] with `audio_metadata_reader` (format-specific
/// models, so album artist, ISRC and ReplayGain are available).
/// Throws when the file has no parser or is corrupt.
ParsedTags readTags(File file) {
  final meta = readAllMetadata(file, getImage: true);
  final t = ParsedTags();
  switch (meta) {
    case Mp3Metadata m:
      t.title = m.songName;
      t.artists = _splitArtists(m.leadPerformer ?? m.bandOrOrchestra ?? m.originalArtist);
      t.albumArtist = m.bandOrOrchestra;
      t.album = m.album;
      t.year = m.year ?? m.originalReleaseYear;
      t.genre = m.genres.isNotEmpty ? m.genres.first : cleanId3Genre(m.contentType);
      t.trackNumber = m.trackNumber;
      t.discNumber = m.discNumber ?? _leadingInt(m.partOfSet);
      t.duration = m.duration;
      t.bitrate = m.bitrate;
      t.sampleRate = m.samplerate;
      final custom = {for (final e in m.customMetadata.entries) e.key.trim().toUpperCase(): _clean(e.value)};
      t.isrc = m.isrc ?? custom['ISRC'];
      t.replayGainTrackDb = parseGainDb(custom['REPLAYGAIN_TRACK_GAIN']);
      t.replayGainAlbumDb = parseGainDb(custom['REPLAYGAIN_ALBUM_GAIN']);
      t.picture = _pickPicture(m.pictures);
    case VorbisMetadata m:
      t.title = m.title.firstOrNull;
      t.artists = [for (final a in m.artist) ..._splitArtists(a)];
      t.albumArtist = m.albumArtist.firstOrNull;
      t.album = m.album.firstOrNull;
      t.year = m.date.firstOrNull?.year;
      t.genre = m.genres.firstOrNull;
      t.trackNumber = m.trackNumber.firstOrNull;
      t.discNumber = m.discNumber;
      t.duration = m.duration;
      t.bitrate = m.bitrate;
      t.sampleRate = m.sampleRate;
      t.isrc = m.isrc.firstOrNull;
      t.replayGainTrackDb = parseGainDb(m.replayGainTrackGain.firstOrNull);
      t.replayGainAlbumDb = parseGainDb(m.replayGainAlbumGain.firstOrNull);
      final unknown = {for (final e in m.unknowns.entries) e.key.toUpperCase(): e.value};
      // Opus: R128 gains (Q7.8 dB relative to -23 LUFS) -> ReplayGain (-18 LUFS).
      t.replayGainTrackDb ??= _r128ToReplayGain(unknown['R128_TRACK_GAIN']);
      t.replayGainAlbumDb ??= _r128ToReplayGain(unknown['R128_ALBUM_GAIN']);
      t.picture = _pickPicture(m.pictures);
    case Mp4Metadata m:
      t.title = m.title;
      t.artists = _splitArtists(m.artist);
      t.album = m.album;
      t.year = m.year?.year;
      t.genre = m.genre;
      t.trackNumber = m.trackNumber;
      t.discNumber = m.discNumber;
      t.duration = m.duration;
      t.bitrate = m.bitrate;
      t.sampleRate = m.sampleRate;
      t.picture = m.picture;
    case RiffMetadata m:
      // RIFF INFO / AIFF chunks are decoded as Latin-1 by the reader; most
      // taggers (and ffmpeg) write UTF-8.
      t.title = fixMojibake(m.title);
      t.artists = _splitArtists(fixMojibake(m.artist));
      t.album = fixMojibake(m.album);
      t.year = m.year?.year;
      t.genre = fixMojibake(m.genre);
      t.trackNumber = m.trackNumber ?? _leadingInt(m.unknowns['ITRK'] ?? m.unknowns['IPRT']);
      t.duration = m.duration;
      t.bitrate = m.bitrate;
      t.sampleRate = m.samplerate;
      t.isrc = _clean(m.unknowns['ISRC']);
      t.picture = _pickPicture(m.pictures);
    case ApeMetadata m:
      t.title = m.title;
      t.artists = _splitArtists(m.artist);
      t.albumArtist = m.albumArtist;
      t.album = m.album;
      t.year = m.date?.year;
      t.genre = m.genres.firstOrNull;
      t.trackNumber = m.trackNumber;
      t.discNumber = m.discNumber;
      t.duration = m.duration;
      t.bitrate = m.bitrate;
      t.sampleRate = m.sampleRate;
      t.picture = _pickPicture(m.pictures);
  }
  return t;
}

Picture? _pickPicture(List<Picture> pictures) {
  if (pictures.isEmpty) return null;
  for (final pic in pictures) {
    if (pic.pictureType == PictureType.coverFront && pic.bytes.isNotEmpty) return pic;
  }
  for (final pic in pictures) {
    if (pic.bytes.isNotEmpty) return pic;
  }
  return null;
}

/// Splits multi-value artist tags on NUL and `;` (not on `/`: "AC/DC").
List<String> _splitArtists(String? raw) {
  if (raw == null) return const [];
  return raw.split(RegExp(r'[\u0000;]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

int? _leadingInt(String? s) {
  if (s == null) return null;
  final m = RegExp(r'^\s*(\d+)').firstMatch(s);
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// `"(17)Rock"`, `"(17)"`, `"Rock"` → `"Rock"` (bare ID3v1 indexes are dropped).
String? cleanId3Genre(String? raw) {
  final s = _clean(raw);
  if (s == null) return null;
  final stripped = s.replaceAll(RegExp(r'^\(\d+\)'), '').trim();
  if (stripped.isEmpty || RegExp(r'^\d+$').hasMatch(stripped)) return null;
  return stripped;
}

/// `"-6.50 dB"` → -6.5.
double? parseGainDb(String? raw) {
  if (raw == null) return null;
  final m = RegExp(r'[-+]?\d+(?:[.,]\d+)?').firstMatch(raw);
  return m == null ? null : double.tryParse(m.group(0)!.replaceAll(',', '.'));
}

double? _r128ToReplayGain(String? raw) {
  final q = raw == null ? null : int.tryParse(raw.trim());
  return q == null ? null : q / 256.0 + 5.0;
}

/// Re-decodes UTF-8 text that was decoded as Latin-1 ("FlÃ¸jte" → "Fløjte").
String? fixMojibake(String? s) {
  if (s == null) return null;
  if (!s.runes.any((r) => r >= 0x80 && r <= 0xFF)) return s;
  if (s.runes.any((r) => r > 0xFF)) return s;
  try {
    return utf8.decode(latin1.encode(s));
  } on FormatException {
    return s;
  }
}
