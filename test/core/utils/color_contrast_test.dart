import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/color_contrast.dart';

void main() {
  const white = Color(0xFFFFFFFF);
  const black = Color(0xFF000000);

  group('contrastRatio', () {
    test('black on white is the WCAG maximum of 21', () {
      expect(contrastRatio(black, white), closeTo(21, 1e-9));
    });

    test('is 1 for two equal colours', () {
      expect(
        contrastRatio(const Color(0xFF0E7A4D), const Color(0xFF0E7A4D)),
        closeTo(1, 1e-9),
      );
    });

    test('does not depend on the argument order', () {
      const a = Color(0xFF0E7A4D);
      const b = Color(0xFFF7F4EF);
      expect(contrastRatio(a, b), contrastRatio(b, a));
    });

    test('matches a published value: 0E7A4D on white is 5.37', () {
      expect(
        contrastRatio(const Color(0xFF0E7A4D), white),
        closeTo(5.37, 0.005),
      );
    });
  });

  group('bestOnColor', () {
    test('picks the dark colour on a light background', () {
      expect(bestOnColor(white), kOnColorDark);
    });

    test('picks white on a dark background', () {
      expect(bestOnColor(black), white);
    });

    test('picks the one with the higher contrast, whatever the colour', () {
      for (final bg in const [
        Color(0xFFE53935),
        Color(0xFFFB8C00),
        Color(0xFF1E88E5),
        Color(0xFF34D08A),
      ]) {
        final withWhite = contrastRatio(white, bg);
        final withDark = contrastRatio(kOnColorDark, bg);
        expect(
          contrastRatio(bestOnColor(bg), bg),
          withWhite > withDark ? withWhite : withDark,
        );
      }
    });
  });

  group('ensureContrast', () {
    const surface = Color(0xFFFFFFFF);
    const canvas = Color(0xFFF7F4EF);
    const toward = Color(0xFF2B2A27);

    test('returns the seed itself when it already passes', () {
      const seed = Color(0xFF0E7A4D);
      expect(
        ensureContrast(seed, toward: toward, against: [surface, canvas]),
        seed,
      );
    });

    test('returns the seed when there is nothing to check against', () {
      const seed = Color(0xFFFDD835);
      expect(ensureContrast(seed, toward: toward, against: const []), seed);
    });

    test('mixes a failing seed until every background reaches the minimum', () {
      const seed = Color(0xFFFDD835); // yellow, 1.40:1 on white
      final out = ensureContrast(
        seed,
        toward: toward,
        against: [surface, canvas],
      );
      expect(out, isNot(seed));
      expect(contrastRatio(out, surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(out, canvas), greaterThanOrEqualTo(4.5));
    });

    test('stops at the first step that passes, not at the target', () {
      const seed = Color(0xFFFDD835);
      final out = ensureContrast(
        seed,
        toward: toward,
        against: [surface, canvas],
      );
      // A just-passing result is far from the target colour, so the text
      // keeps as much of the accent hue as the minimum allows.
      expect(contrastRatio(out, canvas), lessThan(5.0));
    });

    test('a lower minimum needs a smaller change', () {
      const seed = Color(0xFFFDD835);
      final lenient = ensureContrast(
        seed,
        toward: toward,
        against: [surface],
        minRatio: 3,
      );
      final strict = ensureContrast(
        seed,
        toward: toward,
        against: [surface],
        minRatio: 4.5,
      );
      expect(
        contrastRatio(lenient, surface),
        lessThan(contrastRatio(strict, surface)),
      );
      expect(contrastRatio(lenient, surface), greaterThanOrEqualTo(3));
    });

    test('returns the target when no mix can reach the minimum', () {
      // White toward white against white can never leave 1:1.
      expect(ensureContrast(white, toward: white, against: [white]), white);
    });
  });
}
