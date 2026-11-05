import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/styles/accent_colors.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';

void main() {
  for (final palette in [AppPalette.light, AppPalette.dark]) {
    final mode = palette.brightness.name;

    group('buildAppTheme with every preset, $mode', () {
      test('paints text buttons with accentText', () {
        for (final seed in accentPresetColors) {
          final p = palette.withAccent(seed);
          final style = buildAppTheme(p).textButtonTheme.style!;
          expect(style.foregroundColor!.resolve({}), p.accentText);
        }
      });

      test('keeps fills on the raw accent with their on-colour', () {
        for (final seed in accentPresetColors) {
          final p = palette.withAccent(seed);
          final theme = buildAppTheme(p);
          expect(theme.colorScheme.primary, seed);
          expect(theme.floatingActionButtonTheme.backgroundColor, seed);
          expect(theme.floatingActionButtonTheme.foregroundColor, p.onAccent);
          final filled = theme.filledButtonTheme.style!;
          expect(filled.backgroundColor!.resolve({}), seed);
          expect(filled.foregroundColor!.resolve({}), p.onAccent);
        }
      });
    });
  }

  test('the default theme paints text buttons exactly as before', () {
    expect(
      buildAppTheme(
        AppPalette.light,
      ).textButtonTheme.style!.foregroundColor!.resolve({}),
      const Color(0xFF0E7A4D),
    );
    expect(
      buildAppTheme(
        AppPalette.dark,
      ).textButtonTheme.style!.foregroundColor!.resolve({}),
      const Color(0xFF34D08A),
    );
  });
}
