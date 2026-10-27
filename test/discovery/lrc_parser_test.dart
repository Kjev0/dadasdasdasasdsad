import 'dart:convert';
import 'dart:io';

import 'package:fermata/discovery/lyrics/lrc_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  test('basic lines, sorted, centiseconds and milliseconds', () {
    final r = LrcParser.parse('[00:12.50]Second\n[00:01.00]First\n[01:02.345]Third');
    expect([for (final l in r.lines) l.time], [ms(1000), ms(12500), ms(62345)]);
    expect([for (final l in r.lines) l.text], ['First', 'Second', 'Third']);
    expect(r.isSynced, isTrue);
  });

  test('several timestamps on one line produce several lines', () {
    final r = LrcParser.parse('[00:10.00][00:30.00][01:00.00]Chorus\n[00:20.00]Verse');
    expect([for (final l in r.lines) (l.time.inSeconds, l.text)],
        [(10, 'Chorus'), (20, 'Verse'), (30, 'Chorus'), (60, 'Chorus')]);
  });

  test('metadata tags are collected, not shown as lyrics', () {
    final r = LrcParser.parse('[ar:Artist]\n[ti:Title]\n[al:Album]\n[by:someone]\n[length: 03:20]\n[#:comment]\n[00:01.00]Hi');
    expect(r.tags, {'ar': 'Artist', 'ti': 'Title', 'al': 'Album', 'by': 'someone', 'length': '03:20', '#': 'comment'});
    expect(r.lines, hasLength(1));
    expect(r.plainLines, isEmpty);
  });

  test('positive offset shows lyrics earlier, negative later, never below zero', () {
    final earlier = LrcParser.parse('[offset:+500]\n[00:00.20]A\n[00:10.00]B');
    expect(earlier.offset, ms(500));
    expect([for (final l in earlier.lines) l.time], [Duration.zero, ms(9500)]);
    final later = LrcParser.parse('[offset:-250]\n[00:10.00]B');
    expect(later.lines.single.time, ms(10250));
    expect(LrcParser.parse('[offset: junk]\n[00:01.00]x').offset, Duration.zero);
  });

  test('timestamp variants: mm:ss, mm:ss.x, mm:ss:xx, long minutes, hours', () {
    final r = LrcParser.parse('[00:05]a\n[00:06.5]b\n[00:07:25]c\n[75:01.00]d\n[1:02:03.40]e');
    expect([for (final l in r.lines) l.time],
        [ms(5000), ms(6500), ms(7250), ms(((62 * 60) + 3) * 1000 + 400), ms((75 * 60 + 1) * 1000)]);
    expect([for (final l in r.lines) l.text], ['a', 'b', 'c', 'e', 'd']);
  });

  test('enhanced word timings are stripped; blank lyric lines are gaps', () {
    final r = LrcParser.parse('[00:01.00]<00:01.00>Hello <00:01.50>world\n[00:03.00]\n[00:04.00]  spaced   out  ');
    expect([for (final l in r.lines) l.text], ['Hello world', '', 'spaced out']);
  });

  test('BOM, CRLF and CR line endings', () {
    final r = LrcParser.parse('﻿[ti:T]\r\n[00:01.00]One\r[00:02.00]Two\r\n');
    expect(r.tags['ti'], 'T');
    expect([for (final l in r.lines) l.text], ['One', 'Two']);
  });

  test('stable order for equal timestamps, invalid seconds are text', () {
    final r = LrcParser.parse('[00:05.00]first\n[00:05.00]second\n[00:61.00]not a time');
    expect([for (final l in r.lines) l.text], ['first', 'second']);
    expect(r.plainLines, ['[00:61.00]not a time']);
  });

  test('plain text is not LRC', () {
    const plain = 'Just some words\n[Chorus]\nMore words';
    expect(LrcParser.looksLikeLrc(plain), isFalse);
    final r = LrcParser.parse(plain);
    expect(r.isSynced, isFalse);
    expect(r.plainText, 'Just some words\n[Chorus]\nMore words');
  });

  test('parses a real LRCLIB record', () {
    final record = jsonDecode(File('test/discovery/fixtures/lrclib_get_ok.json').readAsStringSync()) as Map;
    final r = LrcParser.parse(record['syncedLyrics'] as String);
    expect(r.lines.first.time, ms(17120));
    expect(r.lines.first.text, 'I feel your breath upon my neck');
    expect(r.lines.where((l) => l.text.isEmpty), isNotEmpty, reason: 'instrumental breaks kept');
    for (var i = 1; i < r.lines.length; i++) {
      expect(r.lines[i].time >= r.lines[i - 1].time, isTrue);
    }
  });
}
