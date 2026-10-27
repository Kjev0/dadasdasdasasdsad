import 'dart:math';

import 'package:fermata/sources/auth/pkce.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PKCE (RFC 7636)', () {
    test('appendix B test vector', () {
      // RFC 7636 Appendix B: the 32 random octets and the resulting values.
      const octets = [
        116, 24, 223, 180, 151, 153, 224, 37, 79, 250, 96, 125, 216, 173, 187, 186, //
        22, 212, 37, 77, 105, 214, 191, 240, 91, 88, 5, 88, 83, 132, 141, 121,
      ];
      final pair = PkcePair.fromBytes(octets);
      expect(pair.verifier, 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk');
      expect(pair.challenge, 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
      expect(pair.method, 'S256');
      expect(
        PkcePair.challengeFor('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('generated verifiers use 64 random bytes and the unreserved alphabet', () {
      final pair = PkcePair.generate();
      expect(pair.verifier.length, 86); // 64 bytes base64url without padding
      expect(RegExp(r'^[A-Za-z0-9\-._~]{43,128}$').hasMatch(pair.verifier), isTrue);
      expect(pair.challenge.length, 43);
      expect(pair.challenge, PkcePair.challengeFor(pair.verifier));
      expect(PkcePair.generate().verifier, isNot(pair.verifier));
    });

    test('deterministic with an injected Random', () {
      expect(PkcePair.generate(random: Random(1)).verifier, PkcePair.generate(random: Random(1)).verifier);
    });

    test('state values are unguessable-length base64url', () {
      final s = generateOAuthState();
      expect(s.length, 43);
      expect(s, isNot(contains('=')));
      expect(generateOAuthState(), isNot(s));
    });
  });
}
