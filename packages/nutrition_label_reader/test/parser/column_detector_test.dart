import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader/src/parser/column_detector.dart';
import 'package:nutrition_label_reader/src/parser/label_row.dart';
import 'package:nutrition_label_reader/src/vocabulary/label_matcher.dart';

const _detector = ColumnDetector(LabelMatcher(englishLabelVocabulary));

/// A token 0.1 wide centred on [x].
LabelToken _tok(String text, double x, {bool estimated = false}) {
  return LabelToken(
    text: text,
    box: LabelRect(left: x - 0.05, top: 0.1, width: 0.1, height: 0.02),
    estimatedX: estimated,
  );
}

LabelRow _row(List<LabelToken> tokens) {
  final left = tokens.map((t) => t.box.left).reduce((a, b) => a < b ? a : b);
  final right = tokens.map((t) => t.box.right).reduce((a, b) => a > b ? a : b);
  return LabelRow(
    tokens: tokens,
    box: LabelRect(left: left, top: 0.1, width: right - left, height: 0.02),
  );
}

LabelRow _wide(String text, {bool estimated = true}) {
  return _row([
    LabelToken(
      text: text,
      box: const LabelRect(left: 0.1, top: 0.1, width: 0.8, height: 0.02),
      estimatedX: estimated,
    ),
  ]);
}

List<ColumnKind> _kinds(ColumnLayout layout) => [
  for (final c in layout.columns) c.kind,
];

void main() {
  group('ColumnDetector.detect', () {
    test('reads two columns, per 100 g and per serving', () {
      final layout = _detector.detect([
        _row([_tok('Per 100 g', 0.5), _tok('Per serving', 0.75)]),
        _row([_tok('Energy', 0.1), _tok('1046 kJ', 0.5), _tok('314 kJ', 0.75)]),
      ]);
      expect(_kinds(layout), [ColumnKind.per100, ColumnKind.perServing]);
      expect(layout.columns[0].basis, LabelBasis.per100g);
      expect(layout.columns[1].basis, LabelBasis.perServing);
      expect(layout.columns[0].centerX, closeTo(0.5, 1e-12));
      expect(layout.columns[0].estimatedX, isFalse);
      expect(layout.warnings, isEmpty);
      expect(layout.headerRows, [0]);
    });

    test('reads a per 100 ml header', () {
      final layout = _detector.detect([
        _row([_tok('Per 100 ml', 0.5)]),
        _row([_tok('Energy', 0.1), _tok('42 kJ', 0.5)]),
      ]);
      expect(layout.columns.single.basis, LabelBasis.per100ml);
    });

    test('orders columns by x whatever the token order', () {
      final layout = _detector.detect([
        _row([_tok('Per serving', 0.75), _tok('Per 100 g', 0.5)]),
        _row([_tok('Protein', 0.1)]),
      ]);
      expect(_kinds(layout), [ColumnKind.per100, ColumnKind.perServing]);
    });

    test('ignores a percent column with a warning', () {
      final layout = _detector.detect([
        _row([
          _tok('Per 100 g', 0.4),
          _tok('Per serving', 0.6),
          _tok('%RI*', 0.85),
        ]),
        _row([_tok('Protein', 0.1)]),
      ]);
      expect(_kinds(layout), [
        ColumnKind.per100,
        ColumnKind.perServing,
        ColumnKind.percent,
      ]);
      expect(layout.warnings, {LabelWarning.percentColumnIgnored});
      expect(layout.columns.last.basis, isNull);
    });

    test('knows the US header and its percent column', () {
      final layout = _detector.detect([
        _row([_tok('Amount per serving', 0.2), _tok('% Daily Value*', 0.85)]),
        _row([_tok('Calories', 0.1)]),
      ]);
      expect(_kinds(layout), [ColumnKind.perServing, ColumnKind.percent]);
      expect(layout.warnings, {LabelWarning.percentColumnIgnored});
    });

    test('ignores an as prepared column with a warning', () {
      final layout = _detector.detect([
        _row([_tok('Per 100 g', 0.5), _tok('As prepared', 0.75)]),
        _row([_tok('Protein', 0.1)]),
      ]);
      expect(_kinds(layout), [ColumnKind.per100, ColumnKind.prepared]);
      expect(layout.warnings, {LabelWarning.preparedColumnIgnored});
    });

    test('reads "per 100 g as prepared" as one prepared column', () {
      final layout = _detector.detect([
        _row([_tok('Per 100 g', 0.5), _tok('Per 100 g as prepared', 0.75)]),
        _row([_tok('Protein', 0.1)]),
      ]);
      expect(_kinds(layout), [ColumnKind.per100, ColumnKind.prepared]);
    });

    test('reports basisUnknown when there is no header', () {
      final layout = _detector.detect([
        _row([_tok('Energy', 0.1), _tok('1046 kJ', 0.5)]),
        _row([_tok('Protein', 0.1), _tok('5 g', 0.5)]),
      ]);
      expect(layout.columns, isEmpty);
      expect(layout.warnings, {LabelWarning.basisUnknown});
      expect(layout.headerRows, isEmpty);
    });

    test('reports basisUnknown when only a percent column has a header', () {
      final layout = _detector.detect([
        _row([_tok('% Daily Value*', 0.85)]),
        _row([_tok('Protein', 0.1)]),
      ]);
      expect(layout.warnings, {
        LabelWarning.percentColumnIgnored,
        LabelWarning.basisUnknown,
      });
    });

    test('does not take a serving size row for a header', () {
      final layout = _detector.detect([
        _row([_tok('Serving size', 0.1), _tok('30 g', 0.5)]),
        _row([_tok('Energy', 0.1), _tok('1046 kJ', 0.5)]),
      ]);
      expect(layout.columns, isEmpty);
      expect(layout.warnings, {LabelWarning.basisUnknown});
    });

    test('looks for headers only above the first nutrient row', () {
      final layout = _detector.detect([
        _row([_tok('Protein', 0.1), _tok('5 g', 0.5)]),
        _row([_tok('Per serving', 0.5)]),
      ]);
      expect(layout.columns, isEmpty);
    });

    test('splits a merged header line into estimated columns', () {
      final layout = _detector.detect([
        _wide('Per 100 g Per serving'),
        _wide('Energy 1046 kJ 314 kJ'),
      ]);
      expect(_kinds(layout), [ColumnKind.per100, ColumnKind.perServing]);
      expect(layout.columns.every((c) => c.estimatedX), isTrue);
      expect(layout.columns[0].centerX < layout.columns[1].centerX, isTrue);
    });

    test('gives no columns for no rows', () {
      final layout = _detector.detect(const []);
      expect(layout.columns, isEmpty);
      expect(layout.warnings, {LabelWarning.basisUnknown});
    });
  });

  group('ColumnDetector.assign', () {
    final twoColumns = _detector.detect([
      _row([_tok('Per 100 g', 0.5), _tok('Per serving', 0.75)]),
      _row([_tok('Protein', 0.1)]),
    ]);

    test('uses the nearest column when x is real', () {
      final a = _tok('5 g', 0.52);
      final b = _tok('1 g', 0.73);
      final result = _detector.assign(twoColumns, [a, b]);
      expect(result.byColumn, {0: a, 1: b});
      expect(result.flags, isEmpty);
      expect(result.ambiguous, isFalse);
    });

    test('keeps a lone serving value in the serving column', () {
      final b = _tok('1 g', 0.76);
      final result = _detector.assign(twoColumns, [b]);
      expect(result.byColumn, {1: b});
    });

    test('is ambiguous when two cells want one column', () {
      final result = _detector.assign(twoColumns, [
        _tok('5 g', 0.5),
        _tok('6 g', 0.52),
      ]);
      expect(result.ambiguous, isTrue);
      expect(result.byColumn, isEmpty);
      expect(result.flags, {FieldFlag.columnAmbiguous});
    });

    test('never puts a cell in a percent column', () {
      final layout = _detector.detect([
        _row([_tok('Amount per serving', 0.2), _tok('% Daily Value*', 0.85)]),
        _row([_tok('Calories', 0.1)]),
      ]);
      final cell = _tok('230', 0.8);
      final result = _detector.assign(layout, [cell]);
      expect(result.byColumn, {0: cell});
    });

    test('uses order when x is estimated and the counts match', () {
      final layout = _detector.detect([
        _wide('Per 100 g Per serving'),
        _wide('Energy 1046 kJ 314 kJ'),
      ]);
      final a = _tok('1046 kJ', 0.5, estimated: true);
      final b = _tok('314 kJ', 0.7, estimated: true);
      final result = _detector.assign(layout, [a, b]);
      expect(result.byColumn, {0: a, 1: b});
      expect(result.flags, {FieldFlag.columnFromOrderNotPosition});
    });

    test('is ambiguous when x is estimated and the counts differ', () {
      final layout = _detector.detect([
        _wide('Per 100 g Per serving'),
        _wide('Energy 1046 kJ 314 kJ 5 g'),
      ]);
      final result = _detector.assign(layout, [
        _tok('1', 0.3, estimated: true),
        _tok('2', 0.5, estimated: true),
        _tok('3', 0.7, estimated: true),
      ]);
      expect(result.ambiguous, isTrue);
      expect(result.byColumn, isEmpty);
      expect(result.flags, {FieldFlag.columnAmbiguous});
    });

    test('uses order when only the header x is estimated', () {
      final layout = _detector.detect([
        _wide('Per 100 g Per serving'),
        _row([_tok('Protein', 0.1)]),
      ]);
      final a = _tok('5 g', 0.5);
      final b = _tok('1 g', 0.75);
      final result = _detector.assign(layout, [a, b]);
      expect(result.byColumn, {0: a, 1: b});
      expect(result.flags, {FieldFlag.columnFromOrderNotPosition});
    });

    test('with no header, one cell has an unknown basis', () {
      final layout = _detector.detect([
        _row([_tok('Protein', 0.1), _tok('5 g', 0.5)]),
      ]);
      final cell = _tok('5 g', 0.5);
      final result = _detector.assign(layout, [cell]);
      expect(result.unknownBasisCell, cell);
      expect(result.byColumn, isEmpty);
      expect(result.ambiguous, isFalse);
      expect(result.flags, {FieldFlag.columnAmbiguous});
    });

    test('with no header, two cells are ambiguous', () {
      final layout = _detector.detect([
        _row([_tok('Protein', 0.1), _tok('5 g', 0.5), _tok('1 g', 0.7)]),
      ]);
      final result = _detector.assign(layout, [
        _tok('5 g', 0.5),
        _tok('1 g', 0.7),
      ]);
      expect(result.ambiguous, isTrue);
      expect(result.unknownBasisCell, isNull);
      expect(result.flags, {FieldFlag.columnAmbiguous});
    });

    test('no cells give an empty assignment', () {
      final result = _detector.assign(twoColumns, const []);
      expect(result.byColumn, isEmpty);
      expect(result.ambiguous, isFalse);
      expect(result.flags, isEmpty);
    });
  });
}
