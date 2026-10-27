import 'dart:typed_data';

import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/track.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/l10n/gen/app_localizations_da.dart';
import 'package:fermata/l10n/gen/app_localizations_en.dart';
import 'package:fermata/settings/app_settings.dart';
import 'package:fermata/ui/widgets/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fakes.dart';

void main() {
  group('errorMessageFor', () {
    final l10n = AppLocalizationsEn();
    String? msg(Object e) => errorMessageFor(l10n, e, sourceName: (id) => id == 'soundcloud' ? 'SoundCloud' : id);

    test('maps every FermataException code', () {
      expect(msg(const NetworkException('x')), l10n.errorOffline);
      expect(msg(const NetworkException('x', isTimeout: true)), l10n.errorTimeout);
      expect(msg(const RateLimitedException('x')), l10n.errorRateLimited);
      expect(msg(const AuthRequiredException('soundcloud', 'x')), 'Reconnect your SoundCloud account to continue.');
      expect(msg(MissingCredentialsException('soundcloud', const ['clientId'])), 'SoundCloud needs developer credentials before it can be used.');
      expect(msg(const UnsupportedSourceOperation('soundcloud', 'download', 'x')), "SoundCloud doesn't support this.");
      expect(msg(const UnplayableTrackException('t', AvailabilityReason.private)), l10n.reasonPrivate);
      expect(msg(const DownloadNotPermittedException('t', AvailabilityReason.notAuthorized)), l10n.reasonNotAuthorized);
      expect(msg(const DownloadNotPermittedException('t', 'streamOnly')), l10n.shellErrorDownloadNotPermitted);
      expect(msg(const StorageException('disk_full', 'x')), l10n.shellErrorStorage);
      expect(msg(const ApiException(500, 'x')), l10n.errorGeneric);
      expect(msg(StateError('x')), l10n.errorGeneric);
      expect(msg(const OperationCanceledException()), isNull);
    });

    test('every availability reason has a localized text (EN + DA)', () {
      for (final l in [AppLocalizationsEn(), AppLocalizationsDa()]) {
        for (final r in [
          AvailabilityReason.deleted,
          AvailabilityReason.private,
          AvailabilityReason.regionRestricted,
          AvailabilityReason.subscriptionRequired,
          AvailabilityReason.notStreamable,
          AvailabilityReason.previewOnly,
          AvailabilityReason.externalOnly,
          AvailabilityReason.fileMissing,
          AvailabilityReason.notAuthorized,
          AvailabilityReason.credentialsMissing,
          AvailabilityReason.offline,
        ]) {
          expect(availabilityReasonText(l, r), isNot(availabilityReasonText(l, AvailabilityReason.unknown)), reason: r);
        }
      }
    });
  });

  group('ErrorState / EmptyState', () {
    testWidgets('ErrorState shows the mapped message and retries', (tester) async {
      var retried = 0;
      await pumpInApp(tester, ErrorState(error: const NetworkException('down'), onRetry: () => retried++));
      expect(find.text("You're offline. Check your connection and try again."), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 1);
    });

    testWidgets('EmptyState with actions', (tester) async {
      var tapped = false;
      await pumpInApp(tester, EmptyState(icon: Icons.music_note_rounded, title: 'Nothing here', message: 'Add music', actionLabel: 'Add', onAction: () => tapped = true));
      expect(find.text('Nothing here'), findsOneWidget);
      await tester.tap(find.text('Add'));
      expect(tapped, isTrue);
    });
  });

  group('badges', () {
    test('primary badge priority', () {
      expect(AvailabilityBadge.primaryKind(testTrack('a', playback: PlaybackRights.unavailable)), AvailabilityBadgeKind.unavailable);
      expect(AvailabilityBadge.primaryKind(testTrack('a', playback: PlaybackRights.externalOnly)), AvailabilityBadgeKind.external);
      expect(AvailabilityBadge.primaryKind(testTrack('a', playback: PlaybackRights.preview)), AvailabilityBadgeKind.preview);
      expect(AvailabilityBadge.primaryKind(testTrack('a'), downloaded: true), AvailabilityBadgeKind.downloaded);
      expect(AvailabilityBadge.primaryKind(testTrack('a', sourceId: SourceIds.local)), AvailabilityBadgeKind.userOwned);
      expect(AvailabilityBadge.primaryKind(testTrack('a', offline: OfflineRights.downloadable)), AvailabilityBadgeKind.downloadable);
      expect(AvailabilityBadge.primaryKind(testTrack('a')), AvailabilityBadgeKind.streamOnly);
      expect(AvailabilityBadge.primaryKind(testTrack('a', offline: OfflineRights.unavailable)), AvailabilityBadgeKind.unavailableOffline);
    });

    testWidgets('the four offline categories + preview + external render localized labels', (tester) async {
      await pumpInApp(
        tester,
        const Wrap(children: [
          AvailabilityBadge(kind: AvailabilityBadgeKind.userOwned),
          AvailabilityBadge(kind: AvailabilityBadgeKind.downloadable),
          AvailabilityBadge(kind: AvailabilityBadgeKind.streamOnly),
          AvailabilityBadge(kind: AvailabilityBadgeKind.unavailableOffline),
          AvailabilityBadge(kind: AvailabilityBadgeKind.preview),
          AvailabilityBadge(kind: AvailabilityBadgeKind.external, sourceId: SourceIds.youtube),
          SourceChip(sourceId: SourceIds.soundcloud),
          SourceChip(sourceId: SourceIds.local),
        ]),
      );
      for (final label in ['Your file', 'Downloadable', 'Stream only', 'Not available offline', 'Preview', 'Plays on YouTube Music', 'SoundCloud', 'Local file']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // Text chips only — never provider logos.
      expect(find.byType(Image), findsNothing);
    });
  });

  group('dialogs & sheets', () {
    testWidgets('ConfirmDialog with typed confirmation', (tester) async {
      await pumpInApp(tester, const SizedBox());
      final ctx = tester.element(find.byType(SizedBox).first);
      final result = ConfirmDialog.show(ctx, title: 'Delete all data?', confirmLabel: 'Delete', destructive: true, typedConfirmation: 'DELETE');
      await pumpFrames(tester);
      await tester.tap(find.text('Delete'));
      await pumpFrames(tester);
      expect(find.text('Delete all data?'), findsOneWidget, reason: 'disabled until typed');
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.text('Delete'));
      await pumpFrames(tester);
      expect(await result, isTrue);
    });

    testWidgets('TextInputDialog returns trimmed text and validates', (tester) async {
      await pumpInApp(tester, const SizedBox());
      final ctx = tester.element(find.byType(SizedBox).first);
      final result = TextInputDialog.show(ctx, title: 'Rename', confirmLabel: 'Save', validator: (v) => v == 'bad' ? 'Nope' : null);
      await pumpFrames(tester);
      await tester.enterText(find.byType(TextField), 'bad');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await pumpFrames(tester);
      expect(find.text('Nope'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Road trip  ');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await pumpFrames(tester);
      expect(await result, 'Road trip');
    });

    testWidgets('AddToPlaylistSheet creates a playlist and TrackActions adds the tracks', (tester) async {
      final tracks = testTracks(2);
      final kit = FakeKit(tracks: tracks);
      await pumpInApp(tester, Consumer(builder: (context, ref, _) {
        return TextButton(onPressed: () => TrackActions(context, ref).addToPlaylist(tracks), child: const Text('add'));
      }), kit: kit);
      await tester.tap(find.text('add'));
      await pumpFrames(tester);
      expect(find.text('Create your first playlist to add tracks to it.'), findsOneWidget);
      await tester.tap(find.text('New playlist'));
      await pumpFrames(tester);
      await tester.enterText(find.byType(TextField), 'Summer');
      await tester.pump();
      await tester.tap(find.text('Create'));
      await pumpFrames(tester);
      final playlist = (await kit.playlists.playlists()).single;
      expect(playlist.name, 'Summer');
      expect(kit.playlists.entries[playlist.id], [for (final t in tracks) t.id]);
      expect(kit.tracks.called('upsertTracks'), isTrue);
      expect(find.text('2 tracks added to Summer'), findsOneWidget);
    });

    testWidgets('TrackActions maps errors to toasts', (tester) async {
      final t = testTrack('e');
      final kit = FakeKit(tracks: [t]);
      kit.favorites.throwOn['setFavorite'] = const NetworkException('down');
      await pumpInApp(tester, Consumer(builder: (context, ref, _) {
        return TextButton(onPressed: () => TrackActions(context, ref).setFavorite(t, true), child: const Text('like'));
      }), kit: kit);
      await tester.tap(find.text('like'));
      await pumpFrames(tester);
      expect(find.text("You're offline. Check your connection and try again."), findsOneWidget);
    });

    testWidgets('downloadAll enqueues permitted tracks and reports the rest', (tester) async {
      final ok = testTrack('ok', offline: OfflineRights.downloadable);
      final sc = testTrack('sc', sourceId: SourceIds.soundcloud, offline: OfflineRights.downloadable);
      final stream = testTrack('st');
      final kit = FakeKit(tracks: [ok, sc, stream]);
      await pumpInApp(tester, Consumer(builder: (context, ref, _) {
        return TextButton(onPressed: () => TrackActions(context, ref).downloadAll([ok, sc, stream]), child: const Text('dl'));
      }), kit: kit);
      await tester.tap(find.text('dl'));
      await pumpFrames(tester);
      expect(kit.downloads.tasks.map((t) => t.trackId), [ok.id]);
      expect(find.text("1 download added · 2 tracks can't be downloaded"), findsOneWidget);
    });
  });

  group('controls', () {
    testWidgets('SearchField clear button', (tester) async {
      final changes = <String>[];
      await pumpInApp(tester, SearchField(onChanged: changes.add));
      await tester.enterText(find.byType(TextField), 'abba');
      await tester.pump();
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(changes.last, '');
    });

    testWidgets('SegmentedTabs', (tester) async {
      String? picked;
      await pumpInApp(tester, SegmentedTabs<String>(
        tabs: const [SegmentedTab('tracks', 'Tracks'), SegmentedTab('albums', 'Albums')],
        selected: 'tracks',
        onChanged: (v) => picked = v,
      ));
      await tester.tap(find.text('Albums'));
      expect(picked, 'albums');
    });

    testWidgets('FermataButton variants and busy state', (tester) async {
      var taps = 0;
      await pumpInApp(tester, Column(children: [
        FermataButton(label: 'Primary', onPressed: () => taps++),
        FermataButton(label: 'Busy', busy: true, onPressed: () => taps++),
        FermataButton(label: 'Ghost', variant: FermataButtonVariant.ghost, onPressed: () => taps++),
      ]));
      await tester.tap(find.text('Primary'));
      await tester.tap(find.text('Busy'));
      await tester.tap(find.text('Ghost'));
      expect(taps, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('MediaCard quick play and ShelfRow arrows', (tester) async {
      var played = 0;
      var opened = 0;
      await pumpInApp(tester, ShelfRow(
        title: 'Daily mixes',
        itemCount: 20,
        itemBuilder: (_, i) => MediaCard(title: 'Mix $i', subtitle: 'For you', onTap: () => opened++, onPlay: () => played++),
      ));
      expect(find.text('Daily mixes'), findsOneWidget);
      final left = find.byTooltip('Scroll left');
      final right = find.byTooltip('Scroll right');
      expect(tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.chevron_left_rounded), matching: find.byType(IconButton))).onPressed, isNull);
      await tester.tap(right);
      await pumpFrames(tester);
      expect(tester.widget<IconButton>(find.ancestor(of: find.byIcon(Icons.chevron_left_rounded), matching: find.byType(IconButton))).onPressed, isNotNull);
      expect(left, findsOneWidget);
      expect(find.text('Mix 0'), findsNothing);

      await tester.tap(find.text('Mix 8'));
      expect(opened, 1);
      // Hover reveals quick play on desktop.
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(find.text('Mix 8')));
      await gesture.moveTo(tester.getCenter(find.ancestor(of: find.text('Mix 8'), matching: find.byType(MediaCard))));
      await pumpFrames(tester);
      await tester.tap(find.descendant(of: find.ancestor(of: find.text('Mix 8'), matching: find.byType(MediaCard)), matching: find.byTooltip('Play')));
      expect(played, 1);
      await gesture.removePointer();
    });

    testWidgets('Skeleton shimmer only animates when animations are allowed', (tester) async {
      await pumpInApp(tester, const SkeletonTrackList(count: 3));
      expect(find.byType(ShaderMask), findsOneWidget);

      final still = FakeKit(settings: const AppSettings(performance: PerformanceSettings(animations: AnimationLevel.off)));
      await pumpInApp(tester, const SkeletonTrackList(count: 3), kit: still);
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(SkeletonTrackTile), findsNWidgets(3));
    });

    testWidgets('ArtworkImage shows the mark placeholder without artwork', (tester) async {
      await pumpInApp(tester, const ArtworkImage(uri: null, size: 64));
      expect(find.byType(ArtworkPlaceholder), findsOneWidget);
      expect(find.byType(FermataMark), findsOneWidget);
    });

    testWidgets('FermataLogo renders the mark (SVG asset or painted fallback) + wordmark', (tester) async {
      await pumpInApp(tester, const FermataLogo());
      await pumpFrames(tester);
      expect(find.text('Fermata'), findsOneWidget);
      // Works whether or not the branding asset is bundled.
      expect(find.descendant(of: find.byType(FermataLogo), matching: find.byType(SvgPicture)), findsOneWidget);
      expect(tester.getSize(find.byType(SvgPicture)).width, 28);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FermataMark paints without assets', (tester) async {
      await pumpInApp(tester, const FermataMark(size: 40));
      expect(tester.getSize(find.byType(FermataMark)), const Size(40, 40));
    });
  });

  group('ArtworkPalette', () {
    test('extracts dominant and vibrant colours from RGBA', () {
      // 3/4 dark grey, 1/4 saturated orange.
      final bytes = Uint8List(16 * 4);
      for (var i = 0; i < 16; i++) {
        final orange = i < 4;
        bytes.setAll(i * 4, orange ? [240, 120, 20, 255] : [40, 40, 44, 255]);
      }
      final p = ArtworkPalette.fromRgba(bytes)!;
      expect(p.dominant, const Color.fromARGB(255, 40, 40, 44));
      expect(p.vibrant, const Color.fromARGB(255, 240, 120, 20));
      expect(p.muted, const Color.fromARGB(255, 40, 40, 44));
    });

    test('transparent images have no palette', () {
      expect(ArtworkPalette.fromRgba(Uint8List(32)), isNull);
    });

    test('defaultArtworkResolver handles http, file and unsupported URIs', () {
      expect(defaultArtworkResolver(Uri.parse('https://x.invalid/a.jpg')), isA<NetworkImage>());
      expect(defaultArtworkResolver(Uri.parse('file:///music/cover.jpg')), isA<FileImage>());
      expect(defaultArtworkResolver(Uri.parse('/music/cover.jpg')), isA<FileImage>());
      expect(defaultArtworkResolver(Uri.parse('content://media/1')), isNull);
    });
  });

  group('routes', () {
    test('artist / album routes from tracks', () {
      expect(AppRoutes.artistForTrack(testTrack('a', artistId: 'x9')), '/artist/audius/x9');
      expect(AppRoutes.artistForTrack(testTrack('a', sourceId: SourceIds.local, artist: 'Nina Simone')), '/artist/local/Nina%20Simone');
      expect(AppRoutes.artistForTrack(testTrack('a')), isNull);
      expect(AppRoutes.albumForTrack(testTrack('a', extra: const {'albumId': '7'})), '/album/audius/7');
      expect(AppRoutes.albumForTrack(testTrack('a', sourceId: SourceIds.deezer, extra: const {'deezer.albumId': '302127'})), '/album/deezer/302127');
      expect(AppRoutes.albumForTrack(testTrack('a', sourceId: SourceIds.local, album: 'Blue')), '/album/local/Blue');
      expect(AppRoutes.library(tab: 'albums'), '/library?tab=albums');
      expect(AppRoutes.playlist('spotify:1 2'), '/playlists/spotify%3A1%202');
    });
  });
}
