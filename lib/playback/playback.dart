/// Playback engine public API (see `lib/playback/README.md`).
library;

export 'backend/audio_backend.dart';
export 'backend/just_audio_backend.dart' show JustAudioBackend;
export 'backend/media_kit_backend.dart' show MediaKitBackend;
export 'backend/platform_audio_backend.dart';
export 'engine/playback_tuning.dart';
export 'playback_controller_impl.dart';
export 'queue/play_queue.dart' show smartQueueOrigin;
export 'stream_resolver_impl.dart';
