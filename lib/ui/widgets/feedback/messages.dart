import '../../../core/errors.dart';
import '../../../core/models/track.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Localized explanation for an `AvailabilityReason` code.
String availabilityReasonText(AppLocalizations l10n, String? reason) => switch (reason) {
      AvailabilityReason.deleted => l10n.reasonDeleted,
      AvailabilityReason.private => l10n.reasonPrivate,
      AvailabilityReason.regionRestricted => l10n.reasonRegionRestricted,
      AvailabilityReason.subscriptionRequired => l10n.reasonSubscriptionRequired,
      AvailabilityReason.notStreamable => l10n.reasonNotStreamable,
      AvailabilityReason.previewOnly => l10n.reasonPreviewOnly,
      AvailabilityReason.externalOnly => l10n.reasonExternalOnly,
      AvailabilityReason.fileMissing => l10n.reasonFileMissing,
      AvailabilityReason.notAuthorized => l10n.reasonNotAuthorized,
      AvailabilityReason.credentialsMissing => l10n.reasonCredentialsMissing,
      AvailabilityReason.offline => l10n.reasonOffline,
      _ => l10n.reasonUnknown,
    };

/// True when [reason] is one of the known `AvailabilityReason` codes.
bool isAvailabilityReason(String? reason) => const {
      AvailabilityReason.deleted,
      AvailabilityReason.private,
      AvailabilityReason.regionRestricted,
      AvailabilityReason.subscriptionRequired,
      AvailabilityReason.notStreamable,
      AvailabilityReason.previewOnly,
      AvailabilityReason.externalOnly,
      AvailabilityReason.fileMissing,
      AvailabilityReason.notAuthorized,
      AvailabilityReason.credentialsMissing,
      AvailabilityReason.offline,
      AvailabilityReason.unknown,
    }.contains(reason);

/// Localized label of an offline category.
String offlineRightsLabel(AppLocalizations l10n, OfflineRights rights) => switch (rights) {
      OfflineRights.userOwned => l10n.offlineUserOwned,
      OfflineRights.downloadable => l10n.offlineDownloadable,
      OfflineRights.streamOnly => l10n.offlineStreamOnly,
      OfflineRights.unavailable => l10n.offlineUnavailable,
    };

/// Maps any error to a user-facing message (by `FermataException` type /
/// `code`). Returns null for cancellations (nothing should be shown).
/// [sourceName] turns a source id into its display name.
String? errorMessageFor(AppLocalizations l10n, Object error, {String Function(String sourceId)? sourceName}) {
  String name(String id) => sourceName?.call(id) ?? id;
  if (error is! FermataException) return l10n.errorGeneric;
  return switch (error) {
    OperationCanceledException() => null,
    NetworkException(isTimeout: true) => l10n.errorTimeout,
    NetworkException() => l10n.errorOffline,
    RateLimitedException() => l10n.errorRateLimited,
    AuthRequiredException(:final sourceId) => l10n.errorAuthRequired(name(sourceId)),
    MissingCredentialsException(:final sourceId) => l10n.errorCredentialsMissing(name(sourceId)),
    UnsupportedSourceOperation(:final sourceId) => l10n.errorUnsupported(name(sourceId)),
    UnplayableTrackException(:final reason) => availabilityReasonText(l10n, reason),
    DownloadNotPermittedException(:final reason) =>
      isAvailabilityReason(reason) ? availabilityReasonText(l10n, reason) : l10n.shellErrorDownloadNotPermitted,
    StorageException() => l10n.shellErrorStorage,
    ApiException() => l10n.errorGeneric,
    // ignore: unreachable_switch_case
    _ => l10n.errorGeneric,
  };
}
