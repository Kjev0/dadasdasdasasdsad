# Desktop integration (`lib/platform/desktop`, `linux`, `windows`)

Window lifecycle, close-to-tray, tray menu, MPRIS (Linux), SMTC (Windows),
global hotkeys, desktop notifications, single instance and start-on-login.
User-facing behaviour per desktop environment: `docs/platform/DESKTOP.md`.

## Public API

| Class | Constructor / entry point | Implements |
|---|---|---|
| `DesktopIntegration` | `static Future<DesktopIntegration> start({required PlatformInfo platform, required PlaybackController playback, required SettingsStore settings, required AppPaths paths, required Future<void> Function() disposeAll, SingleInstance? singleInstance, List<String> args = const [], Future<void> Function(String path)? openFile, /* test overrides: */ DBusClient? sessionBus, WindowBackend? window, TrayBackend? trayBackend, String? trayAssetsRoot, HotkeyBackend? hotkeyBackend, Future<SmtcPort> Function()? smtcPortFactory, Map<String, String>? environment, void Function(int)? exitProcess})`; `factory DesktopIntegration.noop()` | — (fields `lifecycle`, `startup`, `hotkeys`, `notifier`, `mpris?`, `smtc?`) |
| `SingleInstance` | `static Future<SingleInstance> ensure(AppPaths paths, List<String> args)` (exits the process when another instance is running); `static Future<InstanceAcquisition> acquire(File lockFile, List<String> args, {Duration timeout})` | — (`Stream<String> commands`, `launchCommands`, `close()`) |
| `DesktopLifecycleController` | `({required PlaybackController playback, required SettingsStore settings, required AppPaths paths, required PlatformInfo platform, required Future<void> Function() disposeAll, required TrayController tray, WindowBackend? window, List<String> args, Stream<String>? instanceCommands, List<String> launchCommands, Future<void> Function(String)? openFile, void Function(int)? exitProcess, Duration quitStepTimeout, Duration exitGracePeriod, Duration boundsSaveDebounce, Duration startHiddenGrace})` | `AppLifecycleController` (+ `trayUnavailableReason`, `trayStatus`, `setMiniMode()`, `addShutdownHook()`, `handleCommand()`) |
| `TrayController` | `({required TrayBackend backend, required TrayAvailabilityProbe probe, required SettingsStore settings, required PlaybackController playback, required Future<String?> Function() resolveIconPath, AppLocalizations Function()? strings, Duration menuDebounce})` | — |
| `GlobalHotkeyServiceImpl` | `({required HotkeyBackend backend, required Map<String, Future<void> Function()> actions, required PlatformInfo platform, required AppLocalizations Function() strings, Map<String, String> environment})`; `bindToSettings(SettingsStore)` | `GlobalHotkeyService` (+ `unsupportedReason`) |
| `StartupManagerImpl` | `({required PlatformInfo platform, AutostartBackend? backend})` | `StartupManager` |
| `MprisServer` (linux) | `({required PlaybackController playback, required DBusClient client, onRaise, onQuit, onOpenFile, int? processId, Duration jumpThreshold, DateTime Function()? clock})` | — |
| `LinuxNotifier` (linux) | `({required DBusClient client, String appName, String appIcon, String desktopEntry})` + `init()` | `SystemNotifier` |
| `SmtcAdapter` (windows) | `({required PlaybackController playback, required PlatformInfo platform, Future<SmtcPort> Function()? portFactory, Duration timelineInterval, DateTime Function()? clock})` | — |
| `NoopLifecycleController`, `NoopStartupManager`, `NoopGlobalHotkeyService`, `NoopSystemNotifier` | `const ()` | the contracts (Android / unsupported) |

Helpers: `Accelerator.parse('ctrl+alt+space')`, `desktopLocalizations(localeCode)`,
`TrackChangeNotifier`, `LinuxAutostart`, `WindowsRunKeyAutostart`,
`StatusNotifierProbe`, `portalPrefersDark`, `fitWindowBounds`.

## Bootstrap wiring

```dart
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final platform = PlatformInfo.current();
  final paths = await AppPaths.resolve();
  // 1. Before anything heavy (DB, audio): a second launch forwards its
  //    command (show / --play-pause / --next / --previous / files) and exits.
  final instance = platform.isDesktop ? await SingleInstance.ensure(paths, args) : null;

  // ... logging, settings, http, library, sources, playback (restores queue) ...

  late final AppServices services;
  // 2. After the PlaybackController exists, before runApp.
  final desktop = await DesktopIntegration.start(   // returns no-ops on Android
    platform: platform,
    playback: playback,
    settings: settings,
    paths: paths,
    singleInstance: instance,
    args: args,
    disposeAll: () async { /* dispose downloads, database, http, ... */ },
  );
  services = AppServices(
    // ...
    lifecycle: desktop.lifecycle,
    startup: desktop.startup,
    hotkeys: desktop.hotkeys,
    notifier: platform.isAndroid ? androidNotifier : desktop.notifier,
    // ...
  );
  runApp(ProviderScope(overrides: serviceOverrides(services), child: const FermataApp()));
}
```

`start` calls `lifecycle.init()` (window setup, tray, start hidden) and
applies the hotkey settings. Quit order (`lifecycle.quit()`): flush window
bounds → `playback.dispose()` → `settings.flush()` → tray → hotkeys → MPRIS
→ SMTC → track notifications → single instance → session bus →
`disposeAll()` → `setPreventClose(false)` + `destroy()` → `exit(0)` after 3 s
if the process is still alive. Each step has a 4 s timeout.

UI hooks: register the "Close Fermata?" dialog with
`lifecycle.closeDecisionDelegate = () async => (choice, remember)`; Settings
reads `(lifecycle as DesktopLifecycleController).trayUnavailableReason`
and `(hotkeys as GlobalHotkeyServiceImpl).unsupportedReason`; the mini player
uses `setMiniMode(true/false)`. Strings for the close dialog exist as
`desktopCloseDialog*` in `desktop_*.arb`.

## Tests

```sh
source /opt/sdk/env.sh
flutter test test/platform/desktop test/platform/linux
```

`test/platform/linux/mpris_server_test.dart` and
`desktop_integration_linux_test.dart` start a private `dbus-daemon` (own
config, no activatable services) and drive the real MPRIS server with the
`dbus` client and `playerctl -p fermata status|metadata|play-pause|next|
previous|loop|shuffle|volume|position`. Manually against a running app:

```sh
playerctl -p fermata metadata
busctl --user introspect org.mpris.MediaPlayer2.fermata /org/mpris/MediaPlayer2
```

## Platform notes / limitations

* Code for Windows (SMTC, Run key) is guarded by `PlatformInfo.isWindows` /
  `Platform.isWindows` and was written against the package sources; it cannot
  be compiled for Windows in this container.
* The real tray (`NativeTrayBackend`, FFI into `libcnativeapi`) needs a GTK
  display and is therefore exercised by the app under Xvfb, not by
  `flutter test`; its logic is tested through `TrayController` with a fake.
* `window_manager` 0.5.2's Dart `focus()` invokes `isFocused`; the backend
  calls the native `focus` method directly.
* The stock runners show the window on the first frame. When starting
  hidden, a show/restore within 2.5 s re-applies the hidden state (a brief
  flash is possible); see gaps in DESKTOP.md.
* Hotkey plugins do not report OS-level conflicts; only invalid, unsafe,
  duplicate or failed registrations appear in `registrationErrors`.
