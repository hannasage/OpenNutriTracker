import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/styles/accent_colors.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/utils/color_contrast.dart';

/// Presets whose best on-colour still reads under 4.5:1 as a filled button
/// label. The raw swatch is kept as the fill (it is the colour the user
/// picked), so these stay slightly under the text floor. All four clear 3:1,
/// the floor for large text and icons. Same in light and dark: the on-colour
/// depends on the accent alone.
const _fillBelowTextFloor = {
  0xFFE53935, // red
  0xFF00897B, // teal
  0xFFEC407A, // pink
  0xFF1E88E5, // blue
};

double _best(Color accent) {
  final white = contrastRatio(const Color(0xFFFFFFFF), accent);
  final dark = contrastRatio(const Color(0xFF20201C), accent);
  return white > dark ? white : dark;
}

void main() {
  group('default palette is unchanged', () {
    test('light', () {
      const p = AppPalette.light;
      expect(p.brightness, Brightness.light);
      expect(p.canvas, const Color(0xFFF7F4EF));
      expect(p.surface, const Color(0xFFFFFFFF));
      expect(p.surfaceMuted, const Color(0xFFEFEAE1));
      expect(p.border, const Color(0xFFE7E1D6));
      expect(p.shadow, const Color(0x14403A2E));
      expect(p.accent, const Color(0xFF0E7A4D));
      expect(p.onAccent, const Color(0xFFFFFFFF));
      expect(p.carbsColor, const Color(0xFFB87410));
      expect(p.fatColor, const Color(0xFFD05536));
      expect(p.proteinColor, const Color(0xFF1F8E80));
      expect(p.textStrong, const Color(0xFF2B2A27));
      expect(p.textMuted, const Color(0xFF6E685E));
    });

    test('dark', () {
      const p = AppPalette.dark;
      expect(p.brightness, Brightness.dark);
      expect(p.canvas, const Color(0xFF1B1A18));
      expect(p.surface, const Color(0xFF252320));
      expect(p.surfaceMuted, const Color(0xFF302D28));
      expect(p.border, const Color(0xFF38352F));
      expect(p.shadow, const Color(0x33000000));
      expect(p.accent, const Color(0xFF34D08A));
      expect(p.onAccent, const Color(0xFF06281A));
      expect(p.carbsColor, const Color(0xFFF2B45A));
      expect(p.fatColor, const Color(0xFFFF937B));
      expect(p.proteinColor, const Color(0xFF49C9B8));
      expect(p.textStrong, const Color(0xFFECE8E1));
      expect(p.textMuted, const Color(0xFFA39E94));
    });

    test('colour scheme keeps the accent as primary and onAccent on it', () {
      expect(AppPalette.light.colorScheme.primary, const Color(0xFF0E7A4D));
      expect(AppPalette.light.colorScheme.onPrimary, const Color(0xFFFFFFFF));
      expect(AppPalette.dark.colorScheme.primary, const Color(0xFF34D08A));
      expect(AppPalette.dark.colorScheme.onPrimary, const Color(0xFF06281A));
    });

    test('the text-safe accent is the accent itself, in both modes', () {
      expect(AppPalette.light.accentText, AppPalette.light.accent);
      expect(AppPalette.dark.accentText, AppPalette.dark.accent);
    });
  });

  for (final palette in [AppPalette.light, AppPalette.dark]) {
    final mode = palette.brightness.name;

    group('all 16 presets, $mode', () {
      test('there are sixteen presets', () {
        expect(accentPresetColors, hasLength(16));
      });

      test('accentText reads at 4.5:1 on the surface and on the canvas', () {
        for (final seed in accentPresetColors) {
          final p = palette.withAccent(seed);
          final label = seed.toARGB32().toRadixString(16);
          expect(
            contrastRatio(p.accentText, p.surface),
            greaterThanOrEqualTo(4.5),
            reason: '$label on the $mode surface',
          );
          expect(
            contrastRatio(p.accentText, p.canvas),
            greaterThanOrEqualTo(4.5),
            reason: '$label on the $mode canvas',
          );
        }
      });

      test('a seed that already passes is returned unchanged', () {
        var passing = 0;
        for (final seed in accentPresetColors) {
          final p = palette.withAccent(seed);
          final ok =
              contrastRatio(seed, p.surface) >= 4.5 &&
              contrastRatio(seed, p.canvas) >= 4.5;
          if (ok) {
            passing++;
            expect(p.accentText, seed);
          } else {
            expect(p.accentText, isNot(seed));
          }
        }
        expect(passing, greaterThan(0), reason: 'the check must be live');
      });

      test('onAccent is the better of white and the dark label colour', () {
        for (final seed in accentPresetColors) {
          final p = palette.withAccent(seed);
          expect(
            contrastRatio(p.onAccent, p.accent),
            closeTo(_best(seed), 1e-9),
            reason: seed.toARGB32().toRadixString(16),
          );
          expect([const Color(0xFFFFFFFF), kOnColorDark], contains(p.onAccent));
        }
      });

      test('only the documented presets stay under 4.5:1 as a fill', () {
        final below = {
          for (final seed in accentPresetColors)
            if (contrastRatio(palette.withAccent(seed).onAccent, seed) < 4.5)
              seed.toARGB32(),
        };
        expect(below, _fillBelowTextFloor);
        for (final argb in below) {
          expect(
            contrastRatio(
              palette.withAccent(Color(argb)).onAccent,
              Color(argb),
            ),
            greaterThanOrEqualTo(3),
          );
        }
      });

      test('the raw seed stays the accent, for swatches and fills', () {
        for (final seed in accentPresetColors) {
          final p = palette.withAccent(seed);
          expect(p.accent, seed);
          expect(p.colorScheme.primary, seed);
          expect(p.colorScheme.onPrimary, p.onAccent);
        }
      });

      test('neutral roles do not move with the accent', () {
        for (final seed in accentPresetColors) {
          final p = palette.withAccent(seed);
          expect(p.canvas, palette.canvas);
          expect(p.surface, palette.surface);
          expect(p.surfaceMuted, palette.surfaceMuted);
          expect(p.border, palette.border);
          expect(p.textStrong, palette.textStrong);
          expect(p.textMuted, palette.textMuted);
          expect(p.carbsColor, palette.carbsColor);
          expect(p.fatColor, palette.fatColor);
          expect(p.proteinColor, palette.proteinColor);
        }
      });

      test('the colour scheme extension agrees with the palette', () {
        for (final seed in accentPresetColors) {
          final p = palette.withAccent(seed);
          expect(p.colorScheme.accentText, p.accentText);
        }
      });
    });
  }

  test('accentText keeps the hue family of the seed', () {
    // Yellow text turns olive, not grey or brown-red: red stays the lowest
    // channel and green stays above it.
    final p = AppPalette.light.withAccent(const Color(0xFFFDD835));
    expect(p.accentText.g, greaterThan(p.accentText.b));
    expect(p.accentText.r, greaterThan(p.accentText.b));
  });
}
