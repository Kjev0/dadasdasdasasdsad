/// Downloads, offline & storage — public API of the module.
///
/// See `lib/downloads/README.md` for bootstrap wiring.
library;

export 'artwork/fermata_artwork_cache.dart' show FermataArtworkCache, OfflineArtworkStore;
export 'download_errors.dart' show DownloadErrorCode, DownloadFailure, DownloadFailureException;
export 'download_manager_impl.dart' show DownloadManagerImpl;
export 'download_options.dart' show DownloadOptions;
export 'files/file_ops.dart' show FileMover;
export 'files/path_builder.dart' show DownloadPathBuilder, FileNameSanitizer;
export 'integrity/audio_sniffer.dart' show AudioContainer, AudioSniffer, SniffResult;
export 'integrity/integrity.dart' show DownloadIntegrityException, IntegrityChecker, VerifiedFile;
export 'network/connectivity_network_status.dart' show ConnectivityNetworkStatus;
export 'network/network_policy.dart' show DownloadNetworkPolicy, NetworkWaitReason;
export 'network/network_status.dart' show NetworkKind, NetworkState, NetworkStatus;
export 'notify/batch_notifier.dart' show DownloadBatchNotifier, DownloadNotificationStrings;
export 'storage/free_space.dart' show FreeSpace;
