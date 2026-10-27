// Mirrors the registration snippet in lib/sources/PROVIDERS_WIRING.md: all
// four credentialed sources constructed exactly as bootstrap does, registered
// in a real SourceRegistryImpl, with NO credentials configured.
import 'package:fermata/core/contracts/music_source.dart';
import 'package:fermata/core/errors.dart';
import 'package:fermata/core/models/auth.dart';
import 'package:fermata/core/platform/platform_info.dart';
import 'package:fermata/core/sources/source_ids.dart';
import 'package:fermata/settings/settings_store.dart';
import 'package:fermata/sources/auth/auth.dart';
import 'package:fermata/sources/jamendo/jamendo_source.dart';
import 'package:fermata/sources/registry/source_registry_impl.dart';
import 'package:fermata/sources/soundcloud/soundcloud_source.dart';
import 'package:fermata/sources/spotify/spotify_source.dart';
import 'package:fermata/sources/youtube/youtube_source.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/helpers.dart';

void main() {
  test('bootstrap wiring: initAll never throws without credentials; every call is refused offline', () async {
    final net = RecordingHttp((r) async => jsonResponse(<String, Object?>{}));
    final http = net.fermata;
    final credentials = FakeCredentialsStore();
    final tokens = InMemoryTokenStore();
    final oauth = FakeOAuthClient();
    const platform = PlatformInfo(os: HostOs.linux);

    final sources = SourceRegistryImpl(settings: SettingsStore.inMemory())
      ..register(SoundCloudSource(http: http, oauth: oauth, tokens: tokens, credentials: credentials, platform: platform))
      ..register(SpotifySource(http: http, oauth: oauth, tokens: tokens, credentials: credentials, platform: platform))
      ..register(YouTubeSource(http: http, oauth: oauth, tokens: tokens, credentials: credentials, platform: platform))
      ..register(JamendoSource(http: http, credentials: credentials));
    addTearDown(() async {
      for (final s in sources.all) {
        await s.dispose();
      }
      await sources.dispose();
      await credentials.dispose();
    });

    await sources.initAll();

    for (final id in [SourceIds.soundcloud, SourceIds.spotify, SourceIds.youtube, SourceIds.jamendo]) {
      final s = sources.require(id);
      expect(s.credentialStatus.configured, isFalse, reason: id);
      expect(s.credentialStatus.missing, isNotEmpty, reason: id);
      expect(s.authState.status, SourceConnectionStatus.credentialsMissing, reason: id);
      expect(s.isReady, isFalse, reason: id);
      await expectLater(s.searchTracks('x'), throwsA(isA<MissingCredentialsException>()), reason: id);
    }
    expect(net.requests, isEmpty);
    expect(sources.require(SourceIds.soundcloud).capabilities, isNot(contains(SourceCapability.download)));
    expect(sources.require(SourceIds.jamendo).capabilities, contains(SourceCapability.download));
  });
}
