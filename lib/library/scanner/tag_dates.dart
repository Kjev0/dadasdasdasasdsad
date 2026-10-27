import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Lossless handling of the recording-date tags around `audio_metadata_reader`.
///
/// The package models dates as a `DateTime` list (FLAC `DATE`) or a plain
/// year (ID3 `TDRC`/`TYER`), and its writers emit their own representation:
/// `DATE=2019` becomes `2019-01-01`, an unparseable `DATE=2019-05` is dropped
/// and an ID3v2.4 `TDRC=2019-05-03` becomes `TYER=2019`. The helpers here read
/// the raw date text from the file before a write and put it back afterwards.

// ------------------------------------------------------------------- FLAC

class _FlacBlock {
  _FlacBlock(this.type, this.last, this.data);

  final int type;
  bool last;
  Uint8List data;
}

const _flacVorbisComment = 4;

/// (blocks, offset of the first audio frame), or null when [b] is no FLAC.
(List<_FlacBlock>, int)? _parseFlac(Uint8List b) {
  if (b.length < 8 || b[0] != 0x66 || b[1] != 0x4C || b[2] != 0x61 || b[3] != 0x43) return null;
  final blocks = <_FlacBlock>[];
  var o = 4;
  while (o + 4 <= b.length) {
    final last = (b[o] & 0x80) != 0;
    final type = b[o] & 0x7F;
    final len = (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
    if (o + 4 + len > b.length) return null;
    blocks.add(_FlacBlock(type, last, Uint8List.sublistView(b, o + 4, o + 4 + len)));
    o += 4 + len;
    if (last) return (blocks, o);
  }
  return null;
}

int _u32le(Uint8List d, int o) => d[o] | (d[o + 1] << 8) | (d[o + 2] << 16) | (d[o + 3] << 24);

List<int> _le32(int v) => [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];

/// Vendor string and raw `NAME=value` comments of a Vorbis comment block.
(List<int>, List<String>)? _parseComments(Uint8List d) {
  try {
    final vendorLen = _u32le(d, 0);
    final vendor = d.sublist(4, 4 + vendorLen);
    var o = 4 + vendorLen;
    final count = _u32le(d, o);
    o += 4;
    final out = <String>[];
    for (var i = 0; i < count; i++) {
      final len = _u32le(d, o);
      out.add(utf8.decode(d.sublist(o + 4, o + 4 + len), allowMalformed: true));
      o += 4 + len;
    }
    return (vendor, out);
  } on RangeError {
    return null;
  }
}

bool _isDate(String c) => c.length > 4 && c.substring(0, 5).toUpperCase() == 'DATE=';

/// The raw `DATE` values of a FLAC file (empty when none / not FLAC).
List<String> readFlacDates(File file) {
  final parsed = _parseFlac(file.readAsBytesSync());
  if (parsed == null) return const [];
  for (final b in parsed.$1) {
    if (b.type != _flacVorbisComment) continue;
    final c = _parseComments(b.data);
    return c == null ? const [] : [for (final e in c.$2) if (_isDate(e)) e.substring(5)];
  }
  return const [];
}

/// Replaces all `DATE` comments of the FLAC file by [dates] (raw text).
void writeFlacDates(File file, List<String> dates) {
  final bytes = file.readAsBytesSync();
  final parsed = _parseFlac(bytes);
  if (parsed == null) return;
  final (blocks, audioStart) = parsed;
  final index = blocks.indexWhere((b) => b.type == _flacVorbisComment);
  if (index < 0) return;
  final c = _parseComments(blocks[index].data);
  if (c == null) return;
  final comments = [...c.$2.where((e) => !_isDate(e)), for (final d in dates) 'DATE=$d'];
  final out = BytesBuilder()
    ..add(_le32(c.$1.length))
    ..add(c.$1)
    ..add(_le32(comments.length));
  for (final e in comments) {
    final enc = utf8.encode(e);
    out
      ..add(_le32(enc.length))
      ..add(enc);
  }
  blocks[index].data = out.toBytes();
  final result = BytesBuilder()..add(const [0x66, 0x4C, 0x61, 0x43]);
  for (final b in blocks) {
    result
      ..addByte((b.last ? 0x80 : 0) | b.type)
      ..add([(b.data.length >> 16) & 0xFF, (b.data.length >> 8) & 0xFF, b.data.length & 0xFF])
      ..add(b.data);
  }
  result.add(Uint8List.sublistView(bytes, audioStart));
  _replace(file, result.takeBytes());
}

// ------------------------------------------------------------------- ID3v2

class _Id3Frame {
  _Id3Frame(this.id, this.flags, this.data);

  final String id;
  final List<int> flags;
  final Uint8List data;
}

class _Id3Tag {
  _Id3Tag(this.version, this.frames, this.end);

  final int version;
  final List<_Id3Frame> frames;

  /// Offset of the first byte after the whole tag.
  final int end;
}

int _syncSafe(Uint8List b, int o) => ((b[o] & 0x7F) << 21) | ((b[o + 1] & 0x7F) << 14) | ((b[o + 2] & 0x7F) << 7) | (b[o + 3] & 0x7F);

List<int> _toSyncSafe(int v) => [(v >> 21) & 0x7F, (v >> 14) & 0x7F, (v >> 7) & 0x7F, v & 0x7F];

/// The ID3v2.3/2.4 tag at the start of [b] (no unsynchronisation), or null.
_Id3Tag? _parseId3(Uint8List b) {
  if (b.length < 10 || b[0] != 0x49 || b[1] != 0x44 || b[2] != 0x33) return null;
  final version = b[3];
  if (version != 3 && version != 4) return null;
  final flags = b[5];
  if ((flags & 0x80) != 0) return null; // unsynchronisation
  final size = _syncSafe(b, 6);
  final end = 10 + size + ((version == 4 && (flags & 0x10) != 0) ? 10 : 0);
  if (end > b.length) return null;
  var o = 10;
  if ((flags & 0x40) != 0) {
    if (b.length < o + 4) return null;
    o += version == 4 ? _syncSafe(b, o) : 4 + ((b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3]);
  }
  final frames = <_Id3Frame>[];
  final payloadEnd = 10 + size;
  while (o + 10 <= payloadEnd && b[o] != 0) {
    final id = ascii.decode(b.sublist(o, o + 4), allowInvalid: true);
    final len = version == 4 ? _syncSafe(b, o + 4) : ((b[o + 4] << 24) | (b[o + 5] << 16) | (b[o + 6] << 8) | b[o + 7]);
    if (o + 10 + len > payloadEnd) return null;
    frames.add(_Id3Frame(id, b.sublist(o + 8, o + 10), Uint8List.sublistView(b, o + 10, o + 10 + len)));
    o += 10 + len;
  }
  return _Id3Tag(version, frames, end);
}

String _decodeText(Uint8List d) {
  if (d.isEmpty) return '';
  final enc = d[0];
  final body = Uint8List.sublistView(d, 1);
  String s;
  switch (enc) {
    case 0:
      s = latin1.decode(body);
    case 1:
    case 2:
      var big = enc == 2;
      var start = 0;
      if (body.length >= 2 && enc == 1) {
        if (body[0] == 0xFE && body[1] == 0xFF) {
          big = true;
          start = 2;
        } else if (body[0] == 0xFF && body[1] == 0xFE) {
          start = 2;
        }
      }
      final units = <int>[
        for (var i = start; i + 1 < body.length; i += 2) big ? (body[i] << 8) | body[i + 1] : body[i] | (body[i + 1] << 8),
      ];
      s = String.fromCharCodes(units);
    default:
      s = utf8.decode(body, allowMalformed: true);
  }
  return s.replaceAll('\u0000', '').trim();
}

/// The raw text of the ID3v2.4 `TDRC` frame of [file] (e.g. `2019-05-03`).
String? readId3RecordingTime(File file) {
  final tag = _parseId3(file.readAsBytesSync());
  if (tag == null || tag.version != 4) return null;
  for (final f in tag.frames) {
    if (f.id == 'TDRC') {
      final text = _decodeText(f.data);
      return text.isEmpty ? null : text;
    }
  }
  return null;
}

/// Rewrites the ID3v2.4 tag of [file] so that it holds exactly one date
/// frame, `TDRC=[time]`, instead of the writer's `TYER`.
void writeId3RecordingTime(File file, String time) {
  final bytes = file.readAsBytesSync();
  final tag = _parseId3(bytes);
  if (tag == null || tag.version != 4) return;
  final frames = [
    for (final f in tag.frames)
      if (f.id != 'TDRC' && f.id != 'TYER') f,
    _Id3Frame('TDRC', const [0, 0], Uint8List.fromList([3, ...utf8.encode(time)])),
  ];
  final payload = BytesBuilder();
  for (final f in frames) {
    payload
      ..add(ascii.encode(f.id))
      ..add(_toSyncSafe(f.data.length))
      ..add(f.flags)
      ..add(f.data);
  }
  final out = BytesBuilder()
    ..add(const [0x49, 0x44, 0x33, 4, 0, 0])
    ..add(_toSyncSafe(payload.length))
    ..add(payload.toBytes())
    ..add(Uint8List.sublistView(bytes, tag.end));
  _replace(file, out.takeBytes());
}

void _replace(File file, List<int> bytes) {
  final tmp = File('${file.path}.dates.tmp');
  try {
    tmp.writeAsBytesSync(bytes, flush: true);
    tmp.renameSync(file.path);
  } finally {
    if (tmp.existsSync()) tmp.deleteSync();
  }
}
