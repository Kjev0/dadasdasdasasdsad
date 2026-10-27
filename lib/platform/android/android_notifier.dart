import 'package:logging/logging.dart';

import '../../core/contracts/platform.dart';

final _log = Logger('platform.android.notifier');

/// [SystemNotifier] for Android ("download finished" notifications).
///
/// Not supported in this build: [isSupported] is false, so the UI shows the
/// in-app message instead. Posting regular notifications on Android needs a
/// native component, and the only maintained Flutter option
/// (`flutter_local_notifications`) would require core-library desugaring in
/// `android/app/build.gradle.kts`, compiles a native C++/WinRT library into
/// the Windows build and adds a second Linux notification path next to the
/// desktop module's — too heavy for one optional notification. The playback
/// notification (media session) is unaffected; it is provided by
/// audio_service.
///
/// Planned channel when this is enabled: `app.fermata.player.downloads`,
/// small icon `drawable/ic_stat_fermata` (see
/// `docs/platform/ANDROID_BACKGROUND.md`, "Download notifications").
class AndroidNotifier implements SystemNotifier {
  const AndroidNotifier();

  /// Channel id reserved for download notifications.
  static const downloadsChannelId = 'app.fermata.player.downloads';

  @override
  bool get isSupported => false;

  /// No-op (see class docs); callers must check [isSupported] first.
  @override
  Future<void> show({required String id, required String title, String? body, String? iconPath}) async {
    _log.fine('System notifications are not supported on Android in this build; dropped "$id"');
  }
}
