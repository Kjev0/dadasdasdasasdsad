import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

/// Audio container formats recognised by [AudioSniffer].
enum AudioContainer {
  mp3('mp3', 'mp3'),
  aac('aac', 'aac'),
  flac('flac', 'flac'),
  oggVorbis('ogg', 'vorbis'),
  oggOpus('opus', 'opus'),
  oggFlac('oga', 'flac'),
  ogg('ogg', null),
  m4a('m4a', 'aac'),
  wav('wav', 'pcm'),
  aiff('aiff', 'pcm'),
  wma('wma', 'wma'),
  webm('webm', null),
  ape('ape', 'ape'),
  wavPack('wv', 'wavpack'),
  dsf('dsf', 'dsd'),
  musepack('mpc', 'musepack');

  const AudioContainer(this.extension, this.codec);

  /// Canonical file extension (no dot).
  final String extension;

  /// Codec name when implied by the container header, for `AudioFormatInfo`.
  final String? codec;
}

/// Result of [AudioSniffer.sniff].
@immutable
class SniffResult {
  const SniffResult({this.container, this.looksLikeText = false});

  /// Recognised audio container, or null.
  final AudioContainer? container;

  /// The bytes look like text (HTML/XML/JSON error page, plain text).
  final bool looksLikeText;

  bool get isAudio => container != null;

  String? get extension => container?.extension;

  @override
  String toString() => 'SniffResult(${container?.name ?? (looksLikeText ? 'text' : 'unknown')})';
}

/// Magic-number based detection of audio files, used to reject HTML error
/// pages, captive-portal responses and other non-audio bodies before a
/// download is accepted.
abstract final class AudioSniffer {
  /// Bytes read from the file head; enough to skip typical ID3v2 tags.
  static const headLength = 64 * 1024;

  /// Minimum number of bytes [looksLikeText] needs for an early verdict.
  static const earlyCheckLength = 512;

  static Future<SniffResult> sniffFile(File file) async {
    final raf = await file.open();
    try {
      final head = await raf.read(headLength);
      return sniff(head);
    } finally {
      await raf.close();
    }
  }

  static SniffResult sniff(List<int> bytes) {
    final head = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    if (head.length < 4) return SniffResult(looksLikeText: looksLikeText(head));
    final id3 = _id3Size(head);
    if (id3 != null) {
      // Something else (FLAC, ADTS AAC) may hide behind an ID3 tag.
      var next = id3;
      while (next < head.length && head[next] == 0) {
        next++;
      }
      if (next + 4 <= head.length) {
        final inner = _container(Uint8List.sublistView(head, next));
        if (inner != null) return SniffResult(container: inner);
      }
      return const SniffResult(container: AudioContainer.mp3);
    }
    final container = _container(head);
    if (container != null) return SniffResult(container: container);
    return SniffResult(looksLikeText: looksLikeText(head));
  }

  /// Heuristic: HTML/XML/JSON markers or mostly printable ASCII/UTF-8.
  static bool looksLikeText(List<int> head) {
    if (head.isEmpty) return false;
    var i = 0;
    if (head.length >= 3 && head[0] == 0xEF && head[1] == 0xBB && head[2] == 0xBF) i = 3;
    while (i < head.length && _isSpace(head[i])) {
      i++;
    }
    if (i < head.length && (head[i] == 0x3C /* < */ || head[i] == 0x7B /* { */ || head[i] == 0x5B /* [ */)) {
      return true;
    }
    final n = head.length < earlyCheckLength ? head.length : earlyCheckLength;
    var printable = 0;
    for (var j = 0; j < n; j++) {
      final b = head[j];
      if (_isSpace(b) || (b >= 0x20 && b < 0x7F) || b >= 0x80) printable++;
      if (b == 0) return false;
    }
    return printable / n >= 0.97;
  }

  static bool _isSpace(int b) => b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D;

  /// Byte length of a leading ID3v2 tag (header + body + optional footer).
  static int? _id3Size(Uint8List h) {
    if (h.length < 10 || h[0] != 0x49 || h[1] != 0x44 || h[2] != 0x33) return null;
    if (h[3] == 0xFF || h[4] == 0xFF) return null;
    for (var i = 6; i < 10; i++) {
      if (h[i] & 0x80 != 0) return null;
    }
    final size = (h[6] << 21) | (h[7] << 14) | (h[8] << 7) | h[9];
    final footer = (h[5] & 0x10) != 0 ? 10 : 0;
    return 10 + size + footer;
  }

  static bool _ascii(Uint8List h, int offset, String text) {
    if (h.length < offset + text.length) return false;
    for (var i = 0; i < text.length; i++) {
      if (h[offset + i] != text.codeUnitAt(i)) return false;
    }
    return true;
  }

  static AudioContainer? _container(Uint8List h) {
    if (_ascii(h, 0, 'fLaC')) return AudioContainer.flac;
    if (_ascii(h, 0, 'OggS')) return _ogg(h);
    if (_ascii(h, 4, 'ftyp')) return AudioContainer.m4a;
    if (_ascii(h, 0, 'RIFF') && _ascii(h, 8, 'WAVE')) return AudioContainer.wav;
    if (_ascii(h, 0, 'FORM') && (_ascii(h, 8, 'AIFF') || _ascii(h, 8, 'AIFC'))) return AudioContainer.aiff;
    if (_ascii(h, 0, 'MAC ')) return AudioContainer.ape;
    if (_ascii(h, 0, 'wvpk')) return AudioContainer.wavPack;
    if (_ascii(h, 0, 'DSD ')) return AudioContainer.dsf;
    if (_ascii(h, 0, 'MPCK') || _ascii(h, 0, 'MP+')) return AudioContainer.musepack;
    if (h.length >= 4 && h[0] == 0x1A && h[1] == 0x45 && h[2] == 0xDF && h[3] == 0xA3) return AudioContainer.webm;
    if (h.length >= 8 &&
        h[0] == 0x30 &&
        h[1] == 0x26 &&
        h[2] == 0xB2 &&
        h[3] == 0x75 &&
        h[4] == 0x8E &&
        h[5] == 0x66 &&
        h[6] == 0xCF &&
        h[7] == 0x11) {
      return AudioContainer.wma;
    }
    return _mpegFrame(h);
  }

  static AudioContainer _ogg(Uint8List h) {
    // First page: 27-byte header + segment table, then the codec packet.
    if (h.length > 27) {
      final segments = h[26];
      final start = 27 + segments;
      if (_ascii(h, start, 'OpusHead')) return AudioContainer.oggOpus;
      if (h.length > start + 7 && h[start] == 0x01 && _ascii(h, start + 1, 'vorbis')) return AudioContainer.oggVorbis;
      if (h.length > start + 5 && h[start] == 0x7F && _ascii(h, start + 1, 'FLAC')) return AudioContainer.oggFlac;
    }
    return AudioContainer.ogg;
  }

  /// MPEG audio (MP1/2/3) or ADTS AAC frame sync at offset 0.
  static AudioContainer? _mpegFrame(Uint8List h) {
    if (h.length < 4 || h[0] != 0xFF || (h[1] & 0xE0) != 0xE0) return null;
    final layer = (h[1] >> 1) & 0x03;
    if (layer == 0) {
      // ADTS: 12-bit sync 0xFFF, layer 00.
      if ((h[1] & 0xF0) != 0xF0) return null;
      final freqIndex = (h[2] >> 2) & 0x0F;
      return freqIndex <= 12 ? AudioContainer.aac : null;
    }
    final version = (h[1] >> 3) & 0x03;
    final bitrateIndex = (h[2] >> 4) & 0x0F;
    final sampleRateIndex = (h[2] >> 2) & 0x03;
    if (version == 1 || bitrateIndex == 0x0F || sampleRateIndex == 0x03) return null;
    return AudioContainer.mp3;
  }

  /// File extension for an audio MIME type, or null for unknown/non-audio.
  static String? extensionForContentType(String? contentType) {
    if (contentType == null) return null;
    final mime = contentType.split(';').first.trim().toLowerCase();
    return const {
      'audio/mpeg': 'mp3',
      'audio/mp3': 'mp3',
      'audio/mpeg3': 'mp3',
      'audio/x-mpeg': 'mp3',
      'audio/flac': 'flac',
      'audio/x-flac': 'flac',
      'audio/ogg': 'ogg',
      'audio/vorbis': 'ogg',
      'audio/opus': 'opus',
      'audio/mp4': 'm4a',
      'audio/x-m4a': 'm4a',
      'audio/m4a': 'm4a',
      'audio/aac': 'aac',
      'audio/aacp': 'aac',
      'audio/wav': 'wav',
      'audio/wave': 'wav',
      'audio/x-wav': 'wav',
      'audio/aiff': 'aiff',
      'audio/x-aiff': 'aiff',
      'audio/webm': 'webm',
      'audio/x-ms-wma': 'wma',
    }[mime];
  }

  /// Normalises an extension suggested by a source (`.MP3` → `mp3`); returns
  /// null for anything that is not a short alphanumeric token.
  static String? normalizeExtension(String? ext) {
    if (ext == null) return null;
    final e = ext.trim().toLowerCase().replaceFirst(RegExp(r'^\.+'), '');
    if (e.isEmpty || e.length > 5 || !RegExp(r'^[a-z0-9]+$').hasMatch(e)) return null;
    return e;
  }

  /// Picks the extension for a finished download: the source's suggestion
  /// first, then the sniffed container (it reflects the real bytes), then the
  /// response Content-Type.
  static String chooseExtension({String? suggested, String? contentType, SniffResult? sniffed}) =>
      normalizeExtension(suggested) ?? sniffed?.extension ?? extensionForContentType(contentType) ?? 'audio';
}
