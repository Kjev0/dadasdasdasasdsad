import '../../core/platform/platform_info.dart';
import 'audio_backend.dart';
import 'just_audio_backend.dart';
import 'media_kit_backend.dart';

/// Picks the audio backend for the running platform: `just_audio`
/// (ExoPlayer) on Android, libmpv (`media_kit`) on Linux/Windows.
///
/// On desktop, [MediaKitBackend.ensureInitialized] must have been called
/// before (bootstrap does this first thing).
AudioBackend createPlatformAudioBackend(PlatformInfo platform) {
  if (platform.isAndroid) return JustAudioBackend();
  if (platform.isDesktop) return MediaKitBackend();
  throw UnsupportedError('No audio backend for ${platform.os.name}');
}
