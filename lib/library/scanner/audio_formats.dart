import 'package:path/path.dart' as p;

import '../../core/platform/platform_info.dart';

/// Audio file extensions the scanner picks up on every platform.
const commonAudioExtensions = <String>{
  '.mp3',
  '.flac',
  '.m4a',
  '.mp4',
  '.aac',
  '.ogg',
  '.oga',
  '.opus',
  '.wav',
  '.aiff',
  '.aif',
  '.aifc',
};

/// Extensions only scanned on desktop (decoded by libmpv; Android's
/// ExoPlayer has no WMA decoder).
const desktopOnlyAudioExtensions = <String>{'.wma'};

/// Extensions `audio_metadata_reader` can rewrite *and* whose writer output
/// can be verified to be lossless by re-reading the file (see
/// `tag_writer.dart`). MP4/M4A is excluded on purpose: its writer drops
/// atoms the reader cannot see (album artist, iTunes freeform tags), so a
/// lossless write cannot be verified.
const writableTagExtensions = <String>{'.mp3', '.flac', '.wav'};

/// Image files used as folder artwork, in priority order (case-insensitive).
const folderArtNames = <String>[
  'cover.jpg',
  'cover.jpeg',
  'cover.png',
  'folder.jpg',
  'folder.jpeg',
  'folder.png',
  'front.jpg',
  'front.jpeg',
  'front.png',
  'albumart.jpg',
  'albumart.png',
];

/// Extensions scanned on [platform].
Set<String> scannableExtensions(PlatformInfo platform) =>
    {...commonAudioExtensions, if (!platform.isAndroid) ...desktopOnlyAudioExtensions};

/// Lower-case extension including the dot.
String extensionOf(String path) => p.extension(path).toLowerCase();

/// Codec name stored in `AudioFormatInfo.codec` (best effort from the
/// container; M4A may also hold ALAC).
String codecForExtension(String ext) => switch (ext) {
      '.mp3' => 'mp3',
      '.flac' => 'flac',
      '.m4a' || '.mp4' || '.aac' => 'aac',
      '.ogg' || '.oga' => 'vorbis',
      '.opus' => 'opus',
      '.wav' => 'pcm',
      '.aiff' || '.aif' || '.aifc' => 'pcm',
      '.wma' => 'wma',
      _ => ext.replaceFirst('.', ''),
    };
