// SYNTHETIC. Hand-written OCR-style data. Not from a real product and
// not from a real recognition run.

import 'fixture_builder.dart';

/// Fixture 8: one column per serving, serving size 30 g.
const perServingScaled = FixtureGrid([
  ['Test cereal'],
  ['Serving size', '30 g'],
  ['', 'Per serving'],
  ['Energy', '392 kJ / 94 kcal'],
  ['Fat', '1.1 g'],
  ['Carbohydrate', '18 g'],
  ['Protein', '3 g'],
]);

/// Fixture 9: one column per serving, serving size 1 cup (no gram or
/// millilitre amount).
const perServingCup = FixtureGrid([
  ['Test cereal'],
  ['Serving size', '1 cup'],
  ['', 'Per serving'],
  ['Energy', '392 kJ / 94 kcal'],
  ['Fat', '1.1 g'],
  ['Carbohydrate', '18 g'],
  ['Protein', '3 g'],
]);
