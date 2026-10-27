import 'package:flutter/foundation.dart';

enum SourceConnectionStatus {
  /// The source works without an account (public API) or is local.
  notRequired,

  /// Developer credentials (client id etc.) are missing; see
  /// `MusicSource.credentialStatus` for the explanation.
  credentialsMissing,
  notConnected,
  connecting,
  connected,

  /// Token expired and refresh failed — the user must reconnect.
  expired,
  error,
}

@immutable
class SourceAuthState {
  const SourceAuthState({
    required this.status,
    this.accountName,
    this.accountAvatar,
    this.grantedScopes = const [],
    this.error,
    this.expiresAt,
  });

  const SourceAuthState.notRequired() : this(status: SourceConnectionStatus.notRequired);

  final SourceConnectionStatus status;
  final String? accountName;
  final Uri? accountAvatar;
  final List<String> grantedScopes;
  final String? error;
  final DateTime? expiresAt;

  bool get isConnected => status == SourceConnectionStatus.connected;
}

@immutable
class OAuthToken {
  const OAuthToken({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.scopes = const [],
    this.tokenType = 'Bearer',
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final List<String> scopes;
  final String tokenType;

  bool isExpired({Duration leeway = const Duration(seconds: 60)}) =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!.subtract(leeway));

  Map<String, Object?> toJson() => {
        'access': accessToken,
        if (refreshToken != null) 'refresh': refreshToken,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'scopes': scopes,
        'type': tokenType,
      };

  factory OAuthToken.fromJson(Map<String, Object?> json) => OAuthToken(
        accessToken: json['access'] as String,
        refreshToken: json['refresh'] as String?,
        expiresAt: json['expiresAt'] == null ? null : DateTime.tryParse(json['expiresAt'] as String),
        scopes: (json['scopes'] as List?)?.cast<String>() ?? const [],
        tokenType: json['type'] as String? ?? 'Bearer',
      );
}

/// Developer credentials for a source (never user passwords).
@immutable
class SourceCredentials {
  const SourceCredentials({this.clientId, this.clientSecret, this.apiKey, this.redirectUri});

  final String? clientId;

  /// Only for providers whose token endpoint requires it (e.g. SoundCloud).
  final String? clientSecret;
  final String? apiKey;

  /// Override of the default redirect URI.
  final String? redirectUri;

  bool get isEmpty =>
      (clientId == null || clientId!.isEmpty) && (apiKey == null || apiKey!.isEmpty);

  Map<String, Object?> toJson() => {
        if (clientId != null) 'clientId': clientId,
        if (clientSecret != null) 'clientSecret': clientSecret,
        if (apiKey != null) 'apiKey': apiKey,
        if (redirectUri != null) 'redirectUri': redirectUri,
      };

  factory SourceCredentials.fromJson(Map<String, Object?> json) => SourceCredentials(
        clientId: json['clientId'] as String?,
        clientSecret: json['clientSecret'] as String?,
        apiKey: json['apiKey'] as String?,
        redirectUri: json['redirectUri'] as String?,
      );
}

/// Where developer credentials came from (shown in Connected services).
enum CredentialOrigin { none, buildTime, configFile, userEntered }

@immutable
class CredentialStatus {
  const CredentialStatus({required this.configured, required this.origin, this.missing = const [], this.helpUrl});

  const CredentialStatus.notNeeded()
      : configured = true,
        origin = CredentialOrigin.none,
        missing = const [],
        helpUrl = null;

  final bool configured;
  final CredentialOrigin origin;

  /// Names of missing fields, e.g. `['clientId', 'clientSecret']`.
  final List<String> missing;

  /// Where a developer registers an app for this provider.
  final Uri? helpUrl;
}
