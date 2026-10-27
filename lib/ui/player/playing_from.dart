import 'package:flutter/widgets.dart';

import '../../core/models/playback.dart';
import '../design/context_ext.dart';

/// Human-readable "Playing from …" origin: the queue's `originLabel`, else a
/// localized name for well-known origins (`search`, `smart-queue`,
/// `library`, `favorites`). Null when unknown.
String? playingFromLabel(BuildContext context, QueueState queue) {
  final label = queue.originLabel;
  if (label != null && label.isNotEmpty) return label;
  final origin = queue.current?.origin;
  if (origin == null) return null;
  final l10n = context.l10n;
  final kind = origin.split(':').first;
  return switch (kind) {
    'search' => l10n.playerOriginSearch,
    'smart-queue' => l10n.playerOriginSmartQueue,
    'library' => l10n.playerOriginLibrary,
    'favorites' => l10n.playerOriginFavorites,
    _ => null,
  };
}
