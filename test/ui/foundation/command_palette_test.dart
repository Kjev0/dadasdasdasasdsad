import 'package:fermata/l10n/gen/app_localizations_da.dart';
import 'package:fermata/l10n/gen/app_localizations_en.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/actions/fuzzy.dart';
import 'package:fermata/ui/pages/playlists/playlist_detail_page.dart';
import 'package:fermata/ui/pages/settings/settings_page.dart';
import 'package:fermata/ui/player/queue_page.dart';
import 'package:fermata/ui/shell/command_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

List<String> _titles(String query, {bool danish = false}) {
  final l10n = danish ? AppLocalizationsDa() : AppLocalizationsEn();
  final entries = commandPaletteEntries(l10n, bindings: ShortcutActions.defaults);
  return [for (final e in filterPaletteEntries(entries, query)) e.title];
}

Future<void> _openPalette(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await pumpFrames(tester);
  expect(find.byType(CommandPalette), findsOneWidget);
}

void main() {
  group('fuzzy matching', () {
    test('substring, prefix and subsequence matches', () {
      expect(fuzzyScore('que', 'Queue'), isNotNull);
      expect(fuzzyScore('qu', 'Show the queue'), isNotNull);
      expect(fuzzyScore('shfl', 'Shuffle on or off'), isNotNull);
      expect(fuzzyScore('xyz', 'Queue'), isNull);
      // Prefix beats a later word.
      expect(fuzzyScore('sett', 'Settings')!, greaterThan(fuzzyScore('sett', 'Open settings')!));
      // Every token must match.
      expect(fuzzyScore('sleep queue', 'Show the queue'), isNull);
    });

    test('ignores case and diacritics', () {
      expect(fuzzyScore('dansk', 'DANSK'), isNotNull);
      expect(fuzzyScore('kø', 'Vis køen'), isNotNull);
      expect(fuzzyScore('ko', 'Vis køen'), isNotNull);
      expect(foldForSearch('Ærø Café'), 'aero cafe');
    });

    test('fuzzyFilter sorts best first and drops non-matches', () {
      final result = fuzzyFilter(['Open settings', 'Settings', 'Search'], 'set', (s) => [s]);
      expect(result, ['Settings', 'Open settings']);
    });
  });

  group('palette entries', () {
    test('cover navigation, player commands and settings sections', () {
      final all = _titles('');
      expect(all, containsAll(['Home', 'Search', 'Queue', 'Now playing', 'Play or pause', 'Next track', 'Liquid Glass', 'Keyboard shortcuts']));
    });

    test('filtering ranks the obvious match first', () {
      expect(_titles('queue').first, 'Queue');
      expect(_titles('glass').first, 'Liquid Glass');
      expect(_titles('next').first, 'Next track');
      expect(_titles('shfl'), contains('Shuffle on or off'));
      expect(_titles('zzzz'), isEmpty);
      // Danish labels.
      expect(_titles('kø', danish: true).first, 'Kø');
      expect(_titles('sovetimer', danish: true), isEmpty);
    });

    test('shows bound shortcuts', () {
      final entries = commandPaletteEntries(AppLocalizationsEn(), bindings: ShortcutActions.defaults);
      expect(entries.firstWhere((e) => e.id == ShortcutActions.playPause).shortcut, 'Space');
      expect(entries.firstWhere((e) => e.id == ShortcutActions.queue).shortcut, 'Ctrl+Q');
    });
  });

  group('palette UI', () {
    testWidgets('typing filters, Enter runs the selected command', (tester) async {
      await pumpFermata(tester);
      await _openPalette(tester);
      await tester.enterText(find.descendant(of: find.byType(CommandPalette), matching: find.byType(TextField)), 'queue');
      await pumpFrames(tester, count: 6);
      final rows = find.descendant(of: find.byType(ListView), matching: find.byType(InkWell));
      expect(find.descendant(of: rows.first, matching: find.text('Queue')), findsOneWidget);
      expect(find.byKey(const ValueKey('palette-queue')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await pumpFrames(tester);
      expect(find.byType(CommandPalette), findsNothing);
      expect(find.byType(QueuePage), findsOneWidget);
    });

    testWidgets('arrow keys move the selection; settings sections deep-link', (tester) async {
      await pumpFermata(tester);
      await _openPalette(tester);
      await tester.enterText(find.descendant(of: find.byType(CommandPalette), matching: find.byType(TextField)), 'storage');
      await pumpFrames(tester, count: 6);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await pumpFrames(tester);
      final page = tester.widget<SettingsPage>(find.byType(SettingsPage));
      expect(page.section, 'storage');
    });

    testWidgets('player commands run against the controller', (tester) async {
      final kit = FakeKit(tracks: testTracks(2));
      kit.playback.load(kit.tracks.all);
      await pumpFermata(tester, kit: kit);
      await _openPalette(tester);
      await tester.enterText(find.descendant(of: find.byType(CommandPalette), matching: find.byType(TextField)), 'next track');
      await pumpFrames(tester, count: 6);
      await tester.tap(find.descendant(of: find.byType(CommandPalette), matching: find.text('Next track')));
      await pumpFrames(tester);
      expect(kit.playback.called('next'), isTrue);
    });

    testWidgets('lists playlists and library tracks', (tester) async {
      final kit = FakeKit(tracks: [testTrack('x', title: 'Nightcall', artist: 'Kavinsky')]);
      kit.playlists.add(testPlaylist('p9', name: 'Night drive'));
      await pumpFermata(tester, kit: kit);
      await _openPalette(tester);
      await tester.enterText(find.descendant(of: find.byType(CommandPalette), matching: find.byType(TextField)), 'night');
      await pumpFrames(tester, count: 8);
      expect(find.descendant(of: find.byType(CommandPalette), matching: find.text('Night drive')), findsOneWidget);
      expect(find.descendant(of: find.byType(CommandPalette), matching: find.text('Nightcall')), findsOneWidget);
      expect(kit.tracks.called('query'), isTrue);

      await tester.tap(find.descendant(of: find.byType(CommandPalette), matching: find.text('Nightcall')));
      await pumpFrames(tester);
      expect(kit.playback.argsOf('playTracks').first, [kit.tracks.all.single]);

      await _openPalette(tester);
      await tester.enterText(find.descendant(of: find.byType(CommandPalette), matching: find.byType(TextField)), 'night drive');
      await pumpFrames(tester, count: 8);
      await tester.tap(find.descendant(of: find.byType(CommandPalette), matching: find.text('Night drive')));
      await pumpFrames(tester);
      expect(tester.widget<PlaylistDetailPage>(find.byType(PlaylistDetailPage)).playlistId, 'p9');
    });

    testWidgets('no results message', (tester) async {
      await pumpFermata(tester);
      await _openPalette(tester);
      await tester.enterText(find.descendant(of: find.byType(CommandPalette), matching: find.byType(TextField)), 'qqqqqq');
      await pumpFrames(tester, count: 8);
      expect(find.text('No matches'), findsOneWidget);
    });
  });
}
