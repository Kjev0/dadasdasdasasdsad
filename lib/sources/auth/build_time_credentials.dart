import '../../core/models/auth.dart';
import '../../core/sources/source_ids.dart';

/// Developer credentials compiled in with `--dart-define` /
/// `--dart-define-from-file=dart_defines.json` (see docs/CREDENTIALS.md).
///
/// `String.fromEnvironment` must be evaluated in a const context, so every
/// supported name is listed here explicitly. Empty values mean "not set".
abstract final class BuildTimeCredentials {
  static const soundcloudClientId = String.fromEnvironment('FERMATA_SOUNDCLOUD_CLIENT_ID');
  static const soundcloudClientSecret = String.fromEnvironment('FERMATA_SOUNDCLOUD_CLIENT_SECRET');
  static const spotifyClientId = String.fromEnvironment('FERMATA_SPOTIFY_CLIENT_ID');
  static const youtubeClientId = String.fromEnvironment('FERMATA_YOUTUBE_CLIENT_ID');
  static const youtubeClientSecret = String.fromEnvironment('FERMATA_YOUTUBE_CLIENT_SECRET');
  static const youtubeApiKey = String.fromEnvironment('FERMATA_YOUTUBE_API_KEY');
  static const jamendoClientId = String.fromEnvironment('FERMATA_JAMENDO_CLIENT_ID');
  static const audiusApiKey = String.fromEnvironment('FERMATA_AUDIUS_API_KEY');

  /// Names of all supported `--dart-define` keys (for docs/diagnostics).
  static const defineNames = [
    'FERMATA_SOUNDCLOUD_CLIENT_ID',
    'FERMATA_SOUNDCLOUD_CLIENT_SECRET',
    'FERMATA_SPOTIFY_CLIENT_ID',
    'FERMATA_YOUTUBE_CLIENT_ID',
    'FERMATA_YOUTUBE_CLIENT_SECRET',
    'FERMATA_YOUTUBE_API_KEY',
    'FERMATA_JAMENDO_CLIENT_ID',
    'FERMATA_AUDIUS_API_KEY',
  ];

  /// The compiled-in credentials per source (sources without any value are
  /// omitted).
  static Map<String, SourceCredentials> all() => fromValues(const {
    'FERMATA_SOUNDCLOUD_CLIENT_ID': soundcloudClientId,
    'FERMATA_SOUNDCLOUD_CLIENT_SECRET': soundcloudClientSecret,
    'FERMATA_SPOTIFY_CLIENT_ID': spotifyClientId,
    'FERMATA_YOUTUBE_CLIENT_ID': youtubeClientId,
    'FERMATA_YOUTUBE_CLIENT_SECRET': youtubeClientSecret,
    'FERMATA_YOUTUBE_API_KEY': youtubeApiKey,
    'FERMATA_JAMENDO_CLIENT_ID': jamendoClientId,
    'FERMATA_AUDIUS_API_KEY': audiusApiKey,
  });

  /// Maps define-style values to per-source credentials (testable without
  /// recompiling).
  static Map<String, SourceCredentials> fromValues(Map<String, String> v) {
    String? val(String k) => (v[k] == null || v[k]!.trim().isEmpty) ? null : v[k]!.trim();
    final result = <String, SourceCredentials>{};
    void put(String id, SourceCredentials c) {
      if (c.clientId != null || c.clientSecret != null || c.apiKey != null) result[id] = c;
    }

    put(
      SourceIds.soundcloud,
      SourceCredentials(
        clientId: val('FERMATA_SOUNDCLOUD_CLIENT_ID'),
        clientSecret: val('FERMATA_SOUNDCLOUD_CLIENT_SECRET'),
      ),
    );
    put(SourceIds.spotify, SourceCredentials(clientId: val('FERMATA_SPOTIFY_CLIENT_ID')));
    put(
      SourceIds.youtube,
      SourceCredentials(
        clientId: val('FERMATA_YOUTUBE_CLIENT_ID'),
        clientSecret: val('FERMATA_YOUTUBE_CLIENT_SECRET'),
        apiKey: val('FERMATA_YOUTUBE_API_KEY'),
      ),
    );
    put(SourceIds.jamendo, SourceCredentials(clientId: val('FERMATA_JAMENDO_CLIENT_ID')));
    put(SourceIds.audius, SourceCredentials(apiKey: val('FERMATA_AUDIUS_API_KEY')));
    return result;
  }
}
