import 'dart:convert';
import 'dart:typed_data';

import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/library/scanner/artwork_store.dart';
import 'package:fermata/library/scanner/audio_formats.dart';
import 'package:fermata/library/scanner/filename_parser.dart';
import 'package:fermata/library/scanner/m3u.dart';
import 'package:fermata/library/scanner/tag_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('filename parser', () {
    test('artist - title', () {
      final f = parseFilename('/x/Daft Punk - One More Time.mp3');
      expect((f.artist, f.title, f.trackNumber), ('Daft Punk', 'One More Time', null));
    });
    test('track numbers', () {
      expect(parseFilename('01 - Intro.flac').trackNumber, 1);
      expect(parseFilename('01 - Intro.flac').title, 'Intro');
      expect(parseFilename('03. Artist - Song.ogg').artist, 'Artist');
      expect(parseFilename('03. Artist - Song.ogg').trackNumber, 3);
      expect(parseFilename('07_Some_Title.mp3').title, 'Some Title');
      expect(parseFilename('07_Some_Title.mp3').trackNumber, 7);
      final dt = parseFilename('2-05 Deep Cut.m4a');
      expect((dt.discNumber, dt.trackNumber, dt.title), (2, 5, 'Deep Cut'));
      expect(parseFilename('09 Song.mp3').trackNumber, 9);
    });
    test('numbers that belong to the name are kept', () {
      final f = parseFilename('50 Cent - In Da Club.mp3');
      expect((f.artist, f.title, f.trackNumber), ('50 Cent', 'In Da Club', null));
      expect(parseFilename('1999.mp3').title, '1999');
    });
  });

  group('tag helpers', () {
    test('ReplayGain parsing', () {
      expect(parseGainDb('-6.50 dB'), -6.5);
      expect(parseGainDb(' +1,25 dB'), 1.25);
      expect(parseGainDb('n/a'), isNull);
    });
    test('ID3 genres', () {
      expect(cleanId3Genre('(17)Rock'), 'Rock');
      expect(cleanId3Genre('(17)'), isNull);
      expect(cleanId3Genre('13'), isNull);
      expect(cleanId3Genre('Jazz\u0000'), 'Jazz');
    });
    test('mojibake repair', () {
      expect(fixMojibake('FlÃ¸jte'), 'Fløjte');
      expect(fixMojibake('Plain'), 'Plain');
      expect(fixMojibake('Café'), 'Café'); // genuine Latin-1 stays
      expect(fixMojibake('Søren 日本'), 'Søren 日本');
    });
    test('local ids are stable sha1 of the canonical path', () {
      final a = localTrackIdFor('/music/a/../a/song.mp3');
      expect(a, localTrackIdFor('/music/a/song.mp3'));
      expect(a, hasLength(40));
      expect(Track.makeId('local', a), startsWith('local:'));
    });
  });

  group('formats', () {
    test('desktop scans wma, Android does not', () {
      expect(scannableExtensions(const PlatformInfo(os: HostOs.linux)), contains('.wma'));
      expect(scannableExtensions(const PlatformInfo(os: HostOs.android)), isNot(contains('.wma')));
      expect(scannableExtensions(const PlatformInfo(os: HostOs.android)), containsAll(['.mp3', '.flac', '.m4a', '.ogg', '.opus', '.wav', '.aiff']));
      expect(codecForExtension('.oga'), 'vorbis');
    });
    test('artwork keys and extensions', () {
      expect(albumArtworkKey('Søren', 'Ålborg'), albumArtworkKey('soren', 'aalborg'));
      expect(albumArtworkKey('X', null), isNull);
      expect(imageExtension(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0]), ''), '.jpg');
      expect(imageExtension(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]), 'application/octet-stream'), '.png');
      expect(imageExtension(Uint8List(0), 'image/png'), '.png');
    });
  });

  group('M3U', () {
    test('parse resolves paths and skips URLs', () {
      const content = '#EXTM3U\n'
          '#EXTINF:123,Artist - Title\n'
          'sub/song.mp3\n'
          '#EXTINF:-1 tvg-id="x",Stream\n'
          'http://radio.example/stream\n'
          r'..\other\win.flac' '\n'
          '/abs/path.ogg\n'
          'file:///abs/uri%20space.opus\n';
      final r = parseM3u(content, '/base/dir');
      expect(r.skippedUrls, ['http://radio.example/stream']);
      expect(r.entries.map((e) => e.path), [
        p.normalize('/base/dir/sub/song.mp3'),
        p.normalize('/base/other/win.flac'),
        '/abs/path.ogg',
        '/abs/uri space.opus',
      ]);
      expect(r.entries.first.title, 'Artist - Title');
      expect(r.entries.first.duration, const Duration(seconds: 123));
      expect(r.entries[1].title, isNull); // EXTINF applies to the next entry only
    });
    test('decodes UTF-8 with BOM and falls back to Latin-1', () {
      expect(decodePlaylistBytes([0xEF, 0xBB, 0xBF, ...utf8.encode('Ærø')]), 'Ærø');
      expect(decodePlaylistBytes(latin1.encode('Café')), 'Café');
    });
    test('build writes extended entries and relative paths inside the dir', () {
      final tracks = [
        const Track(sourceId: 'local', sourceTrackId: 'a', title: 'A', artists: [ArtistRef('X')], duration: Duration(seconds: 61), localPath: '/m/list/a.mp3'),
        const Track(sourceId: 'local', sourceTrackId: 'b', title: 'B', localPath: '/elsewhere/b.mp3'),
        const Track(sourceId: 'deezer', sourceTrackId: 'c', title: 'C'),
      ];
      expect(buildM3u(tracks, '/m/list', playlistName: 'L'),
          '#EXTM3U\n#PLAYLIST:L\n#EXTINF:61,X - A\na.mp3\n#EXTINF:-1,B\n/elsewhere/b.mp3\n');
      expect(buildM3u(tracks, '/m/list', extended: false, lineEnding: '\r\n'), 'a.mp3\r\n/elsewhere/b.mp3\r\n');
    });
  });
}
