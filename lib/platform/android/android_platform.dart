/// Android media session & system helpers (public API).
///
/// See `lib/platform/android/README.md` for wiring and
/// `docs/platform/ANDROID_BACKGROUND.md` for lifecycle behavior.
library;

export 'android_media_session.dart' show AndroidMediaSession;
export 'android_notifier.dart' show AndroidNotifier;
export 'android_system_helper.dart'
    show AndroidSystemHelperImpl, PermissionGateway, PermissionHandlerGateway, SdkIntReader, androidTiramisu;
export 'fermata_audio_handler.dart' show FermataAudioHandler;
export 'headset_auto_resume.dart' show AudioRouteEvents, AudioSessionRouteEvents, HeadsetAutoResume, headsetDeviceTypes;
export 'media_browser.dart' show BrowseId, BrowseKind, MediaLibraryBrowser, PlayRequest;
export 'media_button_clicks.dart' show MediaButtonClickDetector, TimerFactory;
export 'media_session_config.dart' show AndroidMediaSessionConstants, buildAudioServiceConfig, preloadArtworkFor;
export 'media_session_labels.dart' show MediaSessionLabels;
export 'media_session_mapping.dart' show LikeControlIcons, MediaItemExtras, QueueWindow, toggleLikeActionName;
