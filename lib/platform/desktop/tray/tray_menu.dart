import 'package:flutter/foundation.dart';

import '../../../core/models/playback.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Stable ids of the tray menu entries.
abstract final class TrayMenuIds {
  static const nowPlaying = 'nowPlaying';
  static const playPause = 'playPause';
  static const previous = 'previous';
  static const next = 'next';
  static const show = 'show';
  static const quit = 'quit';
}

/// One entry of the tray context menu (platform independent).
@immutable
class TrayMenuEntry {
  const TrayMenuEntry.item(this.id, this.label, {this.enabled = true}) : separator = false;

  const TrayMenuEntry.separator()
      : id = '',
        label = '',
        enabled = false,
        separator = true;

  final String id;
  final String label;
  final bool enabled;
  final bool separator;

  @override
  bool operator ==(Object other) =>
      other is TrayMenuEntry &&
      other.id == id &&
      other.label == label &&
      other.enabled == enabled &&
      other.separator == separator;

  @override
  int get hashCode => Object.hash(id, label, enabled, separator);

  @override
  String toString() => separator ? '----' : '$id("$label"${enabled ? '' : ', disabled'})';
}

/// The parts of the playback state the tray shows. The menu is only rebuilt
/// when this changes (never for position ticks).
@immutable
class TrayMenuState {
  const TrayMenuState({this.title, this.artist, this.playing = false, this.localeName = 'en'});

  factory TrayMenuState.fromSnapshot(PlaybackSnapshot snapshot, {required String localeName}) {
    final track = snapshot.track;
    return TrayMenuState(
      title: track?.title,
      artist: track == null ? null : track.artistLine,
      playing: snapshot.playing,
      localeName: localeName,
    );
  }

  final String? title;
  final String? artist;
  final bool playing;
  final String localeName;

  bool get hasTrack => title != null;

  /// "Fermata — Title · Artist" (or just "Fermata").
  String tooltip(AppLocalizations l10n) {
    final t = title;
    if (t == null) return l10n.desktopTrayTooltipIdle;
    final a = artist;
    if (a == null || a.isEmpty) return l10n.desktopTrayTooltipTitleOnly(t);
    return l10n.desktopTrayTooltipTrack(t, a);
  }

  /// The localized menu: now-playing label, separator, transport,
  /// separator, show, quit.
  List<TrayMenuEntry> entries(AppLocalizations l10n) {
    final t = title;
    final a = artist;
    final String nowPlaying;
    if (t == null) {
      nowPlaying = l10n.desktopTrayNotPlaying;
    } else if (a == null || a.isEmpty) {
      nowPlaying = t;
    } else {
      nowPlaying = l10n.desktopTrayNowPlaying(t, a);
    }
    return [
      TrayMenuEntry.item(TrayMenuIds.nowPlaying, _ellipsize(nowPlaying), enabled: false),
      const TrayMenuEntry.separator(),
      TrayMenuEntry.item(
        TrayMenuIds.playPause,
        playing ? l10n.desktopTrayPause : l10n.desktopTrayPlay,
        enabled: hasTrack,
      ),
      TrayMenuEntry.item(TrayMenuIds.previous, l10n.desktopTrayPrevious, enabled: hasTrack),
      TrayMenuEntry.item(TrayMenuIds.next, l10n.desktopTrayNext, enabled: hasTrack),
      const TrayMenuEntry.separator(),
      TrayMenuEntry.item(TrayMenuIds.show, l10n.desktopTrayShow),
      TrayMenuEntry.item(TrayMenuIds.quit, l10n.desktopTrayQuit),
    ];
  }

  /// Menus with very long labels get unwieldy (and Windows truncates
  /// tooltips at 127 characters).
  static String _ellipsize(String s, [int max = 60]) => s.length <= max ? s : '${s.substring(0, max - 1)}…';

  @override
  bool operator ==(Object other) =>
      other is TrayMenuState &&
      other.title == title &&
      other.artist == artist &&
      other.playing == playing &&
      other.localeName == localeName;

  @override
  int get hashCode => Object.hash(title, artist, playing, localeName);

  @override
  String toString() => 'TrayMenuState($title, $artist, playing: $playing, $localeName)';
}
