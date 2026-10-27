import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/providers.dart';
import '../../../../core/contracts/music_source.dart';
import '../../../../core/models/matching.dart';
import '../../../../settings/app_settings.dart';
import '../../../actions/routes.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/feedback/messages.dart';
import '../../../widgets/feedback/toast.dart';

/// Match targets for importing from [originSource]: ready sources that
/// stream full tracks inside Fermata (and previews when the user allows
/// them), in the user's provider order. External-only providers (Spotify,
/// YouTube) are never targets.
List<String> importTargets(AppSettings settings, SourceRegistry registry, {String? originSource}) {
  final order = settings.services.providerOrder;
  final sources = [...registry.ordered]..sort((a, b) {
      int rank(MusicSource s) {
        final i = order.indexOf(s.id);
        return i < 0 ? order.length : i;
      }

      return rank(a).compareTo(rank(b));
    });
  return [
    for (final s in sources)
      if (s.id != originSource &&
          s.isReady &&
          s.supports(SourceCapability.searchTracks) &&
          (s.supports(SourceCapability.stream) || (settings.import.allowPreviewOnly && s.supports(SourceCapability.previewOnly))))
        s.id,
  ];
}

/// [MatchOptions] from the user's import settings.
MatchOptions matchOptionsFor(AppSettings settings, SourceRegistry registry, {String? originSource}) {
  final s = settings.import;
  return MatchOptions(
    targetSources: importTargets(settings, registry, originSource: originSource),
    reviewMode: s.reviewMode,
    autoAcceptThreshold: s.autoAcceptThreshold,
    skipUnavailable: s.skipUnavailable,
    preferredSource: s.preferredSource,
    allowPreviewOnly: s.allowPreviewOnly,
  );
}

/// Starts "import & match" of a remote playlist and opens its review page.
Future<void> startPlaylistImport(BuildContext context, WidgetRef ref, {required String sourceId, required String playlistIdOrUrl}) async {
  final settings = ref.read(settingsProvider);
  final registry = ref.read(sourceRegistryProvider);
  try {
    final id = await ref.read(playlistImportProvider).start(
          sourceId: sourceId,
          playlistIdOrUrl: playlistIdOrUrl,
          options: matchOptionsFor(settings, registry, originSource: sourceId),
        );
    if (context.mounted) context.go(AppRoutes.importSession(id));
  } catch (e) {
    if (!context.mounted) return;
    final message = errorMessageFor(context.l10n, e, sourceName: (id) => registry.byId(id)?.displayName ?? id);
    if (message != null) showFermataToast(context, message, isError: true);
  }
}
