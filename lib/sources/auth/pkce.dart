import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// PKCE (RFC 7636) verifier/challenge pair using the S256 method.
class PkcePair {
  const PkcePair._(this.verifier, this.challenge);

  /// Creates a pair from 64 cryptographically secure random bytes
  /// (→ an 86-character base64url verifier, within RFC 7636's 43–128).
  factory PkcePair.generate({Random? random}) {
    final rnd = random ?? Random.secure();
    return PkcePair.fromBytes(List<int>.generate(64, (_) => rnd.nextInt(256)));
  }

  /// Deterministic construction from raw verifier bytes (used by tests with
  /// the RFC 7636 appendix B vector).
  factory PkcePair.fromBytes(List<int> bytes) {
    final verifier = base64UrlNoPad(bytes);
    return PkcePair._(verifier, challengeFor(verifier));
  }

  /// `BASE64URL-ENCODE(SHA256(ASCII(code_verifier)))`.
  static String challengeFor(String verifier) => base64UrlNoPad(sha256.convert(ascii.encode(verifier)).bytes);

  final String verifier;
  final String challenge;

  String get method => 'S256';
}

/// URL-safe base64 without `=` padding (RFC 7636 §3 / RFC 4648 §5).
String base64UrlNoPad(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// A random, unguessable `state` value for CSRF protection (32 bytes).
String generateOAuthState({Random? random}) {
  final rnd = random ?? Random.secure();
  return base64UrlNoPad(List<int>.generate(32, (_) => rnd.nextInt(256)));
}
