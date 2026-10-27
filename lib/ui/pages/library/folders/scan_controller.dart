import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../../../app/providers.dart';
import '../../../../core/models/library.dart';
import '../../../design/context_ext.dart';
import '../../../widgets/feedback/messages.dart';
import '../../../widgets/feedback/toast.dart';
import '../shared/page_services.dart';

final _log = Logger('ui.pages.scan');

/// State of the current (or last) library scan.
@immutable
class LibraryScanState {
  const LibraryScanState({this.progress, this.running = false, this.error, this.folder});

  final ScanProgress? progress;
  final bool running;
  final Object? error;

  /// The folder being scanned (null = all folders).
  final String? folder;

  /// 0..1 when the total is known.
  double? get fraction {
    final total = progress?.totalFiles;
    if (progress == null || total == null || total == 0) return null;
    return (progress!.scannedFiles / total).clamp(0.0, 1.0);
  }
}

/// Runs library scans and keeps their progress app-wide, so the Folders tab
/// shows it even after navigating away and back.
class LibraryScanController extends Notifier<LibraryScanState> {
  StreamSubscription<ScanProgress>? _sub;

  @override
  LibraryScanState build() {
    ref.onDispose(() => _sub?.cancel());
    return const LibraryScanState();
  }

  /// Starts a scan of [folder] (or every folder). A running scan is
  /// replaced (the library queues scans internally).
  void start({String? folder, bool full = false}) {
    _sub?.cancel();
    state = LibraryScanState(running: true, folder: folder);
    final stream = ref.read(localLibraryProvider).scan(folder: folder, full: full);
    _sub = stream.listen(
      (progress) {
        if (!ref.mounted) return;
        state = LibraryScanState(progress: progress, running: !progress.done, folder: folder);
      },
      onError: (Object e, StackTrace st) {
        _log.warning('Scan failed', e, st);
        if (!ref.mounted) return;
        state = LibraryScanState(progress: state.progress, error: e, folder: folder);
      },
      onDone: () {
        if (!ref.mounted) return;
        if (state.running) state = LibraryScanState(progress: state.progress, folder: folder);
      },
    );
  }

  /// Stops listening (the library finishes the current batch and stops).
  void cancel() {
    _sub?.cancel();
    _sub = null;
    state = LibraryScanState(progress: state.progress, folder: state.folder);
  }
}

final libraryScanProvider = NotifierProvider<LibraryScanController, LibraryScanState>(LibraryScanController.new);

/// Asks for a music folder, adds it to the library and starts scanning it.
/// On Android the audio library permission is requested first. Returns
/// true when a folder was added.
Future<bool> addMusicFolder(BuildContext context, WidgetRef ref) async {
  final l10n = context.l10n;
  final platform = ref.read(platformInfoProvider);
  if (platform.isAndroid) {
    final android = ref.read(androidSystemProvider);
    if (android.isSupported && !await android.audioLibraryPermitted()) {
      final granted = await android.requestAudioLibraryPermission();
      if (!granted) {
        if (context.mounted) {
          showFermataToast(
            context,
            l10n.libraryPermissionNeeded,
            icon: Icons.lock_outline_rounded,
            isError: true,
            actionLabel: l10n.libraryOpenSystemSettings,
            onAction: () => android.openAppSettings(),
          );
        }
        return false;
      }
    }
  }
  final path = await ref.read(pageFilePickerProvider).pickDirectory(title: l10n.libraryAddFolder);
  if (path == null || !context.mounted) return false;
  try {
    await ref.read(localLibraryProvider).addFolder(path);
  } catch (e) {
    if (context.mounted) {
      showFermataToast(context, errorMessageFor(l10n, e) ?? l10n.errorGeneric, isError: true);
    }
    return false;
  }
  ref.read(libraryScanProvider.notifier).start(folder: path);
  if (context.mounted) {
    showFermataToast(context, l10n.libraryFolderAdded(p.basename(path)), icon: Icons.folder_rounded);
  }
  return true;
}
