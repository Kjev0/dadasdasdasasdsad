import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../text/fold.dart';

/// Cache key for an album's artwork: one image per (album artist, album).
/// Returns null when the album is unknown (the image bytes are hashed then).
String? albumArtworkKey(String? albumArtist, String? album) {
  final a = foldForSearch(album);
  if (a.isEmpty) return null;
  return sha1.convert(utf8.encode('${foldForSearch(albumArtist)}\u0000$a')).toString();
}

/// File extension for an embedded image (by MIME type, else magic bytes).
String imageExtension(Uint8List bytes, String mime) {
  final m = mime.toLowerCase();
  if (m.contains('png')) return '.png';
  if (m.contains('jpeg') || m.contains('jpg')) return '.jpg';
  if (m.contains('webp')) return '.webp';
  if (m.contains('gif')) return '.gif';
  if (bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return '.png';
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return '.jpg';
  if (bytes.length >= 12 && ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') return '.webp';
  if (bytes.length >= 3 && bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return '.gif';
  return '.jpg';
}

final _rand = Random();

/// Stores embedded artwork once per album in [artworkDir] and returns its
/// `file://` URI. Existing files are reused (first image of an album wins).
/// Writes go to a temp file and are renamed, so concurrent scans are safe.
Uri? saveEmbeddedArtwork(String artworkDir, Uint8List bytes, String mime, {String? albumKey}) {
  if (bytes.isEmpty) return null;
  final key = albumKey ?? sha1.convert(bytes).toString();
  final ext = imageExtension(bytes, mime);
  final dir = Directory(artworkDir);
  final target = File(p.join(artworkDir, 'local_$key$ext'));
  try {
    if (target.existsSync()) return Uri.file(target.path);
    dir.createSync(recursive: true);
    final tmp = File('${target.path}.${_rand.nextInt(1 << 32)}.tmp');
    tmp.writeAsBytesSync(bytes, flush: true);
    tmp.renameSync(target.path);
    return Uri.file(target.path);
  } on FileSystemException {
    return null;
  }
}
