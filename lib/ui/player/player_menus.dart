import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../design/context_ext.dart';
import '../widgets/feedback/messages.dart';
import '../widgets/feedback/toast.dart';
import '../widgets/tracks/track_format.dart';

/// Speeds offered in the speed menu.
const playbackSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// Sleep timer presets in minutes.
const sleepTimerPresets = [5, 10, 15, 30, 45, 60, 90];

/// Locale-aware speed label ("1.25×" / "1,25×").
String formatSpeed(BuildContext context, double speed) {
  final locale = Localizations.localeOf(context).toString();
  return context.l10n.playerSpeedValue(NumberFormat('0.##', locale).format(speed));
}

/// Opens a popup menu anchored below [anchor].
Future<T?> showAnchoredMenu<T>(BuildContext anchor, List<PopupMenuEntry<T>> items) {
  final box = anchor.findRenderObject() as RenderBox?;
  final screen = MediaQuery.sizeOf(anchor);
  final origin = box?.localToGlobal(Offset.zero) ?? Offset.zero;
  final size = box?.size ?? Size.zero;
  return showMenu<T>(
    context: anchor,
    position: RelativeRect.fromRect(origin & size, Offset.zero & screen),
    items: items,
  );
}

PopupMenuItem<T> _checkItem<T>(BuildContext context, T value, String label, bool checked) => PopupMenuItem<T>(
      value: value,
      height: 40,
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: checked ? Icon(Icons.check_rounded, size: 18, color: context.colors.accentText) : null,
          ),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );

/// Output device picker (only rendered when the controller supports
/// output device selection).
class OutputDeviceButton extends ConsumerWidget {
  const OutputDeviceButton({super.key});

  /// Shows the device menu anchored at [context].
  static Future<void> open(BuildContext context, WidgetRef ref) async {
    final playback = ref.read(playbackProvider);
    final l10n = context.l10n;
    try {
      final devices = await playback.outputDevices();
      if (!context.mounted) return;
      final current = ref.read(settingsProvider).playback.outputDeviceId;
      final defaultDevice = devices.where((d) => d.isDefault).firstOrNull;
      final chosen = await showAnchoredMenu<String>(context, [
        for (final d in devices)
          _checkItem(
            context,
            d.id,
            d.isDefault ? '${d.name} · ${l10n.playerSystemDefault}' : d.name,
            current == null ? d.id == defaultDevice?.id : d.id == current,
          ),
        if (devices.isEmpty) PopupMenuItem<String>(enabled: false, child: Text(l10n.playerNoDevices)),
      ]);
      if (chosen != null) await playback.setOutputDevice(chosen);
    } catch (e) {
      if (context.mounted) {
        showFermataToast(context, errorMessageFor(l10n, e) ?? l10n.errorGeneric, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(playbackProvider).supportsOutputDeviceSelection) return const SizedBox.shrink();
    return Builder(
      builder: (anchor) => IconButton(
        tooltip: context.l10n.playerOutputDevice,
        icon: const Icon(Icons.speaker_rounded),
        onPressed: () => open(anchor, ref),
      ),
    );
  }
}

/// Playback speed menu (only when the controller supports speed).
class SpeedButton extends ConsumerWidget {
  const SpeedButton({super.key});

  /// Shows the speed menu anchored at [context].
  static Future<void> open(BuildContext context, WidgetRef ref) async {
    final speed = ref.read(currentSnapshotProvider).speed;
    final chosen = await showAnchoredMenu<double>(context, [
      for (final s in playbackSpeeds) _checkItem(context, s, formatSpeed(context, s), (s - speed).abs() < 0.01),
    ]);
    if (chosen != null) await ref.read(playbackProvider).setSpeed(chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(playbackProvider).supportsSpeed) return const SizedBox.shrink();
    final speed = ref.watch(currentSnapshotProvider.select((s) => s.speed));
    final l10n = context.l10n;
    return PopupMenuButton<double>(
      tooltip: '${l10n.playerSpeed} · ${formatSpeed(context, speed)}',
      icon: Icon(Icons.speed_rounded, color: (speed - 1).abs() > 0.01 ? context.colors.accentText : null),
      onSelected: (v) => ref.read(playbackProvider).setSpeed(v),
      itemBuilder: (context) => [
        for (final s in playbackSpeeds) _checkItem(context, s, formatSpeed(context, s), (s - speed).abs() < 0.01),
      ],
    );
  }
}

/// A sleep-timer choice: minutes, end of track, or off (null both).
class SleepChoice {
  const SleepChoice.minutes(int this.minutes) : endOfTrack = false;
  const SleepChoice.endOfTrack()
      : minutes = null,
        endOfTrack = true;
  const SleepChoice.off()
      : minutes = null,
        endOfTrack = false;

  final int? minutes;
  final bool endOfTrack;

  @override
  bool operator ==(Object other) => other is SleepChoice && other.minutes == minutes && other.endOfTrack == endOfTrack;

  @override
  int get hashCode => Object.hash(minutes, endOfTrack);
}

/// Applies a [SleepChoice]: `setSleepTimer(duration)`, end of track =
/// `setSleepTimer(null, endOfTrack: true)`, off = `setSleepTimer(null)`.
Future<void> applySleepChoice(WidgetRef ref, SleepChoice choice) {
  final playback = ref.read(playbackProvider);
  if (choice.endOfTrack) return playback.setSleepTimer(null, endOfTrack: true);
  if (choice.minutes == null) return playback.setSleepTimer(null);
  return playback.setSleepTimer(Duration(minutes: choice.minutes!));
}

/// Sleep timer menu; highlighted while a timer is active.
class SleepTimerButton extends ConsumerWidget {
  const SleepTimerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endsAt = ref.watch(currentSnapshotProvider.select((s) => s.sleepTimerEndsAt));
    final endOfTrack = ref.watch(currentSnapshotProvider.select((s) => s.sleepAtEndOfTrack));
    final l10n = context.l10n;
    final active = endsAt != null || endOfTrack;
    final tooltip = endOfTrack
        ? l10n.playerSleepAtEndOfTrack
        : endsAt != null
            ? l10n.playerSleepRemaining(formatDuration(endsAt.difference(DateTime.now())))
            : l10n.playerSleepTimer;
    return PopupMenuButton<SleepChoice>(
      tooltip: tooltip,
      icon: Icon(Icons.bedtime_rounded, color: active ? context.colors.accentText : null),
      onSelected: (choice) => applySleepChoice(ref, choice),
      itemBuilder: (context) => [
        _checkItem(context, const SleepChoice.off(), l10n.playerSleepOff, !active),
        for (final m in sleepTimerPresets) _checkItem(context, SleepChoice.minutes(m), l10n.playerSleepMinutes(m), false),
        _checkItem(context, const SleepChoice.endOfTrack(), l10n.playerSleepEndOfTrack, endOfTrack),
      ],
    );
  }
}
