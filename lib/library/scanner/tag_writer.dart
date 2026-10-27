import 'dart:io';
import 'dart:math';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;

import '../../core/models/track.dart';
import 'audio_formats.dart';
import 'tag_reader.dart';

/// Outcome of [writeTagsSafely].
enum TagWriteStatus {
  /// The requested fields were written and verified.
  written,

  /// The format cannot be written (or none of the edited fields can).
  unsupported,

  /// Writing would have dropped other tags (ReplayGain, comments, lyrics,
  /// MusicBrainz ids, ...) or did not round-trip; the file was restored.
  wouldLoseData,

  /// I/O error; the original file is unchanged.
  failed,
}

class TagWriteResult {
  const TagWriteResult(this.status, {this.writtenFields = const {}, this.message});

  final TagWriteStatus status;

  /// Track JSON keys that are now stored in the file.
  final Set<String> writtenFields;
  final String? message;
}

/// Track JSON keys each writable format can store in the file.
const _writableFields = <String, Set<String>>{
  '.mp3': {'title', 'artists', 'album', 'albumArtist', 'year', 'genre', 'trackNo', 'discNo', 'isrc'},
  '.flac': {'title', 'artists', 'album', 'albumArtist', 'year', 'genre', 'trackNo', 'isrc'},
  '.wav': {'title', 'artists', 'album', 'year', 'genre', 'trackNo'},
};

/// Track JSON keys that [extension] can store in the file (empty: none).
Set<String> writableFieldsFor(String extension) => _writableFields[extension.toLowerCase()] ?? const {};

const _eq = DeepCollectionEquality();
final _rand = Random();

/// Writes the [edited] values of [fields] (Track JSON keys) into the file at
/// [path] — synchronous, run it in a background isolate.
///
/// Safety: `audio_metadata_reader`'s writers rebuild the whole tag and drop
/// frames they do not model. So the file is copied to [backupDir] first,
/// written, re-read and compared with the original tag model; if any field
/// other than the edited ones changed (or an edited field did not
/// round-trip) the original bytes are restored and
/// [TagWriteStatus.wouldLoseData] is returned. Purely technical fields
/// (encoder/vendor strings, duration, bitrate) are not compared.
TagWriteResult writeTagsSafely(String path, Track edited, Set<String> fields, String backupDir) {
  final ext = extensionOf(path);
  final toWrite = fields.intersection(writableFieldsFor(ext));
  if (toWrite.isEmpty) return const TagWriteResult(TagWriteStatus.unsupported);
  final file = File(path);
  final Object before;
  try {
    before = readAllMetadata(file, getImage: true);
  } catch (e) {
    return TagWriteResult(TagWriteStatus.unsupported, message: 'Unreadable tags: $e');
  }
  final excluded = _modelFieldsFor(before, toWrite);
  final beforePrint = _fingerprint(before)..removeWhere((k, _) => excluded.contains(k));

  Directory(backupDir).createSync(recursive: true);
  final backup = File(p.join(backupDir, 'tagwrite_${DateTime.now().microsecondsSinceEpoch}_${_rand.nextInt(1 << 30)}${p.extension(path)}'));
  final stat = file.statSync();
  try {
    file.copySync(backup.path);
  } on FileSystemException catch (e) {
    return TagWriteResult(TagWriteStatus.failed, message: e.message);
  }

  var keepBackup = false;
  void restore() {
    try {
      backup.copySync('$path.restore');
      File('$path.restore').renameSync(path);
      File(path).setLastModifiedSync(stat.modified);
    } on FileSystemException {
      // Keep the backup so the original tags can be recovered by hand.
      keepBackup = true;
    }
  }

  try {
    final meta = readAllMetadata(file, getImage: true);
    _apply(meta, edited, toWrite);
    if (meta is Mp3Metadata && !_hasId3v2(file)) {
      Id3v4Writer().write(file, meta); // tag-less MP3: prepend a fresh ID3v2.4 tag
    } else {
      replaceMetadata(file, meta);
    }
    final after = readAllMetadata(file, getImage: true);
    final afterPrint = _fingerprint(after)..removeWhere((k, _) => excluded.contains(k));
    final reread = readTags(file);
    final roundTrip = toWrite.every((f) => _sameValue(f, reread, edited));
    if (!roundTrip || !_eq.equals(beforePrint, afterPrint)) {
      restore();
      return TagWriteResult(
        keepBackup ? TagWriteStatus.failed : TagWriteStatus.wouldLoseData,
        message: keepBackup ? 'Could not restore the original; backup kept at ${backup.path}' : null,
      );
    }
    return TagWriteResult(TagWriteStatus.written, writtenFields: toWrite);
  } catch (e) {
    restore();
    return TagWriteResult(
      TagWriteStatus.failed,
      message: keepBackup ? '$e; backup kept at ${backup.path}' : e.toString(),
    );
  } finally {
    try {
      if (!keepBackup && backup.existsSync()) backup.deleteSync();
    } on FileSystemException {
      // leave it
    }
  }
}

bool _hasId3v2(File f) {
  final raf = f.openSync();
  try {
    final head = raf.readSync(3);
    return head.length == 3 && head[0] == 0x49 && head[1] == 0x44 && head[2] == 0x33;
  } finally {
    raf.closeSync();
  }
}

bool _sameValue(String field, ParsedTags t, Track e) => switch (field) {
      'title' => t.title?.trim() == e.title.trim(),
      'artists' => _eq.equals(t.artists, [for (final a in e.artists) a.name.trim()]),
      'album' => (t.album ?? '') == (e.album ?? ''),
      'albumArtist' => (t.albumArtist ?? '') == (e.albumArtist ?? ''),
      'year' => t.year == e.year,
      'genre' => (t.genre ?? '') == (e.genre ?? ''),
      'trackNo' => t.trackNumber == e.trackNumber,
      'discNo' => t.discNumber == e.discNumber,
      'isrc' => (t.isrc ?? '').toUpperCase() == (e.isrc ?? '').toUpperCase(),
      _ => false,
    };

void _apply(Object meta, Track e, Set<String> fields) {
  final names = [for (final a in e.artists) a.name];
  final joined = names.isEmpty ? null : names.join('; ');
  switch (meta) {
    case Mp3Metadata m:
      for (final f in fields) {
        switch (f) {
          case 'title':
            m.songName = e.title;
          case 'artists':
            m.leadPerformer = joined;
          case 'album':
            m.album = e.album;
          case 'albumArtist':
            m.bandOrOrchestra = e.albumArtist;
          case 'year':
            m.year = e.year;
            m.originalReleaseYear = null;
          case 'genre':
            m.genres = e.genre == null ? [] : [e.genre!];
            m.contentType = e.genre;
          case 'trackNo':
            m.trackNumber = e.trackNumber;
          case 'discNo':
            final total = m.totalDics;
            m.partOfSet = e.discNumber == null ? null : (total == null ? '${e.discNumber}' : '${e.discNumber}/$total');
            m.discNumber = e.discNumber;
          case 'isrc':
            m.isrc = e.isrc;
        }
      }
    case VorbisMetadata m:
      for (final f in fields) {
        switch (f) {
          case 'title':
            m.title = [e.title];
          case 'artists':
            m.artist = names;
          case 'album':
            m.album = e.album == null ? [] : [e.album!];
          case 'albumArtist':
            m.albumArtist = e.albumArtist == null ? [] : [e.albumArtist!];
          case 'year':
            m.date = e.year == null ? [] : [DateTime(e.year!)];
          case 'genre':
            m.genres = e.genre == null ? [] : [e.genre!];
          case 'trackNo':
            m.trackNumber = e.trackNumber == null ? [] : [e.trackNumber!];
          case 'isrc':
            m.isrc = e.isrc == null ? [] : [e.isrc!];
        }
      }
    case RiffMetadata m:
      for (final f in fields) {
        switch (f) {
          case 'title':
            m.title = e.title;
          case 'artists':
            m.artist = joined;
          case 'album':
            m.album = e.album;
          case 'year':
            m.year = e.year == null ? null : DateTime(e.year!);
          case 'genre':
            m.genre = e.genre;
          case 'trackNo':
            m.trackNumber = e.trackNumber;
        }
      }
  }
}

/// Model fields affected by editing [trackFields] (excluded from the
/// lossless comparison).
Set<String> _modelFieldsFor(Object meta, Set<String> trackFields) {
  final out = <String>{};
  for (final f in trackFields) {
    switch (meta) {
      case Mp3Metadata():
        out.addAll(switch (f) {
          'title' => ['songName'],
          'artists' => ['leadPerformer'],
          'albumArtist' => ['bandOrOrchestra'],
          'album' => ['album'],
          'year' => ['year', 'originalReleaseYear', 'date', 'recordingDates'],
          'genre' => ['genres', 'contentType'],
          'trackNo' => ['trackNumber'],
          'discNo' => ['partOfSet', 'discNumber'],
          'isrc' => ['isrc'],
          _ => <String>[],
        });
      case VorbisMetadata():
        out.addAll(switch (f) {
          'title' => ['title'],
          'artists' => ['artist'],
          'albumArtist' => ['albumArtist'],
          'album' => ['album'],
          'year' => ['date'],
          'genre' => ['genres'],
          'trackNo' => ['trackNumber'],
          'isrc' => ['isrc'],
          _ => <String>[],
        });
      case RiffMetadata():
        out.addAll(switch (f) {
          'title' => ['title'],
          'artists' => ['artist'],
          'album' => ['album'],
          'year' => ['year'],
          'genre' => ['genre'],
          'trackNo' => ['trackNumber', 'unknown:ITRK', 'unknown:IPRT'],
          _ => <String>[],
        });
      default:
        break;
    }
  }
  return out;
}

List<Object?> _pics(List<Picture> pics) => [for (final x in pics) '${x.mimetype}|${x.pictureType.name}|${x.bytes.length}'];

/// User-meaningful fields of a tag model (technical fields omitted).
Map<String, Object?> _fingerprint(Object meta) {
  switch (meta) {
    case Mp3Metadata m:
      return {
        'album': m.album, 'bpm': m.bpm, 'composer': m.composer, 'contentType': m.contentType,
        'copyrightMessage': m.copyrightMessage, 'date': m.date, 'textWriter': m.textWriter,
        'contentGroupDescription': m.contentGroupDescription, 'songName': m.songName, 'subtitle': m.subtitle,
        'initialKey': m.initialKey, 'languages': m.languages, 'mediatype': m.mediatype,
        'originalAlbum': m.originalAlbum, 'originalArtist': m.originalArtist,
        'originalTextWriter': m.originalTextWriter, 'originalReleaseYear': m.originalReleaseYear,
        'leadPerformer': m.leadPerformer, 'bandOrOrchestra': m.bandOrOrchestra, 'conductor': m.conductor,
        'interpreted': m.interpreted, 'partOfSet': m.partOfSet, 'discNumber': m.discNumber,
        'publisher': m.publisher, 'trackNumber': m.trackNumber, 'trackTotal': m.trackTotal,
        'recordingDates': m.recordingDates, 'isrc': m.isrc, 'year': m.year, 'ufid': m.uniqueFileIdentifer,
        'lyric': m.lyric, 'custom': {for (final e in m.customMetadata.entries) e.key: e.value},
        'pictures': _pics(m.pictures),
        'comments': [for (final c in m.comments) '${c.language}|${c.shortDescription}|${c.text}'],
        'playCounter': m.playCounter, 'popm': m.popularimeter?.toString(), 'priv': m.privateFrame?.identifer,
        'mcdi': m.musicCdId, 'genres': m.genres,
      };
    case VorbisMetadata m:
      return {
        'title': m.title, 'version': m.version, 'album': m.album, 'trackNumber': m.trackNumber,
        'artist': m.artist, 'albumArtist': m.albumArtist, 'performer': m.performer, 'copyright': m.copyright,
        'license': m.license, 'organization': m.organization, 'description': m.description, 'genres': m.genres,
        'date': [for (final d in m.date) d.year], 'location': m.location, 'contact': m.contact, 'isrc': m.isrc,
        'actor': m.actor, 'composer': m.composer, 'comment': m.comment, 'language': m.language,
        'director': m.director, 'producer': m.producer,
        'rg': [...m.replayGainAlbumGain, ...m.replayGainAlbumPeak, ...m.replayGainTrackGain, ...m.replayGainTrackPeak],
        'unknowns': {for (final e in m.unknowns.entries) e.key: e.value},
        'trackTotal': m.trackTotal, 'discNumber': m.discNumber, 'discTotal': m.discTotal, 'lyric': m.lyric,
        'pictures': _pics(m.pictures),
      };
    case RiffMetadata m:
      return {
        'title': m.title, 'artist': m.artist, 'album': m.album, 'year': m.year?.year, 'comment': m.comment,
        'genre': m.genre, 'trackNumber': m.trackNumber, 'publisher': m.publisher, 'copyright': m.copyright,
        'pictures': _pics(m.pictures),
        for (final e in m.unknowns.entries) 'unknown:${e.key}': e.value,
      };
    default:
      return {'model': meta.toString()};
  }
}
