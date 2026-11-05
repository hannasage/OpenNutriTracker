import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader/src/parser/quantity_scanner.dart';

void main() {
  group('QuantityScanner.quantities', () {
    test('finds spaced and attached quantities', () {
      expect(QuantityScanner.quantities('5 g'), ['5 g']);
      expect(QuantityScanner.quantities('5g 10 mg'), ['5g', '10 mg']);
      expect(QuantityScanner.quantities('3,5 g'), ['3,5 g']);
      expect(QuantityScanner.quantities('12%'), ['12%']);
      expect(QuantityScanner.quantities('12 %'), ['12 %']);
    });

    test('takes an upper bound with or without a space', () {
      expect(QuantityScanner.quantities('<0.5 g'), ['<0.5 g']);
      expect(QuantityScanner.quantities('< 0.5 g'), ['< 0.5 g']);
    });

    test('comes apart at a slash', () {
      expect(QuantityScanner.quantities('1046 kJ / 250 kcal'), [
        '1046 kJ',
        '250 kcal',
      ]);
      expect(QuantityScanner.quantities('1046 kJ/250 kcal'), [
        '1046 kJ',
        '250 kcal',
      ]);
    });

    test('takes absent words', () {
      expect(QuantityScanner.quantities('trace'), ['trace']);
      expect(QuantityScanner.quantities('n/a'), ['n/a']);
      expect(QuantityScanner.quantities('nil'), ['nil']);
    });

    test('finds nothing in words', () {
      expect(QuantityScanner.quantities('Protein'), isEmpty);
      expect(QuantityScanner.quantities(''), isEmpty);
      expect(QuantityScanner.quantities('Vitamin B12'), isEmpty);
    });

    test('keeps a number with no unit and does not attach a non-unit', () {
      expect(QuantityScanner.quantities('5 xyz'), ['5']);
    });
  });

  group('QuantityScanner.isValueText', () {
    test('is true for quantities and lone dashes', () {
      for (final text in ['5 g', '<0.5', '12%', 'trace', '-', '1,5g']) {
        expect(QuantityScanner.isValueText(text), isTrue, reason: text);
      }
    });

    test('is false for labels', () {
      for (final text in ['Protein', '- sugars', 'Vitamin B12', '', ' ']) {
        expect(QuantityScanner.isValueText(text), isFalse, reason: text);
      }
    });
  });

  group('QuantityScanner.unitOf', () {
    test('reads the unit after the number', () {
      expect(QuantityScanner.unitOf('5 g'), LabelUnit.g);
      expect(QuantityScanner.unitOf('<0.5mg'), LabelUnit.mg);
      expect(QuantityScanner.unitOf('1046 kJ'), LabelUnit.kj);
      expect(QuantityScanner.unitOf('250 Cal'), LabelUnit.kcal);
      expect(QuantityScanner.unitOf('5'), isNull);
      expect(QuantityScanner.unitOf('12%'), isNull);
    });
  });

  group('QuantityScanner.segments with joinSlash', () {
    test('keeps slash-joined quantities in one run', () {
      const text = 'Energy 1046 kJ / 250 kcal 209 kJ / 52 kcal';
      final runs = QuantityScanner.segments(text, joinSlash: true);
      expect(
        [for (final s in runs) text.substring(s.start, s.end)],
        ['Energy', '1046 kJ / 250 kcal', '209 kJ / 52 kcal'],
      );
    });
  });
}
