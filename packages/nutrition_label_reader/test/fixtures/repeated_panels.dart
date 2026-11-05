// SYNTHETIC. Hand-written OCR-style data. Not from a real product and
// not from a real recognition run.

import 'fixture_builder.dart';

/// Fixture 10: the same panel printed twice, as on a label with two
/// languages whose words match. The second panel has other numbers, so a test
/// can tell which one was read.
const repeatedPanels = FixtureGrid([
  ['Test cereal'],
  ['', 'Per 100 g'],
  ['Energy', '1300 kJ / 311 kcal'],
  ['Fat', '3.5 g'],
  ['Carbohydrate', '60 g'],
  ['Protein', '10 g'],
  ['', 'Per 100 g'],
  ['Energy', '1200 kJ / 287 kcal'],
  ['Fat', '9 g'],
  ['Carbohydrate', '50 g'],
  ['Protein', '8 g'],
]);
