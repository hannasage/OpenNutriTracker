import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';

const _pieces = [
  'Energy',
  'Fat',
  'Protein',
  'Salt',
  'Sodium',
  'Carbohydrate',
  'of which',
  '5 g',
  '1,234',
  '1.046',
  '<',
  '-',
  '%',
  'kJ',
  'kcal',
  '/',
  'µg',
  '9',
  'trace',
  'Per 100 g',
  'Per serving',
  'As prepared',
  '% Daily Value',
  'Serving size',
  'Servings per container',
  '',
  ' ',
  '٣',
  '\u{1F600}',
  '1O',
  '3.5.2',
  '.',
  ',',
  '1.234,5',
  '2/3 cup (55 g)',
  'n/a',
  '<<',
  '--',
  ' ',
  'μg',
  'Vitamin B12',
  'Added sugars',
  '脂肪',
];

void main() {
  test('500 random documents give a result and never throw', () {
    final random = Random(2026);
    double coordinate() {
      switch (random.nextInt(14)) {
        case 0:
          return double.nan;
        case 1:
          return double.infinity;
        case 2:
          return double.negativeInfinity;
        case 3:
          return -random.nextDouble();
        case 4:
          return 0;
        case 5:
          return 1e300;
        default:
          return random.nextDouble();
      }
    }

    String text() => List.generate(
      random.nextInt(6),
      (_) => _pieces[random.nextInt(_pieces.length)],
    ).join(random.nextBool() ? ' ' : '');
    LabelRect rect() => LabelRect(
      left: coordinate(),
      top: coordinate(),
      width: coordinate(),
      height: coordinate(),
    );

    final parsers = [
      const LabelParser(),
      const LabelParser(
        config: ParserConfig(minNutrientNames: 1, minValues: 1),
      ),
      const LabelParser(vocabularies: []),
    ];
    var parsed = 0;
    for (var i = 0; i < 500; i++) {
      final doc = RecognizedDocument(
        source: RecognitionSource.values[random.nextInt(3)],
        imageWidth: 100,
        imageHeight: 100,
        boxes: [
          for (var b = 0; b < random.nextInt(40); b++)
            RecognizedTextBox(text: text(), box: rect()),
        ],
        tables: [
          for (var t = 0; t < random.nextInt(3); t++)
            RecognizedTable(
              box: rect(),
              cells: [
                for (var c = 0; c < random.nextInt(15); c++)
                  RecognizedCell(
                    text: text(),
                    box: rect(),
                    row: random.nextInt(8) - 2,
                    column: random.nextInt(6) - 2,
                    rowSpan: random.nextInt(3),
                    columnSpan: random.nextInt(3),
                  ),
              ],
            ),
        ],
      );
      for (final parser in parsers) {
        final result = parser.parse(doc);
        expect(result, isA<LabelParseResult>());
        if (result is LabelParsed) parsed++;
      }
    }
    // The loose config lets some random text count as a panel, so the
    // extraction path runs too.
    expect(parsed, greaterThan(0));
  });

  test('random text built from label words gives a result', () {
    final random = Random(77);
    for (var i = 0; i < 200; i++) {
      final boxes = <RecognizedTextBox>[];
      for (var row = 0; row < random.nextInt(14); row++) {
        final cells = random.nextInt(4);
        for (var c = 0; c < cells; c++) {
          boxes.add(
            RecognizedTextBox(
              text: List.generate(
                1 + random.nextInt(3),
                (_) => _pieces[random.nextInt(_pieces.length)],
              ).join(' '),
              box: LabelRect(
                left: 0.05 + c * 0.25,
                top: 0.05 + row * 0.04 + random.nextDouble() * 0.004,
                width: 0.2,
                height: 0.02,
              ),
            ),
          );
        }
      }
      final doc = RecognizedDocument(
        source: RecognitionSource.androidMlKit,
        imageWidth: 100,
        imageHeight: 100,
        boxes: boxes,
      );
      expect(const LabelParser().parse(doc), isA<LabelParseResult>());
      expect(
        const LabelParser(
          config: ParserConfig(minNutrientNames: 1, minValues: 1),
        ).parse(doc),
        isA<LabelParseResult>(),
      );
    }
  });
}
