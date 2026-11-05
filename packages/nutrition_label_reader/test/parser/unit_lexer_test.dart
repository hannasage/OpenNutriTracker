import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader/src/parser/number_lexer.dart';
import 'package:nutrition_label_reader/src/parser/quantity_lexer.dart';
import 'package:nutrition_label_reader/src/parser/text_normalizer.dart';
import 'package:nutrition_label_reader/src/parser/unit_lexer.dart';

void main() {
  group('UnitLexer.parse', () {
    const cases = <String, LabelUnit>{
      'g': LabelUnit.g,
      'G': LabelUnit.g,
      'mg': LabelUnit.mg,
      'MG': LabelUnit.mg,
      'µg': LabelUnit.ug,
      'μg': LabelUnit.ug,
      'ug': LabelUnit.ug,
      'mcg': LabelUnit.ug,
      'kJ': LabelUnit.kj,
      'KJ': LabelUnit.kj,
      'kcal': LabelUnit.kcal,
      'Kcal': LabelUnit.kcal,
      'Cal': LabelUnit.kcal,
      'cal': LabelUnit.kcal,
      'ml': LabelUnit.ml,
      'mL': LabelUnit.ml,
    };
    cases.forEach((text, expected) {
      test('"$text" is $expected', () {
        expect(UnitLexer.parse(text), expected);
      });
    });

    test('unknown or empty text is null', () {
      for (final text in ['', 'q', 'gr', 'oz', 'kg', '9']) {
        expect(UnitLexer.parse(text), isNull, reason: text);
      }
    });
  });

  group('text normalizer', () {
    test('maps special spaces and both mu forms', () {
      expect(normalizeText('5 g'), '5 g');
      expect(normalizeText('5 g'), '5 g');
      expect(normalizeText('5 g'), '5 g');
      expect(normalizeText('μg'), 'µg');
      expect(normalizeText('µg'), 'µg');
    });

    test('folds for matching', () {
      expect(foldForMatching('  Total   FAT  '), 'total fat');
    });

    test('never changes letters into digits', () {
      expect(normalizeText('O l S'), 'O l S');
    });
  });

  group('QuantityLexer.read', () {
    QuantityReading read(String text, NutrientId id) =>
        QuantityLexer.read(text, id);

    test('attached and spaced units', () {
      for (final text in ['5g', '5 g', '5G', '5 g']) {
        final r = read(text, NutrientId.protein);
        expect(r.quantity.value, 5, reason: text);
        expect(r.quantity.unit, LabelUnit.g, reason: text);
        expect(r.flags, isEmpty, reason: text);
      }
    });

    test('micrograms in three spellings', () {
      for (final text in ['5 µg', '5 μg', '5 mcg', '5 ug']) {
        final r = read(text, NutrientId.vitaminD);
        expect(r.quantity.value, 5, reason: text);
        expect(r.quantity.unit, LabelUnit.ug, reason: text);
        expect(r.flags, isEmpty, reason: text);
      }
    });

    test('5 mg of sodium stays 5 mg', () {
      final r = read('5 mg', NutrientId.sodium);
      expect(r.quantity.value, 5);
      expect(r.quantity.unit, LabelUnit.mg);
    });

    test('energy units', () {
      final kj = read('1046kJ', NutrientId.energyKj);
      expect(kj.quantity.value, 1046);
      expect(kj.quantity.unit, LabelUnit.kj);
      for (final text in ['250 kcal', '250 Kcal', '250 Cal']) {
        final r = read(text, NutrientId.energyKcal);
        expect(r.quantity.value, 250, reason: text);
        expect(r.quantity.unit, LabelUnit.kcal, reason: text);
        expect(r.flags, isEmpty, reason: text);
      }
    });

    test('mg to g is exact and not flagged', () {
      final r = read('3500 mg', NutrientId.fat);
      expect(r.quantity.value, 3.5);
      expect(r.quantity.unit, LabelUnit.g);
      expect(r.flags, isEmpty);
      expect(r.quantity.rawText, '3500 mg');
    });

    test('other conversions in the same class', () {
      final sodium = read('0.35 g', NutrientId.sodium);
      expect(sodium.quantity.value, 350);
      expect(sodium.quantity.unit, LabelUnit.mg);
      final vitamin = read('0.01 mg', NutrientId.vitaminD);
      expect(vitamin.quantity.value, 10);
      expect(vitamin.quantity.unit, LabelUnit.ug);
      final iron = read('1500 µg', NutrientId.iron);
      expect(iron.quantity.value, 1.5);
      expect(iron.quantity.unit, LabelUnit.mg);
    });

    test('missing unit keeps the value and flags it', () {
      final r = read('5', NutrientId.protein);
      expect(r.quantity.value, 5);
      expect(r.quantity.unit, isNull);
      expect(r.flags, {FieldFlag.unitMissing});
    });

    test('wrong unit class drops the value', () {
      for (final (text, id) in [
        ('5 kcal', NutrientId.fat),
        ('5 kJ', NutrientId.protein),
        ('5 ml', NutrientId.carbohydrate),
        ('5 g', NutrientId.energyKcal),
        ('5 g', NutrientId.energyKj),
        ('250 kcal', NutrientId.energyKj),
        ('1046 kJ', NutrientId.energyKcal),
      ]) {
        final r = read(text, id);
        expect(r.quantity.value, isNull, reason: text);
        expect(r.flags, {FieldFlag.unitUnexpected}, reason: text);
      }
    });

    test('an unknown unit word is unreadable', () {
      final r = read('5 xyz', NutrientId.protein);
      expect(r.status, NumberStatus.unreadable);
      expect(r.quantity.value, isNull);
      expect(r.flags, {FieldFlag.unreadableNumber});
    });

    test('no repair of digits from letters', () {
      for (final text in ['1O g', 'l2 g', '3.5.2 g']) {
        final r = read(text, NutrientId.protein);
        expect(r.quantity.value, isNull, reason: text);
        expect(r.flags, {FieldFlag.unreadableNumber}, reason: text);
      }
    });

    test('upper bound keeps the value and flags it', () {
      final r = read('<0.5 g', NutrientId.fat);
      expect(r.quantity.value, 0.5);
      expect(r.quantity.isUpperBound, isTrue);
      expect(r.flags, {FieldFlag.upperBound});
      final sodium = read('< 0.1 g', NutrientId.sodium);
      expect(sodium.quantity.value, 100);
      expect(sodium.quantity.isUpperBound, isTrue);
    });

    test('trace and dash carry no value and no flag', () {
      for (final text in ['trace', '-', 'nil', 'n/a']) {
        final r = read(text, NutrientId.fat);
        expect(r.status, NumberStatus.absent, reason: text);
        expect(r.quantity.value, isNull, reason: text);
        expect(r.flags, isEmpty, reason: text);
      }
    });

    test('ambiguous comma with a unit', () {
      final r = read('1,234 g', NutrientId.fat);
      expect(r.status, NumberStatus.ambiguous);
      expect(r.quantity.value, isNull);
      expect(r.flags, {FieldFlag.ambiguousNumber});
    });

    test('plausibility is tested on the canonical value', () {
      final r = QuantityLexer.read(
        '1,234 kJ',
        NutrientId.energyKj,
        isPlausible: (v) => v > 100,
      );
      expect(r.status, NumberStatus.value);
      expect(r.quantity.value, 1234);
      expect(r.flags, isEmpty);
      final mg = QuantityLexer.read(
        '1,234 mg',
        NutrientId.fat,
        isPlausible: (v) => v > 1,
      );
      expect(mg.quantity.value, 1.234);
      expect(mg.quantity.unit, LabelUnit.g);
    });

    test('a dot before three digits is ambiguous, and a floor decides', () {
      final plain = read('1.046 kJ', NutrientId.energyKj);
      expect(plain.status, NumberStatus.ambiguous);
      expect(plain.quantity.value, isNull);
      expect(plain.flags, {FieldFlag.ambiguousNumber});
      final floor = QuantityLexer.read(
        '1.046 kJ',
        NutrientId.energyKj,
        isPlausible: (v) => v >= 100 && v <= 4000,
      );
      expect(floor.status, NumberStatus.value);
      expect(floor.quantity.value, 1046);
      expect(floor.flags, isEmpty);
    });

    test('text without digits is not numeric', () {
      final r = read('Protein', NutrientId.protein);
      expect(r.status, NumberStatus.notNumeric);
      expect(r.quantity.value, isNull);
    });

    test('raw text is a substring of the input', () {
      const input = 'x  3,5 g  y';
      final r = read(input.substring(3, 9), NutrientId.fat);
      expect(input.contains(r.quantity.rawText), isTrue);
    });
  });
}
