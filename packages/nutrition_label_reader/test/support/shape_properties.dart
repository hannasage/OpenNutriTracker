import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';

import '../fixtures/fixture_builder.dart';

const _parser = LabelParser();

/// The three shapes a fixture takes, by name.
Map<String, RecognizedDocument> shapesOf(FixtureGrid grid) => {
  'table': grid.asTable(),
  'separate boxes': grid.asSeparateBoxes(),
  'merged lines': grid.asMergedLines(),
};

ParsedLabel parsedLabel(RecognizedDocument document, {LabelParser? parser}) {
  final result = (parser ?? _parser).parse(document);
  expect(result, isA<LabelParsed>(), reason: '$result');
  return (result as LabelParsed).label;
}

/// id to (per 100 value, per serving value).
Map<NutrientId, (double?, double?)> valuesOf(ParsedLabel label) => {
  for (final n in label.nutrients) n.id: (n.per100?.value, n.perServing?.value),
};

/// Everything a parse reports except the order-from-position flag, which only
/// the merged-line shape may add.
Set<FieldFlag> _flagsWithoutOrder(ParsedNutrient n) =>
    n.flags.difference({FieldFlag.columnFromOrderNotPosition});

/// Registers the checks that hold for every fixture:
/// - the three shapes agree on nutrients, values, units, flags (except the
///   order flag), warnings, serving and ignored rows;
/// - only the merged-line shape reads columns from order;
/// - every value read is text from the input;
/// - the confidence of the observation changes nothing;
/// - the order of boxes and cells changes nothing.
void registerShapeProperties(FixtureGrid grid) {
  Map<String, ParsedLabel> parseAll() => {
    for (final entry in shapesOf(grid).entries)
      entry.key: parsedLabel(entry.value),
  };

  test('the three shapes agree on values, flags and warnings', () {
    final labels = parseAll();
    final table = labels['table']!;
    for (final entry in labels.entries) {
      final label = entry.value;
      expect(valuesOf(label), valuesOf(table), reason: entry.key);
      expect(label.primaryBasis, table.primaryBasis, reason: entry.key);
      expect(label.serving, table.serving, reason: entry.key);
      expect(label.warnings, table.warnings, reason: entry.key);
      expect(label.ignoredRows, table.ignoredRows, reason: entry.key);
      expect(
        label.nutrients.map((n) => n.id).toSet(),
        table.nutrients.map((n) => n.id).toSet(),
        reason: entry.key,
      );
      for (final n in label.nutrients) {
        final other = table.nutrient(n.id)!;
        expect(_flagsWithoutOrder(n), _flagsWithoutOrder(other));
        expect(n.per100?.unit, other.per100?.unit);
        expect(n.perServing?.unit, other.perServing?.unit);
        expect(n.unknownBasis?.unit, other.unknownBasis?.unit);
        expect(n.per100?.isDerived, other.per100?.isDerived);
        expect(n.per100?.isUpperBound, other.per100?.isUpperBound);
      }
    }
  });

  test('only the merged-line shape reads columns from order', () {
    for (final entry in parseAll().entries) {
      final flagged = entry.value.nutrients.any(
        (n) => n.flags.contains(FieldFlag.columnFromOrderNotPosition),
      );
      expect(flagged, entry.key == 'merged lines', reason: entry.key);
    }
  });

  test('every value read is text that is in the input', () {
    for (final entry in parseAll().entries) {
      for (final n in entry.value.nutrients) {
        for (final q in [n.per100, n.perServing, n.unknownBasis]) {
          if (q == null || q.isDerived) continue;
          expect(
            grid.allText.contains(q.rawText),
            isTrue,
            reason: '${entry.key}: "${q.rawText}"',
          );
        }
      }
    }
  });

  test('the confidence of the observation changes nothing', () {
    expect(
      _parser.parse(grid.asTable(observationConfidence: 0.05)),
      _parser.parse(grid.asTable(observationConfidence: 0.99)),
    );
    expect(
      _parser.parse(grid.asSeparateBoxes(observationConfidence: 0.05)),
      _parser.parse(grid.asSeparateBoxes()),
    );
    expect(
      _parser.parse(grid.asMergedLines(observationConfidence: 0.05)),
      _parser.parse(grid.asMergedLines()),
    );
  });

  test('the order of boxes and cells changes nothing', () {
    final table = grid.asTable();
    final shuffledTable = RecognizedDocument(
      source: table.source,
      imageWidth: table.imageWidth,
      imageHeight: table.imageHeight,
      boxes: [...table.boxes]..shuffle(Random(1)),
      tables: [
        for (final t in table.tables)
          RecognizedTable(box: t.box, cells: [...t.cells]..shuffle(Random(2))),
      ],
    );
    expect(_parser.parse(shuffledTable), _parser.parse(table));
    for (final doc in [grid.asSeparateBoxes(), grid.asMergedLines()]) {
      final shuffled = RecognizedDocument(
        source: doc.source,
        imageWidth: doc.imageWidth,
        imageHeight: doc.imageHeight,
        boxes: [...doc.boxes]..shuffle(Random(3)),
      );
      expect(_parser.parse(shuffled), _parser.parse(doc));
    }
  });
}
