import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader/src/parser/label_row.dart';
import 'package:nutrition_label_reader/src/parser/row_builder.dart';

RecognizedTextBox _box(
  String text,
  double left,
  double top, {
  double width = 0.1,
  double height = 0.02,
}) {
  return RecognizedTextBox(
    text: text,
    box: LabelRect(left: left, top: top, width: width, height: height),
  );
}

List<String> _texts(List<LabelRow> rows) =>
    rows.map((row) => row.tokens.map((t) => t.text).join('|')).toList();

void main() {
  const builder = RowBuilder();

  group('RowBuilder.build', () {
    test('returns no rows for no boxes', () {
      expect(builder.build(const []), isEmpty);
    });

    test('keeps a single box as one row with one real token', () {
      final rows = builder.build([_box('Protein', 0.1, 0.1)]);
      expect(rows, hasLength(1));
      expect(rows.single.tokens.single.text, 'Protein');
      expect(rows.single.tokens.single.estimatedX, isFalse);
      expect(rows.single.tokens.single.centerX, closeTo(0.15, 1e-12));
      expect(rows.single.box.top, 0.1);
    });

    test('puts boxes in rows, top to bottom and left to right', () {
      final rows = builder.build([
        _box('10 g', 0.7, 0.30),
        _box('Fat', 0.1, 0.30),
        _box('Protein', 0.1, 0.10),
        _box('5 g', 0.5, 0.10),
        _box('4 g', 0.7, 0.10),
      ]);
      expect(_texts(rows), ['Protein|5 g|4 g', 'Fat|10 g']);
    });

    test('rebuilds rows through small vertical jitter', () {
      final random = Random(7);
      final boxes = <RecognizedTextBox>[];
      for (var r = 0; r < 6; r++) {
        for (var c = 0; c < 3; c++) {
          final jitter = (random.nextDouble() - 0.5) * 0.008;
          boxes.add(_box('r${r}c$c', 0.1 + c * 0.3, 0.1 + r * 0.04 + jitter));
        }
      }
      boxes.shuffle(Random(3));
      final rows = builder.build(boxes);
      expect(_texts(rows), [
        for (var r = 0; r < 6; r++) 'r${r}c0|r${r}c1|r${r}c2',
      ]);
    });

    test('does not merge close rows when the gap is above the tolerance', () {
      // Box height 0.02, factor 0.5, so the limit is a 0.01 centre gap.
      final apart = builder.build([
        _box('A', 0.1, 0.100),
        _box('B', 0.5, 0.115),
      ]);
      expect(apart, hasLength(2));
      final together = builder.build([
        _box('A', 0.1, 0.100),
        _box('B', 0.5, 0.108),
      ]);
      expect(together, hasLength(1));
    });

    test('uses the factor it is given', () {
      final boxes = [_box('A', 0.1, 0.100), _box('B', 0.5, 0.115)];
      expect(
        const RowBuilder(rowYToleranceFactor: 1).build(boxes),
        hasLength(1),
      );
      expect(
        const RowBuilder(rowYToleranceFactor: 0.1).build(boxes),
        hasLength(2),
      );
    });

    test('keeps two rows for a page rotated a few degrees', () {
      // A slope of 0.01 over the width. Rows are 0.04 apart.
      final rows = builder.build([
        _box('Protein', 0.1, 0.100),
        _box('5 g', 0.5, 0.104),
        _box('4 g', 0.8, 0.107),
        _box('Fat', 0.1, 0.140),
        _box('3 g', 0.5, 0.144),
        _box('2 g', 0.8, 0.147),
      ]);
      expect(_texts(rows), ['Protein|5 g|4 g', 'Fat|3 g|2 g']);
    });

    test('joins boxes closer than one median height', () {
      final rows = builder.build([
        _box('Protein', 0.1, 0.1, width: 0.10),
        _box('5', 0.21, 0.1, width: 0.01),
        _box('g', 0.225, 0.1, width: 0.01),
        _box('far', 0.6, 0.1),
      ]);
      expect(_texts(rows), ['Protein 5 g|far']);
      final joined = rows.single.tokens.first;
      expect(joined.estimatedX, isFalse);
      expect(joined.centerX, closeTo((0.1 + 0.235) / 2, 1e-12));
    });

    test('does not join boxes farther apart than one median height', () {
      final rows = builder.build([
        _box('Protein', 0.1, 0.1, width: 0.10),
        _box('5 g', 0.24, 0.1, width: 0.05),
      ]);
      expect(_texts(rows), ['Protein|5 g']);
    });

    test('drops blank text and boxes with non-finite coordinates', () {
      const nan = LabelRect(
        left: double.nan,
        top: 0.1,
        width: 0.1,
        height: 0.02,
      );
      final rows = builder.build([
        _box('   ', 0.1, 0.1),
        const RecognizedTextBox(text: 'bad', box: nan),
        _box('ok', 0.3, 0.1),
      ]);
      expect(_texts(rows), ['ok']);
    });

    test('gives the same rows for any input order', () {
      final boxes = [
        for (var r = 0; r < 5; r++)
          for (var c = 0; c < 3; c++)
            _box('r${r}c$c', 0.1 + c * 0.3, 0.1 + r * 0.05),
      ];
      final expected = _texts(builder.build(boxes));
      for (var seed = 0; seed < 5; seed++) {
        final shuffled = [...boxes]..shuffle(Random(seed));
        expect(_texts(builder.build(shuffled)), expected);
      }
    });

    test('handles boxes with zero height', () {
      final rows = builder.build([
        _box('A', 0.1, 0.1, height: 0),
        _box('B', 0.5, 0.1, height: 0),
        _box('C', 0.1, 0.2, height: 0),
      ]);
      expect(_texts(rows), ['A|B', 'C']);
    });

    test('row box is the union of its tokens', () {
      final rows = builder.build([
        _box('A', 0.1, 0.10, width: 0.1, height: 0.02),
        _box('B', 0.6, 0.11, width: 0.2, height: 0.02),
      ]);
      final box = rows.single.box;
      expect(box.left, closeTo(0.1, 1e-12));
      expect(box.right, closeTo(0.8, 1e-12));
      expect(box.top, closeTo(0.10, 1e-12));
      expect(box.bottom, closeTo(0.13, 1e-12));
    });
  });

  group('LineSplitter.split', () {
    LabelRow rowOf(String text, {double left = 0.1, double width = 0.8}) {
      return builder.build([_box(text, left, 0.1, width: width)]).single;
    }

    test('leaves a row alone when it has no quantity', () {
      final row = rowOf('Protein');
      expect(LineSplitter.split(row), row);
    });

    test('leaves a bare quantity alone', () {
      final row = rowOf('5 g');
      expect(LineSplitter.split(row), row);
    });

    test('splits a label and two quantities with estimated x', () {
      final row = rowOf('Protein 5 g 10 g', width: 0.8);
      final split = LineSplitter.split(row);
      expect(_texts([split]), ['Protein|5 g|10 g']);
      expect(split.tokens.every((t) => t.estimatedX), isTrue);
      final xs = split.tokens.map((t) => t.centerX).toList();
      expect(xs[0] < xs[1] && xs[1] < xs[2], isTrue);
      expect(xs.every((x) => x > 0.1 && x < 0.9), isTrue);
    });

    test('estimates x by character position inside the box', () {
      // "ab 1 g": 6 characters over width 0.6, left 0.
      final row = rowOf('ab 1 g', left: 0, width: 0.6);
      final split = LineSplitter.split(row);
      expect(split.tokens[0].text, 'ab');
      expect(split.tokens[0].centerX, closeTo(0.1, 1e-12));
      expect(split.tokens[1].text, '1 g');
      expect(split.tokens[1].centerX, closeTo(0.45, 1e-12));
    });

    test('takes attached units, comma decimals and upper bounds', () {
      expect(_texts([LineSplitter.split(rowOf('Total Fat 3,5g <0.5 g 12%'))]), [
        'Total Fat|3,5g|<0.5 g|12%',
      ]);
      expect(_texts([LineSplitter.split(rowOf('Sugars < 0.5 g trace'))]), [
        'Sugars|< 0.5 g|trace',
      ]);
    });

    test('keeps a vitamin name with digits as a label', () {
      expect(_texts([LineSplitter.split(rowOf('Vitamin B12 2,4 µg'))]), [
        'Vitamin B12|2,4 µg',
      ]);
    });

    test('keeps a leading dash as part of the label', () {
      expect(_texts([LineSplitter.split(rowOf('- of which sugars 4 g'))]), [
        '- of which sugars|4 g',
      ]);
    });

    test('does not attach a word that is not a unit', () {
      expect(_texts([LineSplitter.split(rowOf('Protein 5 xyz'))]), [
        'Protein|5|xyz',
      ]);
    });

    test('keeps estimatedX false for a split of one piece', () {
      final split = LineSplitter.split(rowOf('Energy'));
      expect(split.tokens.single.estimatedX, isFalse);
    });

    test('splits only tokens that need it in a multi-token row', () {
      final row = builder.build([
        _box('Protein 5 g', 0.1, 0.1, width: 0.3),
        _box('4 g', 0.7, 0.1, width: 0.1),
      ]).single;
      final split = LineSplitter.split(row);
      expect(_texts([split]), ['Protein|5 g|4 g']);
      expect(split.tokens.map((t) => t.estimatedX), [true, true, false]);
      expect(split.tokens.last.centerX, closeTo(0.75, 1e-12));
    });
  });
}
