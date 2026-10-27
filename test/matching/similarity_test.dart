import 'package:fermata/matching/normalizer.dart';
import 'package:fermata/matching/similarity.dart';
import 'package:flutter_test/flutter_test.dart';

List<FoldedText> names(List<String> raw) => [for (final n in raw) TextKeys.artistName(n)];

void main() {
  group('primitives', () {
    final levenshtein = <(String, String), int>{
      ('kitten', 'sitting'): 3,
      ('', 'abc'): 3,
      ('flaw', 'lawn'): 2,
      ('same', 'same'): 0,
      ('ø', 'o'): 1,
    };
    levenshtein.forEach((pair, d) {
      test('levenshtein${pair.toString()} = $d', () => expect(Similarity.levenshtein(pair.$1, pair.$2), d));
    });

    final jw = <(String, String), double>{
      ('martha', 'marhta'): 0.961,
      ('dwayne', 'duane'): 0.84,
      ('dixon', 'dicksonx'): 0.813,
    };
    jw.forEach((pair, expected) {
      test('jaroWinkler${pair.toString()} ≈ $expected', () {
        expect(Similarity.jaroWinkler(pair.$1, pair.$2), closeTo(expected, 0.001));
      });
    });

    test('edge cases', () {
      expect(Similarity.jaroWinkler('abc', 'abc'), 1);
      expect(Similarity.jaroWinkler('', 'abc'), 0);
      expect(Similarity.levenshteinSimilarity('', ''), 1);
      expect(Similarity.tokenSetJaccard('a b c', 'c b a'), 1);
      expect(Similarity.tokenSetJaccard('a b', 'b c'), closeTo(1 / 3, 1e-9));
      expect(Similarity.fuzzyTokenJaccard(['adventure', 'time'], ['adventrue', 'time']), 1);
      expect(Similarity.fuzzyTokenJaccard(['part', '2'], ['part', '3']), closeTo(1 / 3, 1e-9));
    });
  });

  group('title', () {
    test('equal and spacing-only differences are 1', () {
      expect(Similarity.title('adventure', 'adventure'), 1);
      expect(Similarity.title('a b c', 'abc'), 1);
    });

    test('typos stay high, extra words drop', () {
      expect(Similarity.title('adventure', 'adventrue'), greaterThan(0.85));
      expect(Similarity.title('hello', 'hello world'), lessThan(0.7));
      expect(Similarity.title('hello', 'someone like you'), lessThan(0.4));
    });

    test('word order swaps stay high', () {
      expect(Similarity.title('love me do', 'do love me'), greaterThanOrEqualTo(0.95));
    });

    test('different numbers are penalized', () {
      expect(Similarity.title('part 2', 'part 3'), lessThan(0.6));
      expect(Similarity.title('1999', '2000'), lessThan(0.5));
    });

    test('folded variants: Ålborg ≈ Aalborg', () {
      expect(Similarity.foldedTitle(TextKeys.title('Ålborg Blues'), TextKeys.title('Aalborg Blues')), 1);
    });
  });

  group('name', () {
    test('compact and token-order equality', () {
      expect(Similarity.name('ac dc', 'acdc'), 1);
      expect(Similarity.name('jay z', 'jayz'), 1);
      expect(Similarity.name('simon garfunkel', 'garfunkel simon'), 1);
    });

    test('different artists are low', () {
      expect(Similarity.name('drake', 'drakeo ruler'), lessThan(0.7));
      expect(Similarity.name('adele', 'lionel richie'), lessThan(0.5));
    });

    test('Danish/German letters match both transliterations', () {
      expect(Similarity.foldedName(TextKeys.artistName('Mø'), TextKeys.artistName('MO')), 1);
      expect(Similarity.foldedName(TextKeys.artistName('Mø'), TextKeys.artistName('Moe')), 1);
      expect(Similarity.foldedName(TextKeys.artistName('Motörhead'), TextKeys.artistName('Motorhead')), 1);
      expect(Similarity.foldedName(TextKeys.artistName('Björk'), TextKeys.artistName('Bjoerk')), 1);
    });
  });

  group('artistOverlap', () {
    ArtistOverlap overlap(List<String> pa, List<String> fa, List<String> pb, List<String> fb) =>
        Similarity.artistOverlap(primaryA: names(pa), featuredA: names(fa), primaryB: names(pb), featuredB: names(fb));

    test('featured artists are order-insensitive', () {
      final o = overlap(['Kygo'], ['Mø', 'Rogue'], ['Kygo'], ['Rogue', 'Mø']);
      expect(o.primary, 1);
      expect(o.featured, 1);
      expect(o.hasFeatured, isTrue);
    });

    test('collaborator listed as main vs featured still agrees', () {
      final o = overlap(['Calvin Harris'], ['Dua Lipa'], ['Calvin Harris', 'Dua Lipa'], []);
      expect(o.primary, 1);
      expect(o.featured, 1);
    });

    test('band names containing separators match unsplit spellings', () {
      final o = overlap(['Tyler', 'The Creator'], [], ['Tyler The Creator'], []);
      expect(o.primary, 1);
      expect(o.featured, 1);
    });

    test('missing featured artist lowers only the featured signal', () {
      final o = overlap(['Kygo'], ['Mø'], ['Kygo'], []);
      expect(o.primary, 1);
      expect(o.featured, 0);
    });

    test('different main artists are low; unknown artists are null', () {
      expect(overlap(['Adele'], [], ['Lionel Richie'], []).primary, lessThan(0.5));
      expect(overlap([], [], ['Adele'], []).primary, isNull);
      expect(overlap(['Adele'], [], ['Adele'], []).hasFeatured, isFalse);
    });
  });
}
