import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/models/track.dart';

/// Cross-platform file-name sanitising (Windows is the strictest target:
/// reserved device names, `<>:"/\|?*`, control characters, trailing dots
/// and spaces; ext4/NTFS component limits).
abstract final class FileNameSanitizer {
  /// Max UTF-8 bytes per path component (well below the 255-byte limit of
  /// ext4/NTFS so `" (2)"` suffixes and long Windows paths still fit).
  static const maxComponentBytes = 120;

  static const _reserved = {
    'CON', 'PRN', 'AUX', 'NUL', //
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
    'COM¹', 'COM²', 'COM³', 'LPT¹', 'LPT²', 'LPT³',
  };

  static final _illegal = RegExp(r'[<>:"/\\|?*\x00-\x1F\x7F]');
  static final _spaces = RegExp(r'\s+');
  static final _trailing = RegExp(r'[. ]+$');
  static final _leadingDots = RegExp(r'^[. ]+');

  /// Returns a safe single path component for [input].
  static String sanitize(String? input, {String fallback = 'Unknown', int maxBytes = maxComponentBytes}) {
    var s = (input ?? '').replaceAll(_illegal, '_').replaceAll(_spaces, ' ').trim();
    // No hidden files on Unix, no trailing dots/spaces on Windows.
    s = s.replaceFirst(_leadingDots, '').replaceFirst(_trailing, '');
    if (s.isEmpty || s.replaceAll('_', '').isEmpty) s = fallback;
    s = truncateUtf8(s, maxBytes).replaceFirst(_trailing, '');
    if (s.isEmpty) s = fallback;
    final stem = s.split('.').first.trim().toUpperCase();
    if (_reserved.contains(stem)) s = '_$s';
    return s;
  }

  /// Truncates to at most [maxBytes] UTF-8 bytes without splitting a code
  /// point.
  static String truncateUtf8(String s, int maxBytes) {
    if (utf8.encode(s).length <= maxBytes) return s;
    final out = StringBuffer();
    var bytes = 0;
    for (final rune in s.runes) {
      final ch = String.fromCharCode(rune);
      final len = utf8.encode(ch).length;
      if (bytes + len > maxBytes) break;
      out.write(ch);
      bytes += len;
    }
    return out.toString().trimRight();
  }
}

/// Layout of finished downloads:
/// `<downloadDir>/<Artist>/<Album or Singles>/<NN - >Title.<ext>`.
abstract final class DownloadPathBuilder {
  static const singlesFolder = 'Singles';
  static const unknownArtist = 'Unknown Artist';

  /// Path relative to the download directory (platform separators).
  static String relativePathFor(Track track, String extension) {
    final artistName = (track.albumArtist?.trim().isNotEmpty ?? false) ? track.albumArtist : track.primaryArtist;
    final artist = FileNameSanitizer.sanitize(artistName, fallback: unknownArtist, maxBytes: 80);
    final albumName = track.album?.trim();
    final album = FileNameSanitizer.sanitize(
      (albumName == null || albumName.isEmpty) ? singlesFolder : albumName,
      fallback: singlesFolder,
      maxBytes: 80,
    );
    return p.join(artist, album, fileNameFor(track, extension));
  }

  /// `NN - Title.ext` (`D-NN - ` for disc > 1), sanitised and length-limited.
  static String fileNameFor(Track track, String extension, {int? copy}) {
    final ext = extension.isEmpty ? '' : '.$extension';
    final number = track.trackNumber;
    var prefix = '';
    if (number != null && number > 0) {
      final disc = track.discNumber;
      prefix = '${disc != null && disc > 1 ? '$disc-' : ''}${number.toString().padLeft(2, '0')} - ';
    }
    final suffix = copy == null ? '' : ' ($copy)';
    final budget = FileNameSanitizer.maxComponentBytes - utf8.encode('$prefix$suffix$ext').length;
    final title = FileNameSanitizer.sanitize(track.title, fallback: 'Untitled', maxBytes: budget);
    return '$prefix$title$suffix$ext';
  }

  /// A path below [root] for [track] that does not exist yet (adds
  /// ` (2)`, ` (3)`, ... on collisions).
  static Future<String> uniqueTarget(String root, Track track, String extension) async {
    final relative = relativePathFor(track, extension);
    final dir = p.join(root, p.dirname(relative));
    var candidate = p.join(root, relative);
    for (var copy = 2; await FileSystemEntity.type(candidate) != FileSystemEntityType.notFound; copy++) {
      candidate = p.join(dir, fileNameFor(track, extension, copy: copy));
    }
    return candidate;
  }
}
