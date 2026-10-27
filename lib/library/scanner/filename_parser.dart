import 'package:path/path.dart' as p;

/// Metadata guessed from a file name when tags are missing.
class FilenameInfo {
  const FilenameInfo({required this.title, this.artist, this.trackNumber, this.discNumber});

  final String title;
  final String? artist;
  final int? trackNumber;
  final int? discNumber;
}

final _discTrack = RegExp(r'^(\d{1,2})-(\d{1,3})\s*[.\-_ ]\s*(.+)$');
final _trackSep = RegExp(r'^(\d{1,3})\s*[.\-_)]\s*(.+)$');
final _trackZero = RegExp(r'^(0\d)\s+(.+)$');

/// Parses names like `Artist - Title.mp3`, `01 - Title.flac`,
/// `03. Artist - Title.ogg`, `1-04 Title.m4a` (disc-track) or
/// `07_Some_Title.mp3`. A bare leading number followed only by a space is
/// treated as a track number only when zero-padded (`01 Title`), so names
/// such as `50 Cent - In Da Club` keep their artist.
FilenameInfo parseFilename(String path) {
  var name = p.basenameWithoutExtension(path).trim();
  if (!name.contains(' ') && name.contains('_')) name = name.replaceAll('_', ' ');
  name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  int? track;
  int? disc;
  var m = _discTrack.firstMatch(name);
  if (m != null) {
    disc = int.parse(m.group(1)!);
    track = int.parse(m.group(2)!);
    name = m.group(3)!.trim();
  } else if ((m = _trackSep.firstMatch(name)) != null || (m = _trackZero.firstMatch(name)) != null) {
    track = int.parse(m!.group(1)!);
    name = m.group(2)!.trim();
  }
  String? artist;
  final sep = name.indexOf(' - ');
  if (sep > 0 && sep < name.length - 3) {
    artist = name.substring(0, sep).trim();
    name = name.substring(sep + 3).trim();
  }
  if (name.isEmpty) name = p.basenameWithoutExtension(path);
  return FilenameInfo(
    title: name,
    artist: (artist == null || artist.isEmpty) ? null : artist,
    trackNumber: track == 0 ? null : track,
    discNumber: disc == 0 ? null : disc,
  );
}
