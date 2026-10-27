import 'dart:async';

import 'package:logging/logging.dart';

import '../../core/contracts/platform.dart';
import '../../core/contracts/playback.dart';
import '../../core/models/playback.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../settings/settings_store.dart';
import '../linux/linux_notifier.dart';

final _log = Logger('desktop.notify');

/// Shows a "now playing" notification when a new track starts and
/// `notifications.trackChange` is on (desktop only). Each notification
/// replaces the previous one.
class TrackChangeNotifier {
  TrackChangeNotifier({
    required this._playback,
    required this._settings,
    required this._notifier,
    required this._strings,
  });

  static const notificationId = 'track-change';

  final PlaybackController _playback;
  final SettingsStore _settings;
  final SystemNotifier _notifier;
  final AppLocalizations Function() _strings;
  StreamSubscription<PlaybackEvent>? _sub;
  String? _lastUid;

  void start() {
    _sub ??= _playback.events.listen((e) {
      if (e is TrackStarted) unawaited(_onTrackStarted(e.item));
    });
  }

  Future<void> _onTrackStarted(QueueItem item) async {
    if (!_settings.current.notifications.trackChange || !_notifier.isSupported) return;
    if (item.uid == _lastUid) return; // e.g. restart of the same entry
    _lastUid = item.uid;
    final track = item.track;
    final artist = track.artistLine.isEmpty ? _strings().desktopUnknownArtist : track.artistLine;
    final body = track.album == null || track.album!.isEmpty ? artist : '$artist — ${track.album}';
    final art = track.artworkUrl;
    final iconPath = art != null && art.scheme == 'file' ? art.toFilePath() : null;
    try {
      final n = _notifier;
      if (n is LinuxNotifier) {
        await n.notify(id: notificationId, title: track.title, body: body, iconPath: iconPath, transient: true, urgency: 0);
      } else {
        await n.show(id: notificationId, title: track.title, body: body, iconPath: iconPath);
      }
    } catch (e) {
      _log.fine('Track notification failed: $e');
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
