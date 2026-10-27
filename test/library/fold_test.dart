import 'package:fermata/library/text/fold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('foldForSearch', () {
    test('removes case and accents', () {
      expect(foldForSearch('Beyoncé'), 'beyonce');
      expect(foldForSearch('CAFÉ Ñandú'), 'cafe nandu');
      expect(foldForSearch('Motörhead'), 'motorhead');
      expect(foldForSearch('Straße'), 'strasse');
    });

    test('Danish letters: æ/ae, ø/o, å/aa/a', () {
      expect(foldForSearch('Ærø'), 'aero');
      expect(foldForSearch('Søren'), 'soren');
      expect(foldForSearch('Århus'), 'arhus');
      expect(foldForSearch('Aarhus'), 'arhus');
      expect(foldForSearch('Arhus'), 'arhus');
      expect(foldForSearch('Ålborg'), foldForSearch('Aalborg'));
      expect(foldForSearch('Blåbærgrød'), 'blabaergrod');
    });

    test('punctuation and apostrophes', () {
      expect(foldForSearch("Don't Stop Me Now"), 'dont stop me now');
      expect(foldForSearch('AC/DC'), 'ac dc');
      expect(foldForSearch('  Hello,   World!  '), 'hello world');
      expect(foldForSearch('Guns N’ Roses'), 'guns n roses');
    });

    test('keeps other scripts and digits', () {
      expect(foldForSearch('Кино 1985'), 'кино 1985');
      expect(foldForSearch('坂本龍一'), '坂本龍一');
    });

    test('decomposed combining marks are dropped', () {
      expect(foldForSearch('Béyoncé'), 'beyonce');
    });

    test('null/empty', () {
      expect(foldForSearch(null), '');
      expect(foldForSearch('   '), '');
      expect(searchTokens('  Søren  Kierkegaard '), ['soren', 'kierkegard']);
    });
  });
}
