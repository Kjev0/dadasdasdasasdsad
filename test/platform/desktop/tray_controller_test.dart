import 'package:fermata/platform/desktop/tray/tray_availability.dart';
import 'package:fermata/platform/desktop/tray/tray_controller.dart';
import 'package:fermata/platform/desktop/tray/tray_menu.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeTrayBackend backend;
  late FakeTrayProbe probe;
  late SettingsStore settings;
  late FakePlaybackController playback;
  late TrayController tray;
  String? iconPath;

  setUp(() {
    backend = FakeTrayBackend();
    probe = FakeTrayProbe();
    settings = SettingsStore.inMemory();
    playback = FakePlaybackController();
    iconPath = '/app/data/flutter_assets/assets/branding/tray_icon.png';
    tray = TrayController(
      backend: backend,
      probe: probe,
      settings: settings,
      playback: playback,
      resolveIconPath: () async => iconPath,
      menuDebounce: const Duration(milliseconds: 20),
    );
  });

  tearDown(() => tray.dispose());

  Future<void> debounce() async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    await tray.idle;
  }

  List<String> labels() => [for (final e in backend.menu) e.separator ? '---' : e.label];

  test('creates the icon with the "Not playing" menu', () async {
    await tray.start();
    expect(tray.isActive, isTrue);
    expect(tray.status, TrayStatus.active);
    expect(tray.unavailableReason, isNull);
    expect(backend.iconPath, iconPath);
    expect(labels(), ['Not playing', '---', 'Play', 'Previous', 'Next', '---', 'Show Fermata', 'Quit Fermata']);
    expect(backend.entry(TrayMenuIds.nowPlaying).enabled, isFalse);
    expect(backend.entry(TrayMenuIds.playPause).enabled, isFalse);
    expect(backend.entry(TrayMenuIds.show).enabled, isTrue);
    expect(backend.tooltip, 'Fermata');
  });

  test('shows the current track and reflects play/pause (debounced, no rebuild on ticks)', () async {
    await tray.start();
    playback.load([track('1', title: 'So What', artist: 'Miles Davis')]);
    await eventually(() => expect(labels().first, 'So What — Miles Davis'));
    expect(backend.entry(TrayMenuIds.playPause).label, 'Play');
    expect(backend.tooltip, 'Fermata — So What · Miles Davis');

    await playback.play();
    await eventually(() => expect(backend.entry(TrayMenuIds.playPause).label, 'Pause'));
    await tray.idle;

    final updates = backend.menuUpdates;
    for (var i = 1; i <= 10; i++) {
      playback.emit(playback.snapshot.copyWith(position: Duration(milliseconds: 250 * i)));
    }
    await debounce();
    expect(backend.menuUpdates, updates, reason: 'position ticks must not rebuild the menu');

    // A burst of changes collapses into one rebuild.
    await playback.pause();
    await playback.play();
    await playback.pause();
    await eventually(() => expect(backend.entry(TrayMenuIds.playPause).label, 'Play'));
    await debounce();
    expect(backend.menuUpdates, updates + 1);
  });

  test('labels follow the app language', () async {
    await settings.update((s) => s.copyWith(localeCode: 'da'));
    await tray.start();
    expect(labels(), ['Der afspilles intet', '---', 'Afspil', 'Forrige', 'Næste', '---', 'Vis Fermata', 'Afslut Fermata']);
    await settings.update((s) => s.copyWith(localeCode: 'en'));
    await eventually(() => expect(labels().last, 'Quit Fermata'));
  });

  test('menu clicks control playback and the window', () async {
    var shows = 0;
    var quits = 0;
    tray.onShowWindow = () async => shows++;
    tray.onQuit = () async => quits++;
    await tray.start();
    playback.load([track('1'), track('2')]);

    backend.onMenuItem!(TrayMenuIds.playPause);
    backend.onMenuItem!(TrayMenuIds.next);
    backend.onMenuItem!(TrayMenuIds.previous);
    backend.onMenuItem!(TrayMenuIds.show);
    backend.onActivate!(); // left click on Windows
    backend.onMenuItem!(TrayMenuIds.quit);
    await settle();
    expect(playback.calls, ['togglePlayPause', 'next', 'previous']);
    expect(shows, 2);
    expect(quits, 1);
  });

  test('desktop.showTrayIcon toggles the icon live', () async {
    final changes = <bool>[];
    tray.activeChanges.listen(changes.add);
    await tray.start();
    await settings.update((s) => s.copyWith(desktop: s.desktop.copyWith(showTrayIcon: false)));
    await tray.idle;
    expect(tray.isActive, isFalse);
    expect(backend.created, isFalse);
    expect(tray.status, TrayStatus.disabledBySetting);
    expect(tray.unavailableReason, contains('turned off'));

    await settings.update((s) => s.copyWith(desktop: s.desktop.copyWith(showTrayIcon: true)));
    await tray.idle;
    expect(tray.isActive, isTrue);
    expect(backend.created, isTrue);
    expect(labels(), isNotEmpty);
    expect(changes, [true, false, true]);
  });

  test('no StatusNotifier host: no icon and an explanation (GNOME)', () async {
    probe.state = TrayHostState.gnomeWithoutAppIndicator;
    await tray.start();
    expect(tray.isActive, isFalse);
    expect(backend.createCount, 0);
    expect(tray.status, TrayStatus.gnomeWithoutAppIndicator);
    expect(tray.unavailableReason, contains('AppIndicator'));
  });

  test('host appearing later (extension enabled) creates the icon; restarts re-register', () async {
    probe.state = TrayHostState.noHost;
    await tray.start();
    expect(tray.status, TrayStatus.noStatusNotifierHost);

    probe.state = TrayHostState.available;
    probe.hostChanged();
    await tray.idle;
    expect(tray.isActive, isTrue);
    expect(backend.createCount, 1);

    probe.hostChanged(); // panel restarted
    await tray.idle;
    expect(backend.createCount, 2);
    expect(tray.isActive, isTrue);

    probe.state = TrayHostState.noHost;
    probe.hostChanged();
    await tray.idle;
    expect(tray.isActive, isFalse);
  });

  test('missing icon file or refusing platform → tray skipped with a reason', () async {
    iconPath = null;
    await tray.start();
    expect(tray.isActive, isFalse);
    expect(tray.status, TrayStatus.iconMissing);
    expect(tray.unavailableReason, contains('missing'));
    expect(backend.createCount, 0);
  });

  test('platform refusing the icon → failed', () async {
    backend.createResult = false;
    await tray.start();
    expect(tray.status, TrayStatus.failed);
    expect(tray.isActive, isFalse);
  });

  test('every status has a localized reason except active', () {
    final l10n = desktopTestStrings();
    for (final s in TrayStatus.values) {
      final reason = TrayController.reasonText(s, l10n);
      if (s == TrayStatus.active || s == TrayStatus.pending) {
        expect(reason, isNull);
      } else {
        expect(reason, isNotEmpty, reason: '$s');
      }
    }
  });

  test('dispose removes the icon', () async {
    await tray.start();
    await tray.dispose();
    expect(backend.created, isFalse);
    expect(tray.isActive, isFalse);
  });

  test('menu model: titles without artist, long titles are shortened', () {
    final l10n = desktopTestStrings();
    const noArtist = TrayMenuState(title: 'Untitled', artist: '');
    expect(noArtist.entries(l10n).first.label, 'Untitled');
    expect(noArtist.tooltip(l10n), 'Fermata — Untitled');
    final long = TrayMenuState(title: 'x' * 200, artist: 'y');
    expect(long.entries(l10n).first.label.length, lessThanOrEqualTo(60));
  });
}
