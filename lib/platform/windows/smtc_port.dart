import 'dart:async';

import 'package:smtc_windows/smtc_windows.dart' as smtc;

import '../../core/models/playback.dart';

/// Buttons the Windows media overlay / hardware media keys can press.
enum SmtcButton { play, pause, next, previous, stop, other }

/// Playback state shown by the overlay.
enum SmtcStatus { closed, changing, stopped, playing, paused }

/// Thin seam over `smtc_windows` so [SmtcAdapter] logic is testable off
/// Windows. [SmtcWindowsPort] is the real one.
abstract class SmtcPort {
  Future<void> updateConfig({
    required bool play,
    required bool pause,
    required bool next,
    required bool previous,
    required bool stop,
  });
  Future<void> updateMetadata({String? title, String? artist, String? album, String? albumArtist, String? thumbnail});
  Future<void> clearMetadata();
  Future<void> setStatus(SmtcStatus status);
  Future<void> updateTimeline({required int startMs, required int endMs, required int positionMs});
  Future<void> setShuffle(bool enabled);
  Future<void> setRepeat(RepeatMode mode);
  Future<void> setEnabled(bool enabled);
  Stream<SmtcButton> get buttons;
  Stream<bool> get shuffleRequests;
  Stream<RepeatMode> get repeatRequests;
  Future<void> dispose();
}

/// [SmtcPort] backed by `smtc_windows` 1.1.0 (Rust via flutter_rust_bridge).
/// Create only on Windows: [create] loads the native library.
class SmtcWindowsPort implements SmtcPort {
  SmtcWindowsPort._(this._smtc);

  final smtc.SMTCWindows _smtc;

  /// Initializes the Rust bridge (`SMTCWindows.initialize()` →
  /// `RustLib.init()`) and creates the controls.
  static Future<SmtcWindowsPort> create() async {
    await smtc.SMTCWindows.initialize();
    return SmtcWindowsPort._(smtc.SMTCWindows(
      config: const smtc.SMTCConfig(
        playEnabled: true,
        pauseEnabled: true,
        nextEnabled: true,
        prevEnabled: true,
        stopEnabled: true,
        fastForwardEnabled: false,
        rewindEnabled: false,
      ),
      enabled: true,
    ));
  }

  @override
  Future<void> updateConfig({
    required bool play,
    required bool pause,
    required bool next,
    required bool previous,
    required bool stop,
  }) =>
      _smtc.updateConfig(smtc.SMTCConfig(
        playEnabled: play,
        pauseEnabled: pause,
        nextEnabled: next,
        prevEnabled: previous,
        stopEnabled: stop,
        fastForwardEnabled: false,
        rewindEnabled: false,
      ));

  @override
  Future<void> updateMetadata({String? title, String? artist, String? album, String? albumArtist, String? thumbnail}) =>
      _smtc.updateMetadata(smtc.MusicMetadata(
        title: title,
        artist: artist,
        album: album,
        albumArtist: albumArtist,
        thumbnail: thumbnail,
      ));

  @override
  Future<void> clearMetadata() => _smtc.clearMetadata();

  @override
  Future<void> setStatus(SmtcStatus status) => _smtc.setPlaybackStatus(switch (status) {
        SmtcStatus.closed => smtc.PlaybackStatus.closed,
        SmtcStatus.changing => smtc.PlaybackStatus.changing,
        SmtcStatus.stopped => smtc.PlaybackStatus.stopped,
        SmtcStatus.playing => smtc.PlaybackStatus.playing,
        SmtcStatus.paused => smtc.PlaybackStatus.paused,
      });

  @override
  Future<void> updateTimeline({required int startMs, required int endMs, required int positionMs}) =>
      _smtc.updateTimeline(smtc.PlaybackTimeline(
        startTimeMs: startMs,
        endTimeMs: endMs,
        positionMs: positionMs,
        minSeekTimeMs: startMs,
        maxSeekTimeMs: endMs,
      ));

  @override
  Future<void> setShuffle(bool enabled) => _smtc.setShuffleEnabled(enabled);

  @override
  Future<void> setRepeat(RepeatMode mode) => _smtc.setRepeatMode(switch (mode) {
        RepeatMode.off => smtc.RepeatMode.none,
        RepeatMode.one => smtc.RepeatMode.track,
        RepeatMode.all => smtc.RepeatMode.list,
      });

  @override
  Future<void> setEnabled(bool enabled) => enabled ? _smtc.enableSmtc() : _smtc.disableSmtc();

  @override
  Stream<SmtcButton> get buttons => _smtc.buttonPressStream.map((b) => switch (b) {
        smtc.PressedButton.play => SmtcButton.play,
        smtc.PressedButton.pause => SmtcButton.pause,
        smtc.PressedButton.next => SmtcButton.next,
        smtc.PressedButton.previous => SmtcButton.previous,
        smtc.PressedButton.stop => SmtcButton.stop,
        _ => SmtcButton.other,
      });

  @override
  Stream<bool> get shuffleRequests => _smtc.shuffleChangeStream;

  @override
  Stream<RepeatMode> get repeatRequests => _smtc.repeatModeChangeStream.map((m) => switch (m) {
        smtc.RepeatMode.none => RepeatMode.off,
        smtc.RepeatMode.track => RepeatMode.one,
        smtc.RepeatMode.list => RepeatMode.all,
      });

  @override
  Future<void> dispose() => _smtc.dispose();
}
