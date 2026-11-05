import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';

const _qty = ParsedQuantity(value: 3.5, unit: LabelUnit.g, rawText: '3.5 g');
const _rect = LabelRect(left: 0.1, top: 0.2, width: 0.3, height: 0.1);

void main() {
  group('ParsedQuantity', () {
    test('defaults the optional flags to false', () {
      expect(_qty.isUpperBound, isFalse);
      expect(_qty.isDerived, isFalse);
    });

    test('is equal by value', () {
      expect(
        _qty,
        const ParsedQuantity(value: 3.5, unit: LabelUnit.g, rawText: '3.5 g'),
      );
      expect(
        _qty,
        isNot(
          const ParsedQuantity(
            value: 3.5,
            unit: LabelUnit.g,
            rawText: '3.5 g',
            isUpperBound: true,
          ),
        ),
      );
    });

    test('allows a null value and a null unit', () {
      const q = ParsedQuantity(value: null, unit: null, rawText: 'trace');
      expect(q.value, isNull);
      expect(q.unit, isNull);
    });
  });

  group('ParsedNutrient.review', () {
    test('is looksRight with no flags', () {
      const n = ParsedNutrient(id: NutrientId.protein, per100: _qty);
      expect(n.flags, isEmpty);
      expect(n.review, FieldReview.looksRight);
    });

    test('is checkThis with any flag', () {
      const n = ParsedNutrient(
        id: NutrientId.protein,
        per100: _qty,
        flags: {FieldFlag.unitMissing},
      );
      expect(n.review, FieldReview.checkThis);
    });

    test('compares flags as a set, ignoring order', () {
      const a = ParsedNutrient(
        id: NutrientId.fat,
        flags: {FieldFlag.unitMissing, FieldFlag.upperBound},
      );
      const b = ParsedNutrient(
        id: NutrientId.fat,
        flags: {FieldFlag.upperBound, FieldFlag.unitMissing},
      );
      expect(a, b);
      expect(a, isNot(const ParsedNutrient(id: NutrientId.fat)));
    });

    test('keeps a value of unknown basis in its own slot', () {
      const n = ParsedNutrient(id: NutrientId.fat, unknownBasis: _qty);
      expect(n.unknownBasis, _qty);
      expect(n.per100, isNull);
      expect(n.perServing, isNull);
      expect(n, isNot(const ParsedNutrient(id: NutrientId.fat)));
      expect(n, const ParsedNutrient(id: NutrientId.fat, unknownBasis: _qty));
    });

    test('keeps the source box', () {
      const n = ParsedNutrient(id: NutrientId.fat, sourceBox: _rect);
      expect(n.sourceBox, _rect);
    });
  });

  group('ServingInfo', () {
    test('defaults', () {
      const s = ServingInfo(rawText: '30 g');
      expect(s.amount, isNull);
      expect(s.isMillilitres, isFalse);
      expect(s.servingsPerContainer, isNull);
      expect(s, const ServingInfo(rawText: '30 g'));
      expect(s, isNot(const ServingInfo(rawText: '30 g', amount: 30)));
    });
  });

  group('ParsedLabel', () {
    const protein = ParsedNutrient(id: NutrientId.protein, per100: _qty);
    const fat = ParsedNutrient(id: NutrientId.fat);
    const label = ParsedLabel(
      nutrients: [protein, fat],
      primaryBasis: LabelBasis.per100g,
      languageTag: 'en',
    );

    test('finds a nutrient by id', () {
      expect(label.nutrient(NutrientId.protein), protein);
      expect(label.nutrient(NutrientId.fat), fat);
    });

    test('returns null for a missing nutrient', () {
      expect(label.nutrient(NutrientId.salt), isNull);
    });

    test('defaults warnings and ignored rows to empty', () {
      expect(label.warnings, isEmpty);
      expect(label.ignoredRows, isEmpty);
      expect(label.serving, isNull);
    });

    test('is equal by value', () {
      const same = ParsedLabel(
        nutrients: [protein, fat],
        primaryBasis: LabelBasis.per100g,
        languageTag: 'en',
      );
      const other = ParsedLabel(
        nutrients: [protein, fat],
        primaryBasis: LabelBasis.perServing,
        languageTag: 'en',
      );
      expect(label, same);
      expect(label, isNot(other));
    });
  });

  group('LabelParseResult', () {
    test('LabelParsed wraps a label', () {
      const label = ParsedLabel(
        nutrients: [],
        primaryBasis: LabelBasis.per100g,
        languageTag: 'en',
      );
      const result = LabelParsed(label);
      expect(result.label, label);
      expect(result, const LabelParsed(label));
    });

    test('LabelNotRead carries the reason and the counts', () {
      const result = LabelNotRead(
        reason: LabelFailureReason.noEnergyRow,
        nameMatches: 5,
        valueMatches: 4,
      );
      expect(result.reason, LabelFailureReason.noEnergyRow);
      expect(result.nameMatches, 5);
      expect(result.valueMatches, 4);
      expect(
        result,
        const LabelNotRead(
          reason: LabelFailureReason.noEnergyRow,
          nameMatches: 5,
          valueMatches: 4,
        ),
      );
    });

    test('a switch over the sealed type needs no default', () {
      const LabelParseResult result = LabelNotRead(
        reason: LabelFailureReason.noText,
        nameMatches: 0,
        valueMatches: 0,
      );
      final text = switch (result) {
        LabelParsed() => 'parsed',
        LabelNotRead(:final reason) => reason.name,
      };
      expect(text, 'noText');
    });
  });

  test('enums list the blueprint values', () {
    expect(LabelBasis.values.map((e) => e.name), [
      'per100g',
      'per100ml',
      'perServing',
      'unknown',
    ]);
    expect(LabelUnit.values.map((e) => e.name), [
      'g',
      'mg',
      'ug',
      'kj',
      'kcal',
      'ml',
    ]);
    expect(NutrientId.values, hasLength(18));
    expect(FieldFlag.values, hasLength(16));
    expect(LabelWarning.values, hasLength(7));
    expect(LabelFailureReason.values, hasLength(5));
  });
}
