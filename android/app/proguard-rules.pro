# Fermata - R8 rules for release builds.
#
# Picked up automatically by the Flutter Gradle plugin (next to
# proguard-android-optimize.txt and Flutter's flutter_proguard_rules.pro).
# Most plugins and their libraries ship consumer rules of their own
# (androidx.media3 / ExoPlayer, androidx.media, package:jni, ...), so this file
# only covers what those do not.

# --- Plugins used for background playback ----------------------------------
# audio_service: AudioService (MediaBrowserServiceCompat), MediaButtonReceiver and
# AudioServiceActivity are entered by the framework / manifest and by our
# MainActivity. just_audio + audio_session are driven from Dart over method
# channels. None of them use reflection today, but they are small and a
# stripped callback here means silent playback/notification failures that are
# hard to diagnose in the field, so keep them whole.
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audio_session.** { *; }

# --- flutter_secure_storage --------------------------------------------------
# The cipher algorithms are persisted in SharedPreferences and looked up again
# by enum name (KeyCipherAlgorithm / StorageCipherAlgorithm name()/valueOf()).
# Keep the package intact so stored OAuth tokens stay decryptable across
# releases built with different R8 versions/optimizations.
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# --- media_kit (pulled in on Android by media_kit_libs_audio) ---------------
# libmediakitandroidhelper.so calls back into these static Java methods via JNI
# by name (content:// URI support), which R8 cannot see.
-keep class com.alexmercerind.mediakitandroidhelper.** { *; }
