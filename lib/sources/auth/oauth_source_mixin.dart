import 'package:flutter/foundation.dart';

import '../../core/models/auth.dart';
import '../base/music_source_base.dart';
import 'oauth_session.dart';

/// Gives a [MusicSourceBase] an account connection backed by an
/// [OAuthSession]: auth state, credential status, connect/disconnect and
/// `isReady` are delegated to the session.
///
/// ```dart
/// class MySource extends MusicSourceBase with OAuthSourceMixin {
///   MySource(...) : oauthSession = OAuthSession(...);
///   @override
///   final OAuthSession oauthSession;
///
///   @override
///   Future<Page<Track>> searchTracks(String q, {...}) async {
///     ensureCredentials();
///     final json = await oauthSession.authorizedGetJson(uri, cancel: cancel);
///     ...
///   }
/// }
/// ```
///
/// Sources that can also serve public requests without a user connection
/// (e.g. SoundCloud with client credentials) override [isReady].
mixin OAuthSourceMixin on MusicSourceBase {
  /// The session for this source (create it in the constructor).
  OAuthSession get oauthSession;

  @override
  Future<void> init() => oauthSession.init();

  @override
  CredentialStatus get credentialStatus => oauthSession.credentialStatus;

  @override
  SourceAuthState get authState => oauthSession.state;

  @override
  Stream<SourceAuthState> get authStateChanges => oauthSession.changes;

  @override
  Future<void> connect() => oauthSession.connect();

  @override
  Future<void> disconnect() => oauthSession.disconnect();

  @override
  bool get isReady => oauthSession.hasCredentials && oauthSession.state.isConnected;

  /// Throws `MissingCredentialsException` when developer credentials are
  /// missing — call first in every API method so no request is made.
  @protected
  void ensureCredentials() => oauthSession.requireCredentials();

  @override
  Future<void> dispose() async {
    await oauthSession.dispose();
    await super.dispose();
  }
}
