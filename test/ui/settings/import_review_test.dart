import 'dart:async';

import 'package:fermata/app/providers.dart';
import 'package:fermata/core/contracts/matching.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/matching.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/l10n/gen/app_localizations_en.dart';
import 'package:fermata/ui/pages/import/import_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'settings_harness.dart';

MatchCandidate cand(Track t, double score, MatchConfidence c, {Set<MatchDifference> diffs = const {}, Duration? delta}) =>
    MatchCandidate(candidate: t, score: score, confidence: c, differences: diffs, durationDelta: delta);

/// A service whose sessions are driven by the test (for the progress view).
class ScriptedImports implements PlaylistImportService {
  final _ctl = StreamController<ImportSessionState>.broadcast();
  ImportSessionState? state;
  final calls = <String>[];

  void emit(ImportSessionState s) {
    state = s;
    _ctl.add(s);
  }

  @override
  ImportSessionState? current(String sessionId) => state;

  @override
  Stream<ImportSessionState> watch(String sessionId) => _ctl.stream;

  @override
  void cancel(String sessionId) => calls.add('cancel');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  final l10n = AppLocalizationsEn();

  final o1 = testTrack('o1', sourceId: SourceIds.spotify, title: 'Blue', artist: 'Kai');
  final o2 = testTrack('o2', sourceId: SourceIds.spotify, title: 'Red', artist: 'Lu');
  final o3 = testTrack('o3', sourceId: SourceIds.spotify, title: 'Green', artist: 'Mo');
  final o4 = testTrack('o4', sourceId: SourceIds.spotify, title: 'Grey', artist: 'Ny');
  final o5 = testTrack('o5', sourceId: SourceIds.spotify, title: 'Gold', artist: 'Ola');

  final m1 = testTrack('m1', sourceId: SourceIds.soundcloud, title: 'Blue', artist: 'Kai');
  final m2remix = testTrack('m2r', sourceId: SourceIds.soundcloud, title: 'Red (Club Remix)', artist: 'Lu');
  final m2low = testTrack('m2l', sourceId: SourceIds.audius, title: 'Red', artist: 'Lu Cover Band');
  final m3live = testTrack('m3', sourceId: SourceIds.audius, title: 'Green (Live)', artist: 'Mo');
  final m5 = testTrack('m5', sourceId: SourceIds.soundcloud, title: 'Gold', artist: 'Ola');
  final alt = testTrack('alt', sourceId: SourceIds.audius, title: 'Grey', artist: 'Ny');

  late MatchCandidate c5;

  List<TrackMatchResult> results() {
    c5 = cand(m5, 0.97, MatchConfidence.exact);
    return [
      TrackMatchResult(original: o1, candidates: [cand(m1, 0.91, MatchConfidence.high, delta: const Duration(seconds: 2))], decision: MatchDecision.needsReview),
      TrackMatchResult(
        original: o2,
        candidates: [
          cand(m2remix, 0.9, MatchConfidence.high, diffs: {MatchDifference.remix}),
          cand(m2low, 0.55, MatchConfidence.low, diffs: {MatchDifference.artistMismatch}),
        ],
        decision: MatchDecision.needsReview,
      ),
      TrackMatchResult(original: o3, candidates: [cand(m3live, 0.88, MatchConfidence.high, diffs: {MatchDifference.live})], decision: MatchDecision.needsReview),
      TrackMatchResult(original: o4, candidates: const [], decision: MatchDecision.notFound),
      TrackMatchResult(original: o5, candidates: [c5], decision: MatchDecision.autoAccepted, chosen: c5),
    ];
  }

  Future<FakeKit> pumpReview(WidgetTester tester, {Size size = TestSizes.expanded}) async {
    final kit = FakeKit();
    kit.imports.presetResults['pl'] = results();
    final id = await kit.imports.start(sourceId: SourceIds.spotify, playlistIdOrUrl: 'pl', options: const MatchOptions());
    expect(id, 's1');
    await pumpFermata(tester, kit: kit, initialRoute: '/import/s1', size: size, overrides: settingsOverrides());
    return kit;
  }

  String decisionOf(WidgetTester tester, Track original) =>
      tester.widget<Text>(find.byKey(ValueKey('import.row.${original.id}.decision'))).data!;

  Finder rowButton(Track original, String action) =>
      find.descendant(of: find.byKey(ValueKey('import.row.${original.id}.$action')), matching: find.byType(FilledButton));

  Future<void> scrollToRow(WidgetTester tester, Track original) async {
    await tester.scrollUntilVisible(
      find.byKey(ValueKey('import.row.${original.id}')),
      200,
      scrollable: find.descendant(of: find.byKey(const ValueKey('import.reviewList')), matching: find.byType(Scrollable)).first,
    );
    await tester.pump();
  }

  testWidgets('summary chips, confidence, duration difference and version chips are shown', (tester) async {
    await pumpReview(tester);
    expect(find.text(l10n.importReviewTitle), findsOneWidget);
    expect(find.text('${l10n.importDecisionReview} · 3'), findsOneWidget);
    expect(find.text('${l10n.importDecisionAuto} · 1'), findsOneWidget);
    expect(find.text('${l10n.importDecisionNotFound} · 1'), findsOneWidget);
    expect(find.text('${l10n.importDecisionSkipped} · 0'), findsOneWidget);
    expect(find.text('${l10n.importConfidenceHigh} · 91 %'), findsOneWidget);
    expect(find.text('+2 s'), findsOneWidget);
    // Row 2 proposes the safe low candidate, never the remix.
    expect(find.descendant(of: find.byKey(ValueKey('import.row.${o2.id}')), matching: find.text('Red (Club Remix)')), findsNothing);
    expect(find.descendant(of: find.byKey(ValueKey('import.row.${o2.id}')), matching: find.text(l10n.importDiffArtist)), findsOneWidget);
    // Row 3 only has a live version: nothing is proposed.
    expect(find.descendant(of: find.byKey(ValueKey('import.row.${o3.id}')), matching: find.text(l10n.importOnlyOtherVersions)), findsOneWidget);
    expect(tester.widget<FilledButton>(rowButton(o3, 'accept')).onPressed, isNull);
  });

  testWidgets('matched tracks link back to the provider (attribution)', (tester) async {
    final kit = await pumpReview(tester);
    final link = find.descendant(of: find.byKey(ValueKey('import.row.${o1.id}')), matching: find.text(l10n.importOpenOn('SoundCloud')));
    await tapVisible(tester, link);
    expect(kit.openedLinks.single, m1.permalink);
  });

  testWidgets('accept, reject and skip update the decisions', (tester) async {
    final kit = await pumpReview(tester);
    await tapVisible(tester, rowButton(o1, 'accept'));
    expect(decisionOf(tester, o1), l10n.importDecisionAccepted);
    await scrollToRow(tester, o2);
    await tapVisible(tester, rowButton(o2, 'reject'));
    expect(decisionOf(tester, o2), l10n.importDecisionRejected);
    await scrollToRow(tester, o4);
    await tapVisible(tester, rowButton(o4, 'skip'));
    expect(decisionOf(tester, o4), l10n.importDecisionSkipped);
    expect(kit.imports.calls, containsAllInOrder(['accept', 'reject', 'skip']));
    expect(kit.imports.current('s1')!.results.first.chosen!.candidate, m1);
  });

  testWidgets('choosing another candidate is an explicit choice (even a different version)', (tester) async {
    final kit = await pumpReview(tester);
    await scrollToRow(tester, o3);
    await tapVisible(tester, rowButton(o3, 'candidates'));
    expect(find.text(l10n.importDifferentVersionWarning), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(ValueKey('import.candidate.${m3live.id}.use')), matching: find.byType(FilledButton)));
    await pumpFrames(tester);
    final r3 = kit.imports.current('s1')!.results[2];
    expect(r3.decision, MatchDecision.userAccepted);
    expect(r3.chosen!.candidate, m3live);
  });

  testWidgets('"accept all high-confidence" skips different versions', (tester) async {
    final kit = await pumpReview(tester);
    expect(find.text(l10n.importAcceptAllHigh(1)), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('import.acceptAll')));
    final rs = kit.imports.current('s1')!.results;
    expect(rs[0].decision, MatchDecision.userAccepted);
    expect(rs[1].decision, MatchDecision.needsReview, reason: 'best is a remix');
    expect(rs[2].decision, MatchDecision.needsReview, reason: 'best is live');
  });

  testWidgets('filtering by decision', (tester) async {
    await pumpReview(tester);
    await tester.tap(find.byKey(const ValueKey('import.filter.notFound')));
    await pumpFrames(tester);
    expect(find.byKey(ValueKey('import.row.${o4.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('import.row.${o1.id}')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('import.filter.skipped')));
    await pumpFrames(tester);
    expect(find.text(l10n.importFilterEmpty), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import.filter.all')));
    await pumpFrames(tester);
    expect(find.byKey(ValueKey('import.row.${o1.id}')), findsOneWidget);
  });

  testWidgets('manual search finds alternatives and accepts one', (tester) async {
    final kit = await pumpReview(tester);
    kit.imports.alternatives = [cand(alt, 0.8, MatchConfidence.medium)];
    await scrollToRow(tester, o4);
    await tapVisible(tester, rowButton(o4, 'search'));
    final field = find.byKey(const ValueKey('import.manualSearch.query'));
    expect(tester.widget<TextField>(field).controller!.text, 'Ny Grey');
    await tester.enterText(field, 'ny grey remaster');
    await tester.tap(find.byKey(const ValueKey('import.manualSearch.go')));
    await pumpFrames(tester);
    expect(kit.imports.calls, contains('searchAlternatives'));
    await tester.tap(find.descendant(of: find.byKey(ValueKey('import.candidate.${alt.id}.use')), matching: find.byType(FilledButton)));
    await pumpFrames(tester);
    expect(kit.imports.current('s1')!.results[3].decision, MatchDecision.userAccepted);
  });

  testWidgets('save → name → copyable missing-tracks report → navigates to the playlist', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final kit = await pumpReview(tester);
    await tapVisible(tester, find.byKey(const ValueKey('import.save')));
    // 3 rows still need review.
    expect(find.text(l10n.importSavePendingBody(3)), findsOneWidget);
    await tester.tap(find.text(l10n.importSaveAnyway));
    await pumpFrames(tester);
    expect(find.text(l10n.importSaveTitle), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'My Mix');
    await tester.tap(find.widgetWithText(FilledButton, l10n.actionSave));
    await pumpFrames(tester);
    expect(kit.imports.calls, contains('save'));
    final report = tester.widget<SelectableText>(find.byKey(const ValueKey('import.report'))).data!;
    expect(report, contains('Ny — Grey'));
    expect(report, isNot(contains('Ola — Gold')));
    await tester.tap(find.byKey(const ValueKey('import.report.copy')));
    await pumpFrames(tester, count: 3);
    expect(calls.where((c) => c.method == 'Clipboard.setData'), isNotEmpty);
    await tester.tap(find.widgetWithText(FilledButton, l10n.actionDone));
    await pumpFrames(tester);
    expect(appRouter(tester).routerDelegate.currentConfiguration.uri.path, '/playlists/imported-s1');
  });

  testWidgets('live progress while matching, with cancel', (tester) async {
    final svc = ScriptedImports();
    final kit = FakeKit();
    svc.emit(const ImportSessionState(id: 'x', phase: ImportPhase.fetching, source: SourceIds.spotify, results: [], total: 0, processed: 0));
    await pumpFermata(tester, kit: kit, initialRoute: '/import/x', overrides: [...settingsOverrides(), playlistImportProvider.overrideWithValue(svc)]);
    expect(find.text(l10n.importPhaseFetching), findsOneWidget);
    svc.emit(ImportSessionState(
      id: 'x',
      phase: ImportPhase.matching,
      source: SourceIds.spotify,
      playlist: const Playlist(id: 'p', name: 'Road Trip', kind: PlaylistKind.remote),
      results: [TrackMatchResult(original: o4, candidates: const [], decision: MatchDecision.notFound)],
      total: 10,
      processed: 4,
    ));
    await pumpFrames(tester);
    expect(find.text(l10n.importPhaseMatching(4, 10)), findsOneWidget);
    expect(find.text('Road Trip'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('import.progress'))).value, closeTo(0.4, 0.001));
    await tester.tap(find.byKey(const ValueKey('import.cancel')));
    await pumpFrames(tester);
    expect(svc.calls, ['cancel']);
    svc.emit(const ImportSessionState(id: 'x', phase: ImportPhase.canceled, source: SourceIds.spotify, results: [], total: 10, processed: 4));
    await pumpFrames(tester);
    expect(find.text(l10n.importCanceled), findsOneWidget);
  });

  testWidgets('an unknown session explains and offers a new import', (tester) async {
    await pumpFermata(tester, initialRoute: '/import/gone', overrides: settingsOverrides());
    expect(find.text(l10n.importSessionMissing), findsOneWidget);
    await tester.tap(find.text(l10n.importStartNew));
    await pumpFrames(tester);
    expect(appRouter(tester).routerDelegate.currentConfiguration.uri.path, '/import');
  });

  testWidgets('review works at phone width', (tester) async {
    await pumpReview(tester, size: TestSizes.compact);
    expect(tester.takeException(), isNull);
    await scrollToRow(tester, o1);
    expect(find.byKey(ValueKey('import.row.${o1.id}')), findsOneWidget);
    await scrollToRow(tester, o5);
    expect(tester.takeException(), isNull);
  });

  test('helpers: duration delta, proposed candidate, report', () {
    expect(durationDeltaLabel(const Duration(seconds: 3)), '+3 s');
    expect(durationDeltaLabel(const Duration(seconds: -12)), '−12 s');
    expect(durationDeltaLabel(const Duration(milliseconds: 300)), '±0 s');
    final rs = results();
    expect(proposedCandidate(rs[1])!.candidate, m2low);
    expect(proposedCandidate(rs[2]), isNull);
    expect(proposedCandidate(rs[4]), same(c5));
    final state = ImportSessionState(id: 's', phase: ImportPhase.reviewing, source: 'spotify', results: rs, total: 5, processed: 5);
    expect(unmatchedResults(state), hasLength(4));
    expect(missingTracksReport(l10n, state).split('\n').first, l10n.importReportHeader(l10n.importUntitled, 4));
  });
}
