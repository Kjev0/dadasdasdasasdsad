package app.fermata.player

import com.ryanheise.audioservice.AudioServiceActivity

/**
 * Fermata's single Android activity.
 *
 * Extends audio_service's [AudioServiceActivity] instead of FlutterActivity so
 * the activity and the background playback service (AudioService) share one
 * cached FlutterEngine. That way playback, the MediaSession and the media
 * notification keep running when the activity is destroyed (swiped away from
 * recents, rotated, etc.), and re-opening the UI re-attaches to the same
 * engine instead of starting a second Dart isolate.
 */
class MainActivity : AudioServiceActivity()
