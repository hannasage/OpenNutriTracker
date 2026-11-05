import 'dart:ui';

/// The dark label colour used on a light accent: a near-black with a warm
/// tint, the same one the palette already used for light accents.
const Color kOnColorDark = Color(0xFF20201C);

/// WCAG 2 minimum contrast for body text (level AA).
const double kMinTextContrast = 4.5;

/// WCAG 2 contrast ratio between two opaque colours, from 1 (equal) to 21
/// (black on white). The order of the arguments does not matter.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

/// Whichever of white or [kOnColorDark] reads better on [background], for a
/// label or icon drawn on a filled accent.
Color bestOnColor(Color background) {
  const white = Color(0xFFFFFFFF);
  return contrastRatio(white, background) >=
          contrastRatio(kOnColorDark, background)
      ? white
      : kOnColorDark;
}

/// Mixes [seed] toward [toward] in 1% steps and returns the first mix whose
/// contrast against every colour in [against] is at least [minRatio].
///
/// A seed that already passes comes back unchanged, so a colour that was
/// already readable keeps its exact value. If no mix passes, [toward] is
/// returned. The first passing step is used on purpose: it keeps as much of
/// the seed's hue as the minimum allows.
Color ensureContrast(
  Color seed, {
  required Color toward,
  required Iterable<Color> against,
  double minRatio = kMinTextContrast,
}) {
  bool passes(Color c) =>
      against.every((bg) => contrastRatio(c, bg) >= minRatio);

  if (passes(seed)) return seed;
  for (var step = 1; step < 100; step++) {
    final mixed = Color.lerp(seed, toward, step / 100)!;
    if (passes(mixed)) return mixed;
  }
  return toward;
}
