import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader/src/parser/scaling_rules.dart';

ParsedQuantity _q(
  double? value,
  LabelUnit? unit, {
  String raw = 'raw',
  bool bound = false,
  bool derived = false,
}) => ParsedQuantity(
  value: value,
  unit: unit,
  rawText: raw,
  isUpperBound: bound,
  isDerived: derived,
);

ParsedNutrient _n(
  NutrientId id, {
  ParsedQuantity? per100,
  ParsedQuantity? perServing,
  ParsedQuantity? unknownBasis,
  Set<FieldFlag> flags = const {},
}) => ParsedNutrient(
  id: id,
  per100: per100,
  perServing: perServing,
  unknownBasis: unknownBasis,
  flags: flags,
);

const _serving30 = ServingInfo(rawText: '30 g', amount: 30);

ParsedNutrient _find(List<ParsedNutrient> list, NutrientId id) =>
    list.firstWhere((n) => n.id == id);

void main() {
  group('R14 scale a per-serving-only label', () {
    test('scales each serving value to per 100 and flags it', () {
      final fat = _n(
        NutrientId.fat,
        perServing: _q(1.5, LabelUnit.g, raw: '1.5 g'),
      );
      final outcome = applyServingScaling([fat], _serving30);
      final scaled = _find(outcome.nutrients, NutrientId.fat);
      expect(scaled.perServing, fat.perServing);
      expect(scaled.per100!.value, 1.5 * 100 / 30);
      expect(scaled.per100!.unit, LabelUnit.g);
      expect(scaled.per100!.isDerived, isTrue);
      expect(scaled.per100!.rawText, '1.5 g');
      expect(scaled.flags, {FieldFlag.scaledFromServing});
      expect(scaled.review, FieldReview.checkThis);
      expect(outcome.warnings, isEmpty);
    });

    test('scales millilitre servings the same way', () {
      final outcome = applyServingScaling(
        [_n(NutrientId.sugars, perServing: _q(12, LabelUnit.g))],
        const ServingInfo(rawText: '240 ml', amount: 240, isMillilitres: true),
      );
      expect(
        _find(outcome.nutrients, NutrientId.sugars).per100!.value,
        12 * 100 / 240,
      );
    });

    test('keeps the unit and the upper bound', () {
      final outcome = applyServingScaling([
        _n(NutrientId.sodium, perServing: _q(160, LabelUnit.mg, bound: true)),
      ], _serving30);
      final q = _find(outcome.nutrients, NutrientId.sodium).per100!;
      expect(q.unit, LabelUnit.mg);
      expect(q.isUpperBound, isTrue);
      expect(q.value, 160 * 100 / 30);
    });

    test('scales a derived serving value and keeps it derived', () {
      final outcome = applyServingScaling([
        _n(
          NutrientId.salt,
          perServing: _q(0.4, LabelUnit.g, derived: true),
          flags: {FieldFlag.derivedFromOtherUnit},
        ),
      ], _serving30);
      final salt = _find(outcome.nutrients, NutrientId.salt);
      expect(salt.per100!.isDerived, isTrue);
      expect(salt.flags, {
        FieldFlag.derivedFromOtherUnit,
        FieldFlag.scaledFromServing,
      });
    });

    test('does not scale a value with no unit or no number', () {
      final list = [
        _n(NutrientId.energyKcal, perServing: _q(230, null)),
        _n(NutrientId.fat, perServing: _q(null, LabelUnit.g)),
        _n(NutrientId.protein, perServing: _q(3, LabelUnit.g)),
      ];
      final outcome = applyServingScaling(list, _serving30);
      expect(_find(outcome.nutrients, NutrientId.energyKcal).per100, isNull);
      expect(_find(outcome.nutrients, NutrientId.fat).per100, isNull);
      expect(_find(outcome.nutrients, NutrientId.fat).flags, isEmpty);
      expect(_find(outcome.nutrients, NutrientId.protein).per100, isNotNull);
    });

    test('scales a zero', () {
      final outcome = applyServingScaling([
        _n(NutrientId.transFat, perServing: _q(0, LabelUnit.g)),
      ], _serving30);
      expect(_find(outcome.nutrients, NutrientId.transFat).per100!.value, 0);
    });

    test('leaves a label that already has a per 100 value alone', () {
      final list = [
        _n(
          NutrientId.fat,
          per100: _q(3, LabelUnit.g),
          perServing: _q(1, LabelUnit.g),
        ),
        _n(NutrientId.protein, perServing: _q(3, LabelUnit.g)),
      ];
      final outcome = applyServingScaling(list, _serving30);
      expect(outcome.nutrients, list);
      expect(outcome.warnings, isEmpty);
    });

    test('leaves a label with no serving values alone', () {
      final list = [
        _n(NutrientId.fat, unknownBasis: _q(3, LabelUnit.g)),
        _n(NutrientId.protein, per100: _q(3, LabelUnit.g)),
      ];
      expect(applyServingScaling(list, _serving30).nutrients, list);
      expect(applyServingScaling(list, null).warnings, isEmpty);
      expect(applyServingScaling(const [], null).warnings, isEmpty);
    });
  });

  group('R15 no gram or millilitre serving', () {
    final list = [_n(NutrientId.fat, perServing: _q(3, LabelUnit.g))];

    test('makes no per 100 value and warns', () {
      for (final serving in [
        null,
        const ServingInfo(rawText: '1 cup'),
        const ServingInfo(rawText: '0 g', amount: 0),
        const ServingInfo(rawText: '-5 g', amount: -5),
        const ServingInfo(rawText: 'x', amount: double.nan),
      ]) {
        final outcome = applyServingScaling(list, serving);
        expect(outcome.nutrients, list, reason: '$serving');
        expect(outcome.warnings, {LabelWarning.servingSizeMissing});
      }
    });
  });
}
