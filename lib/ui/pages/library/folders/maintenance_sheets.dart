import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/models/library.dart';
import '../../../../core/models/track.dart';
import '../../../../l10n/gen/app_localizations.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/controls/fermata_button.dart';
import '../../../widgets/dialogs/dialogs.dart';
import '../../../widgets/dialogs/sheet.dart';
import '../../../widgets/feedback/states.dart';
import '../../../widgets/feedback/toast.dart';
import '../../../widgets/util/async_utils.dart';

final _missingProvider = FutureProvider.autoDispose<List<Track>>(
  (ref) => ref.watch(trackRepositoryProvider).findMissingFiles(),
  retry: noRetry,
);

final _duplicatesProvider = FutureProvider.autoDispose<List<DuplicateGroup>>(
  (ref) => ref.watch(trackRepositoryProvider).findDuplicates(),
  retry: noRetry,
);

Future<void> showMissingFilesSheet(BuildContext context) =>
    showFermataSheet<void>(context, builder: (_) => const MissingFilesSheet());

Future<void> showDuplicatesSheet(BuildContext context) =>
    showFermataSheet<void>(context, builder: (_) => const DuplicatesSheet());

Future<bool> _removeFromLibrary(BuildContext context, WidgetRef ref, List<Track> tracks) async {
  final l10n = context.l10n;
  final ok = await ConfirmDialog.show(
    context,
    title: l10n.libraryRemoveFromLibraryTitle(tracks.length),
    message: l10n.libraryRemoveFromLibraryMessage,
    confirmLabel: l10n.pagesRemove,
    destructive: true,
  );
  if (!ok) return false;
  try {
    await ref.read(trackRepositoryProvider).removeTracks([for (final t in tracks) t.id]);
    if (context.mounted) showFermataToast(context, l10n.libraryRemovedFromLibrary(tracks.length), icon: Icons.check_rounded);
    return true;
  } catch (e) {
    if (context.mounted) showFermataToast(context, l10n.errorGeneric, isError: true);
    return false;
  }
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.type.title),
                  const SizedBox(height: 4),
                  Text(subtitle, style: context.type.bodySmall),
                ],
              ),
            ),
            Flexible(child: child),
          ],
        ),
      );
}

Widget _trackRow(BuildContext context, Track t, {String? detail, VoidCallback? onRemove}) => ListTile(
      key: ValueKey('maint-${t.id}'),
      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text([t.artistLine, ?detail].where((s) => s.isNotEmpty).join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: onRemove == null
          ? null
          : IconButton(tooltip: context.l10n.libraryRemoveFromLibrary, icon: const Icon(Icons.delete_outline_rounded), onPressed: onRemove),
    );

/// Local tracks whose files are gone (moved / deleted / unmounted).
class MissingFilesSheet extends ConsumerWidget {
  const MissingFilesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final missing = ref.watch(_missingProvider);
    return _SheetFrame(
      title: l10n.libraryMissingFiles,
      subtitle: l10n.libraryMissingFilesHint,
      child: missing.when(
        loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(_missingProvider)),
        data: (tracks) => tracks.isEmpty
            ? EmptyState(icon: Icons.check_circle_outline_rounded, title: l10n.libraryNoMissingFiles, compact: true)
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (final t in tracks)
                    _trackRow(context, t, detail: t.localPath, onRemove: () async {
                      if (await _removeFromLibrary(context, ref, [t])) ref.invalidate(_missingProvider);
                    }),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FermataButton(
                        label: l10n.libraryRemoveAllMissing,
                        variant: FermataButtonVariant.danger,
                        onPressed: () async {
                          if (await _removeFromLibrary(context, ref, tracks)) ref.invalidate(_missingProvider);
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

String duplicateReasonLabel(AppLocalizations l10n, String reason) => switch (reason) {
      'same_hash' => l10n.libraryDuplicateSameFile,
      'same_isrc' => l10n.libraryDuplicateSameIsrc,
      _ => l10n.libraryDuplicateSameMetadata,
    };

/// Groups of tracks that look like duplicates (same file, ISRC or tags).
class DuplicatesSheet extends ConsumerWidget {
  const DuplicatesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final groups = ref.watch(_duplicatesProvider);
    return _SheetFrame(
      title: l10n.libraryDuplicates,
      subtitle: l10n.libraryDuplicatesHint,
      child: groups.when(
        loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(_duplicatesProvider)),
        data: (list) => list.isEmpty
            ? EmptyState(icon: Icons.check_circle_outline_rounded, title: l10n.libraryNoDuplicates, compact: true)
            : ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  for (final g in list) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Text(duplicateReasonLabel(l10n, g.reason), style: context.type.label.copyWith(color: context.colors.accentText)),
                    ),
                    for (final t in g.tracks)
                      _trackRow(context, t, detail: t.localPath ?? t.sourceId, onRemove: () async {
                        if (await _removeFromLibrary(context, ref, [t])) ref.invalidate(_duplicatesProvider);
                      }),
                  ],
                ],
              ),
      ),
    );
  }
}
