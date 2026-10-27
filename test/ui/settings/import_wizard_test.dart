import 'package:fermata/app/providers.dart';
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/models/catalog.dart';
import 'package:fermata/core/models/matching.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/l10n/gen/app_localizations_en.dart';
import 'package:fermata/ui/pages/settings/settings_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';
import 'settings_harness.dart';

/// Records the options and tracks every import starts with.
class RecordingImports extends FakePlaylistImportService {
  MatchOptions? lastOptions;
  String? lastPlaylist;
  String? lastSource;
  List<Track>? lastTracks;
  String? lastName;

  @override
  Future<String> start({required String sourceId, required String playlistIdOrUrl, required MatchOptions options}) {
    lastOptions = options;
    lastPlaylist = playlistIdOrUrl;
    lastSource = sourceId;
    return super.start(sourceId: sourceId, playlistIdOrUrl: playlistIdOrUrl, options: options);
  }

  @override
  Future<String> startWithTracks({required String sourceId, required String name, required List<Track> tracks, required MatchOptions options}) {
    lastOptions = options;
    lastSource = sourceId;
    lastTracks = tracks;
    lastName = name;
    return super.startWithTracks(sourceId: sourceId, name: name, tracks: tracks, options: options);
  }
}

class _M3uLibrary extends FakeLocalLibraryService {
  _M3uLibrary(this.tracks);

  final List<Track> tracks;

  @override
  Future<List<Track>> importM3u(String path) async {
    record('importM3u');
    return tracks;
  }
}

String currentPath(WidgetTester tester) => appRouter(tester).routerDelegate.currentConfiguration.uri.path;

void main() {
  final l10n = AppLocalizationsEn();

  FakeMusicSource spotifyLike({bool connected = false}) => FakeMusicSource(
        id: SourceIds.spotify,
        displayName: 'Spotify',
        authState: SourceAuthState(
          status: connected ? SourceConnectionStatus.connected : SourceConnectionStatus.notConnected,
          accountName: connected ? 'Ada' : null,
        ),
        capabilities: const {
          SourceCapability.searchTracks,
          SourceCapability.externalPlayback,
          SourceCapability.oauth,
          SourceCapability.userLibrary,
          SourceCapability.playlistImport,
        },
        tracks: testTracks(3, sourceId: SourceIds.spotify),
        playlists: [
          const Playlist(id: 'spotify:pl1', name: 'Road Trip', kind: PlaylistKind.remote, sourceId: SourceIds.spotify, sourcePlaylistId: 'pl1', trackCount: 12),
        ],
      );

  List<FakeMusicSource> targets() => [
        FakeMusicSource(id: SourceIds.soundcloud, displayName: 'SoundCloud'),
        FakeMusicSource(id: SourceIds.audius, displayName: 'Audius'),
        FakeMusicSource(id: SourceIds.deezer, displayName: 'Deezer', capabilities: const {SourceCapability.searchTracks, SourceCapability.previewOnly}),
        FakeMusicSource(id: SourceIds.jamendo, displayName: 'Jamendo', ready: false),
      ];

  Future<(FakeKit, RecordingImports)> pumpImport(WidgetTester tester, List<MusicSource> sources, {FakeFileDialogs? dialogs, List<Track>? m3u}) async {
    final kit = FakeKit(sources: sources);
    final imports = RecordingImports();
    await pumpFermata(tester, kit: kit, initialRoute: '/import', overrides: [
      ...settingsOverrides(dialogs: dialogs),
      playlistImportProvider.overrideWithValue(imports),
      if (m3u != null) localLibraryProvider.overrideWithValue(_M3uLibrary(m3u)),
    ]);
    return (kit, imports);
  }

  testWidgets('paste a link → targets (SoundCloud first, external and unready excluded) → start → review page', (tester) async {
    final (_, imports) = await pumpImport(tester, [spotifyLike(), ...targets()]);
    expect(find.text(l10n.importChooseSource), findsOneWidget);
    // Not connected: link import still possible.
    expect(find.text(l10n.importSourceLinkOnly), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import.source.spotify')));
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('import.liked')), findsNothing, reason: 'library needs a connection');
    await tester.enterText(find.byKey(const ValueKey('import.link')), 'https://open.spotify.com/playlist/abc');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('import.link.continue')));
    await pumpFrames(tester);

    expect(find.text(l10n.importSummaryLink('Spotify')), findsOneWidget);
    expect(find.byKey(const ValueKey('import.target.soundcloud')), findsOneWidget);
    expect(find.byKey(const ValueKey('import.target.audius')), findsOneWidget);
    expect(find.byKey(const ValueKey('import.target.deezer')), findsNothing, reason: 'previews only when allowed');
    expect(find.byKey(const ValueKey('import.target.spotify')), findsNothing, reason: 'origin / external-only');
    expect(find.byKey(const ValueKey('import.target.jamendo')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('import.target.jamendo')), matching: find.text(l10n.importTargetNotReady)), findsOneWidget);

    // Allowing previews adds Deezer.
    await tapVisible(tester, find.byKey(const ValueKey('import.allowPreview')));
    expect(find.byKey(const ValueKey('import.target.deezer')), findsOneWidget);

    await tapVisible(tester, find.byKey(const ValueKey('import.start')));
    expect(imports.lastSource, SourceIds.spotify);
    expect(imports.lastPlaylist, 'https://open.spotify.com/playlist/abc');
    expect(imports.lastOptions!.targetSources, [SourceIds.soundcloud, SourceIds.audius, SourceIds.deezer]);
    expect(imports.lastOptions!.allowPreviewOnly, isTrue);
    expect(imports.lastOptions!.reviewMode, ReviewMode.autoAcceptHigh);
    expect(imports.lastOptions!.autoAcceptThreshold, 0.88);
    expect(currentPath(tester), '/import/s1');
    expect(find.text(l10n.importReviewTitle), findsOneWidget);
  });

  testWidgets('targets can be unchecked and reordered; review mode and options are passed on', (tester) async {
    final (_, imports) = await pumpImport(tester, [spotifyLike(), ...targets()]);
    await tester.tap(find.byKey(const ValueKey('import.source.spotify')));
    await pumpFrames(tester);
    await tester.enterText(find.byKey(const ValueKey('import.link')), 'pl1');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('import.link.continue')));
    await pumpFrames(tester);
    // Move Audius above SoundCloud, then uncheck SoundCloud.
    await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('import.target.audius')), matching: find.byTooltip(l10n.settingsMoveUp)));
    await tapVisible(tester, find.descendant(of: find.byKey(const ValueKey('import.target.soundcloud')), matching: find.byType(Checkbox)));
    final dropdown = find.descendant(of: find.byKey(const ValueKey('import.reviewMode')), matching: find.byType(DropdownButton<ReviewMode>));
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await pumpFrames(tester, count: 3);
    await tester.tap(find.text(l10n.settingsReviewAll).last);
    await pumpFrames(tester, count: 3);
    await tapVisible(tester, find.byKey(const ValueKey('import.start')));
    expect(imports.lastOptions!.targetSources, [SourceIds.audius]);
    expect(imports.lastOptions!.reviewMode, ReviewMode.reviewAll);
  });

  testWidgets('connected library: pick one of your playlists', (tester) async {
    final (_, imports) = await pumpImport(tester, [spotifyLike(connected: true), ...targets()]);
    expect(find.text(l10n.importSourceSignedIn('Ada')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import.source.spotify')));
    await pumpFrames(tester);
    expect(find.text('Road Trip'), findsOneWidget);
    expect(find.text(l10n.importTrackCount(12)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import.playlist.spotify:pl1')));
    await pumpFrames(tester);
    expect(find.text(l10n.importSummaryPlaylist('Road Trip', 'Spotify')), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('import.start')));
    expect(imports.lastPlaylist, 'pl1');
  });

  testWidgets('connected library: liked tracks are fetched and imported as a list', (tester) async {
    final (_, imports) = await pumpImport(tester, [spotifyLike(connected: true), ...targets()]);
    await tester.tap(find.byKey(const ValueKey('import.source.spotify')));
    await pumpFrames(tester);
    await tester.tap(find.byKey(const ValueKey('import.liked')));
    await pumpFrames(tester);
    await tapVisible(tester, find.byKey(const ValueKey('import.start')));
    expect(imports.calls, contains('startWithTracks'));
    expect(imports.lastTracks, hasLength(3));
    expect(imports.lastName, l10n.importLikedName('Spotify'));
    expect(currentPath(tester), '/import/s1');
  });

  testWidgets('M3U file: tracks are read by the local library and matched', (tester) async {
    final dialogs = FakeFileDialogs()
      ..file = PickedFile(name: 'Summer.m3u8', path: '/home/u/Summer.m3u8', read: () async => throw UnimplementedError());
    final (_, imports) = await pumpImport(tester, targets(), dialogs: dialogs, m3u: testTracks(2, sourceId: SourceIds.local));
    await tester.tap(find.byKey(const ValueKey('import.source.m3u')));
    await pumpFrames(tester);
    expect(find.text(l10n.importSummaryM3u('Summer', 2)), findsOneWidget);
    await tapVisible(tester, find.byKey(const ValueKey('import.start')));
    expect(imports.lastSource, SourceIds.local);
    expect(imports.lastName, 'Summer');
    expect(imports.lastTracks, hasLength(2));
  });

  testWidgets('sources without credentials point to Connected services; no ready target disables Start', (tester) async {
    final unconfigured = FakeMusicSource(
      id: SourceIds.soundcloud,
      displayName: 'SoundCloud',
      credentialStatus: const CredentialStatus(configured: false, origin: CredentialOrigin.none, missing: ['clientId']),
      capabilities: const {SourceCapability.searchTracks, SourceCapability.stream, SourceCapability.oauth, SourceCapability.playlistImport},
    );
    await pumpImport(tester, [unconfigured, spotifyLike(), FakeMusicSource(id: SourceIds.audius, displayName: 'Audius', ready: false)]);
    expect(find.text(l10n.importSourceNotSetUp('SoundCloud')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('import.source.soundcloud')));
    await pumpFrames(tester);
    expect(find.text(l10n.importChooseSource), findsOneWidget, reason: 'not selectable');

    await tester.tap(find.byKey(const ValueKey('import.source.spotify')));
    await pumpFrames(tester);
    await tester.enterText(find.byKey(const ValueKey('import.link')), 'pl1');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('import.link.continue')));
    await pumpFrames(tester);
    final start = find.descendant(of: find.byKey(const ValueKey('import.start')), matching: find.byType(FilledButton));
    expect(tester.widget<FilledButton>(start).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('import.back')));
    await pumpFrames(tester);
    expect(find.byKey(const ValueKey('import.link')), findsOneWidget);
  });

  testWidgets('Settings → "Import a playlist" opens the wizard', (tester) async {
    await pumpFermata(tester, initialRoute: '/settings/import', overrides: settingsOverrides(hooks: const SettingsHooks()));
    await tapVisible(tester, find.byKey(const ValueKey('settings.importPlaylist')));
    expect(currentPath(tester), '/import');
  });
}
