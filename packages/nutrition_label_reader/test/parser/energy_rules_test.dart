import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader/src/parser/energy_rules.dart';

const _box = LabelRect(left: 0.1, top: 0.2, width: 0.5, height: 0.02);

ParsedQuantity _kj(double? value, {String? raw, bool bound = false}) =>
    ParsedQuantity(
      value: value,
      unit: LabelUnit.kj,
      rawText: raw ?? '$value kJ',
      isUpperBound: bound,
    );

ParsedQuantity _kcal(double? value, {String? raw}) => ParsedQuantity(
  value: value,
  unit: LabelUnit.kcal,
  rawText: raw ?? '$value kcal',
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
  sourceBox: _box,
);

const _config = ParserConfig();

List<ParsedNutrient> _apply(List<ParsedNutrient> nutrients) =>
    applyEnergyRules(nutrients, _config);

ParsedNutrient _find(List<ParsedNutrient> list, NutrientId id) =>
    list.firstWhere((n) => n.id == id);

void main() {
  group('only kJ read (R9)', () {
    test('derives kcal, flags it and keeps the kJ value untouched', () {
      final kj = _n(NutrientId.energyKj, per100: _kj(1046, raw: '1046 kJ'));
      final result = _apply([kj, _n(NutrientId.fat)]);
      expect(result.map((n) => n.id), [
        NutrientId.energyKj,
        NutrientId.energyKcal,
        NutrientId.fat,
      ]);
      expect(result.first, kj);
      final kcal = _find(result, NutrientId.energyKcal);
      expect(kcal.per100!.value, closeTo(250, 1e-9));
      expect(kcal.per100!.unit, LabelUnit.kcal);
      expect(kcal.per100!.isDerived, isTrue);
      expect(kcal.per100!.rawText, '1046 kJ');
      expect(kcal.flags, {FieldFlag.derivedFromOtherUnit});
      expect(kcal.review, FieldReview.checkThis);
      expect(kcal.sourceBox, _box);
    });

    test('derives each slot that has a kJ value', () {
      final result = _apply([
        _n(
          NutrientId.energyKj,
          per100: _kj(1046),
          perServing: _kj(314),
          unknownBasis: _kj(523),
        ),
      ]);
      final kcal = _find(result, NutrientId.energyKcal);
      expect(kcal.per100!.value, closeTo(250, 1e-9));
      expect(kcal.perServing!.value, closeTo(314 / 4.184, 1e-9));
      expect(kcal.unknownBasis!.value, closeTo(125, 1e-9));
      expect(kcal.perServing!.isDerived, isTrue);
    });

    test('fills a kcal slot that is empty and keeps the other slot', () {
      final read = _kcal(250, raw: '250 kcal');
      final result = _apply([
        _n(NutrientId.energyKj, per100: _kj(1046), perServing: _kj(314)),
        _n(NutrientId.energyKcal, per100: read),
      ]);
      final kcal = _find(result, NutrientId.energyKcal);
      expect(kcal.per100, read);
      expect(kcal.perServing!.isDerived, isTrue);
      expect(kcal.flags, {FieldFlag.derivedFromOtherUnit});
      expect(result, hasLength(2));
    });

    test('derives zero from zero', () {
      final result = _apply([_n(NutrientId.energyKj, per100: _kj(0))]);
      expect(_find(result, NutrientId.energyKcal).per100!.value, 0);
    });

    test('copies only the column doubts of the source', () {
      final result = _apply([
        _n(
          NutrientId.energyKj,
          per100: _kj(1046),
          flags: {
            FieldFlag.columnFromOrderNotPosition,
            FieldFlag.duplicateRow,
            FieldFlag.upperBound,
          },
        ),
      ]);
      expect(_find(result, NutrientId.energyKcal).flags, {
        FieldFlag.derivedFromOtherUnit,
        FieldFlag.columnFromOrderNotPosition,
      });
    });
  });

  group('only kcal read (R10)', () {
    test('derives kJ and flags it', () {
      final result = _apply([
        _n(NutrientId.energyKcal, per100: _kcal(250, raw: '250 kcal')),
      ]);
      expect(result.map((n) => n.id), [
        NutrientId.energyKcal,
        NutrientId.energyKj,
      ]);
      final kj = _find(result, NutrientId.energyKj);
      expect(kj.per100!.value, closeTo(1046, 1e-9));
      expect(kj.per100!.unit, LabelUnit.kj);
      expect(kj.per100!.isDerived, isTrue);
      expect(kj.per100!.rawText, '250 kcal');
      expect(kj.flags, {FieldFlag.derivedFromOtherUnit});
    });
  });

  group('both read (R8)', () {
    test('leaves values that agree alone and adds no flag', () {
      final list = [
        _n(NutrientId.energyKj, per100: _kj(1046)),
        _n(NutrientId.energyKcal, per100: _kcal(250)),
      ];
      expect(_apply(list), list);
    });

    test('accepts a gap inside the tolerance', () {
      // 255 kcal is 1066.9 kJ, about 2% from 1046.
      final list = [
        _n(NutrientId.energyKj, per100: _kj(1046)),
        _n(NutrientId.energyKcal, per100: _kcal(255)),
      ];
      expect(_apply(list), list);
    });

    test('flags both when the gap is above the tolerance', () {
      final result = _apply([
        _n(NutrientId.energyKj, per100: _kj(1046)),
        _n(NutrientId.energyKcal, per100: _kcal(200)),
      ]);
      expect(result, hasLength(2));
      for (final n in result) {
        expect(n.flags, {FieldFlag.energyUnitsDisagree});
        expect(n.per100!.isDerived, isFalse);
      }
      expect(_find(result, NutrientId.energyKj).per100!.value, 1046);
      expect(_find(result, NutrientId.energyKcal).per100!.value, 200);
    });

    test('uses the tolerance from the config', () {
      final list = [
        _n(NutrientId.energyKj, per100: _kj(1046)),
        _n(NutrientId.energyKcal, per100: _kcal(255)),
      ];
      final strict = applyEnergyRules(
        list,
        const ParserConfig(energyUnitTolerance: 0.01),
      );
      expect(
        strict.every((n) => n.flags.contains(FieldFlag.energyUnitsDisagree)),
        isTrue,
      );
    });

    test('judges each slot on its own', () {
      final result = _apply([
        _n(NutrientId.energyKj, per100: _kj(1046), perServing: _kj(314)),
        _n(NutrientId.energyKcal, per100: _kcal(250), perServing: _kcal(300)),
      ]);
      expect(
        result.every((n) => n.flags.contains(FieldFlag.energyUnitsDisagree)),
        isTrue,
      );
    });

    test('flags a zero against a non-zero value', () {
      final result = _apply([
        _n(NutrientId.energyKj, per100: _kj(0)),
        _n(NutrientId.energyKcal, per100: _kcal(10)),
      ]);
      expect(result.first.flags, {FieldFlag.energyUnitsDisagree});
    });

    test('agrees on zero and zero', () {
      final list = [
        _n(NutrientId.energyKj, per100: _kj(0)),
        _n(NutrientId.energyKcal, per100: _kcal(0)),
      ];
      expect(_apply(list), list);
    });
  });

  group('what a rule does not touch', () {
    test('a value with no unit is not used', () {
      const noUnit = ParsedQuantity(value: 230, unit: null, rawText: '230');
      final list = [
        _n(
          NutrientId.energyKcal,
          perServing: noUnit,
          flags: {FieldFlag.unitMissing},
        ),
      ];
      expect(_apply(list), list);
    });

    test('an unreadable value is not used', () {
      final list = [_n(NutrientId.energyKj, per100: _kj(null, raw: '1O46 kJ'))];
      expect(_apply(list), list);
    });

    test('an upper bound is not converted', () {
      final list = [_n(NutrientId.energyKj, per100: _kj(100, bound: true))];
      expect(_apply(list), list);
    });

    test('a kcal slot that was read and rejected is not filled', () {
      final list = [
        _n(NutrientId.energyKj, per100: _kj(1046)),
        _n(NutrientId.energyKcal, per100: _kcal(null, raw: '2S0 kcal')),
      ];
      expect(_apply(list), list);
    });

    test('a label with no energy is unchanged', () {
      final list = [_n(NutrientId.fat), _n(NutrientId.protein)];
      expect(_apply(list), list);
      expect(_apply(const []), isEmpty);
    });
  });
}
