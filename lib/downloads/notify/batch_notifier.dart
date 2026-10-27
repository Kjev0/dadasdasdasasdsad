import 'dart:io';

import 'package:logging/logging.dart';

import '../../core/contracts/platform.dart';
import '../../core/models/download.dart';
import '../../settings/settings_store.dart';

final _log = Logger('downloads.notify');

/// Notification texts. English and Danish are built in (chosen from
/// `localeCode` / the platform locale); bootstrap may pass its own
/// localized instance.
class DownloadNotificationStrings {
  const DownloadNotificationStrings({
    required this.completedTitle,
    required this.failedBody,
  });

  /// "12 tracks downloaded" / single-track variant.
  final String Function(int count, String? singleTitle) completedTitle;

  /// Body line when some tracks failed in the same batch.
  final String Function(int failed) failedBody;

  static final english = DownloadNotificationStrings(
    completedTitle: (n, title) => n == 1 ? 'Downloaded: ${title ?? '1 track'}' : '$n tracks downloaded',
    failedBody: (n) => n == 1 ? '1 download failed' : '$n downloads failed',
  );

  static final danish = DownloadNotificationStrings(
    completedTitle: (n, title) => n == 1 ? 'Downloadet: ${title ?? '1 nummer'}' : '$n numre downloadet',
    failedBody: (n) => n == 1 ? '1 download mislykkedes' : '$n downloads mislykkedes',
  );

  static DownloadNotificationStrings forLocale(String? localeCode) {
    final code = (localeCode ?? _platformLocale()).toLowerCase();
    return code.startsWith('da') ? danish : english;
  }

  static String _platformLocale() {
    try {
      return Platform.localeName;
    } catch (_) {
      return 'en';
    }
  }
}

/// Collects completions and shows ONE system notification per batch (when
/// the queue drains), honouring `downloads.notifyOnComplete` and
/// `notifications.downloads`.
class DownloadBatchNotifier {
  DownloadBatchNotifier({this._notifier, required this._settings, this._strings});

  static const notificationId = 'fermata.downloads.batch';

  final SystemNotifier? _notifier;
  final SettingsStore _settings;
  final DownloadNotificationStrings? _strings;

  int _completed = 0;
  int _failed = 0;
  String? _lastTitle;

  int get pendingCompleted => _completed;

  void recordCompleted(DownloadTask task) {
    _completed++;
    _lastTitle = task.track.title;
  }

  void recordFailed(DownloadTask task) => _failed++;

  /// Called when no task is queued/downloading/verifying any more.
  Future<void> onQueueDrained() async {
    final completed = _completed;
    final failed = _failed;
    final title = _lastTitle;
    _completed = 0;
    _failed = 0;
    _lastTitle = null;
    if (completed == 0) return;
    final notifier = _notifier;
    final s = _settings.current;
    if (notifier == null || !notifier.isSupported) return;
    if (!s.downloads.notifyOnComplete || !s.notifications.downloads) return;
    final strings = _strings ?? DownloadNotificationStrings.forLocale(s.localeCode);
    try {
      await notifier.show(
        id: notificationId,
        title: strings.completedTitle(completed, completed == 1 ? title : null),
        body: failed > 0 ? strings.failedBody(failed) : null,
      );
    } catch (e) {
      _log.fine('Download notification failed', e);
    }
  }
}
