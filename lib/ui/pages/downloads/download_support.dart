import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../app/providers.dart';
import '../../../core/contracts/downloads.dart';
import '../../../core/models/download.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../design/context_ext.dart';
import '../../widgets/feedback/messages.dart';
import '../../widgets/util/async_utils.dart';

final _log = Logger('ui.pages.downloads');

// ---------------------------------------------------------------------------
// Optional download-manager capabilities. The frozen `DownloadManager`
// contract has no network-policy API; the implementation exposes
// `needsMobileDataConfirmation`, `confirmMobileDataForSession()` and
// `networkWaitReason` as extras. The UI must not import the implementation,
// so they are reached dynamically and degrade to "unknown" when absent.
// ---------------------------------------------------------------------------

/// Whether queued downloads wait for the user to accept mobile data; null
/// when the manager doesn't expose it.
bool? needsMobileDataConfirmation(DownloadManager dm) {
  try {
    final v = (dm as dynamic).needsMobileDataConfirmation;
    return v is bool ? v : null;
  } on NoSuchMethodError {
    return null;
  }
}

/// Allows downloads over mobile data until the app restarts.
bool confirmMobileData(DownloadManager dm) {
  try {
    (dm as dynamic).confirmMobileDataForSession();
    return true;
  } on NoSuchMethodError {
    _log.warning('Download manager cannot confirm mobile data');
    return false;
  }
}

/// Why downloads wait: `offline`, `wifiOnly`, `mobileDataConfirmation` or
/// null (not waiting / unknown).
String? networkWaitReason(DownloadManager dm) {
  try {
    final v = (dm as dynamic).networkWaitReason;
    if (v == null) return null;
    if (v is Enum) return v.name;
    return v.toString();
  } on NoSuchMethodError {
    return null;
  }
}

/// Storage usage; refreshed whenever a download completes or is removed.
final storageUsageProvider = FutureProvider.autoDispose<StorageUsage>(
  (ref) async {
    ref.watch(downloadTasksProvider.select((v) {
      final tasks = v.value ?? const <DownloadTask>[];
      return '${tasks.length}:${tasks.where((t) => t.status == DownloadStatus.completed).length}';
    }));
    return ref.watch(downloadManagerProvider).storageUsage();
  },
  retry: noRetry,
);

/// Localized status label.
String downloadStatusLabel(AppLocalizations l10n, DownloadStatus s) => switch (s) {
      DownloadStatus.queued => l10n.downloadsStatusQueued,
      DownloadStatus.waitingForNetwork => l10n.downloadsStatusWaiting,
      DownloadStatus.downloading => l10n.downloadsStatusDownloading,
      DownloadStatus.verifying => l10n.downloadsStatusVerifying,
      DownloadStatus.paused => l10n.downloadsStatusPaused,
      DownloadStatus.completed => l10n.downloadsStatusCompleted,
      DownloadStatus.failed => l10n.downloadsStatusFailed,
      DownloadStatus.canceled => l10n.downloadsStatusCanceled,
    };

/// Color of a status chip.
Color downloadStatusColor(BuildContext context, DownloadStatus s) {
  final c = context.colors;
  return switch (s) {
    DownloadStatus.completed => c.success,
    DownloadStatus.failed => c.danger,
    DownloadStatus.downloading || DownloadStatus.verifying => c.accentText,
    DownloadStatus.waitingForNetwork || DownloadStatus.paused => c.warning,
    _ => c.textSecondary,
  };
}

/// Localized text for a `DownloadTask.error` code (the downloads module's
/// `DownloadErrorCode`s plus `AvailabilityReason`s).
String downloadErrorText(AppLocalizations l10n, String? code) => switch (code) {
      null => l10n.errorGeneric,
      'download_not_permitted' => l10n.shellErrorDownloadNotPermitted,
      'source_unavailable' => l10n.downloadsErrorSourceUnavailable,
      'auth_required' => l10n.downloadsErrorAuth,
      'credentials_missing' => l10n.reasonCredentialsMissing,
      'unavailable' => l10n.reasonUnknown,
      'http_not_found' => l10n.downloadsErrorNotFound,
      'http_forbidden' => l10n.downloadsErrorForbidden,
      'http_error' || 'server_error' => l10n.downloadsErrorServer,
      'rate_limited' => l10n.errorRateLimited,
      'network_error' => l10n.errorOffline,
      'network_timeout' => l10n.errorTimeout,
      'not_audio' => l10n.downloadsErrorNotAudio,
      'size_mismatch' || 'checksum_mismatch' => l10n.downloadsErrorCorrupt,
      'file_missing' => l10n.reasonFileMissing,
      'disk_full' => l10n.downloadsErrorDiskFull,
      'storage_error' => l10n.shellErrorStorage,
      _ => isAvailabilityReason(code) ? availabilityReasonText(l10n, code) : l10n.errorGeneric,
    };
