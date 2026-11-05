import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader/src/parser/plausibility_rules.dart';

ParsedQuantity _q(
  double? value,
  LabelUnit? unit, {
  bool bound = false,
  bool derived = false,
}) => ParsedQuantity(
  value: value,
  unit: unit,
  rawText: '$value',
  isUpperBound: bound,
  isDerived: derived,
);

ParsedQuantity _g(double? v, {bool bound = false}) =>
    _q(v, LabelUnit.g, bound: bound);

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

const _config = ParserConfig();

List<ParsedNutrient> _apply(
  List<ParsedNutrient> nutrients, {
  ParserConfig config = _config,
}) => applyPlausibilityRules(nutrients, config);

Set<FieldFlag> _flags(List<ParsedNutrient> list, NutrientId id) =>
    list.firstWhere((n) => n.id == id).flags;

void main() {
  group('R5 value out of range, per 100 only', () {
    test('flags a macro above 100 g and keeps the value', () {
      final result = _apply([_n(NutrientId.protein, per100: _g(100.1))]);
      expect(_flags(result, NutrientId.protein), {FieldFlag.valueOutOfRange});
      expect(result.single.per100!.value, 100.1);
    });

    test('accepts the ceilings themselves', () {
      final list = [
        _n(NutrientId.fat, per100: _g(100)),
        _n(NutrientId.energyKj, per100: _q(4000, LabelUnit.kj)),
        _n(NutrientId.energyKcal, per100: _q(950, LabelUnit.kcal)),
      ];
      expect(_apply(list), list);
    });

    test('flags energy above its ceiling', () {
      final result = _apply([
        _n(NutrientId.energyKj, per100: _q(4001, LabelUnit.kj)),
        _n(NutrientId.energyKcal, per100: _q(951, LabelUnit.kcal)),
      ]);
      expect(_flags(result, NutrientId.energyKj), {FieldFlag.valueOutOfRange});
      expect(_flags(result, NutrientId.energyKcal), {
        FieldFlag.valueOutOfRange,
      });
    });

    test('flags salt above 100 g', () {
      final result = _apply([_n(NutrientId.salt, per100: _g(101))]);
      expect(_flags(result, NutrientId.salt), {FieldFlag.valueOutOfRange});
    });

    test('has no ceiling for mg nutrients', () {
      final list = [_n(NutrientId.sodium, per100: _q(99999, LabelUnit.mg))];
      expect(_apply(list), list);
    });

    test('does not judge a serving or an unknown basis', () {
      final list = [
        _n(NutrientId.protein, perServing: _g(500), unknownBasis: _g(500)),
      ];
      expect(_apply(list), list);
    });

    test('does not judge a value with no unit or no number', () {
      final list = [
        _n(NutrientId.protein, per100: _q(500, null)),
        _n(NutrientId.fat, per100: _g(null)),
      ];
      expect(_apply(list), list);
    });

    test('uses the ceilings of the config', () {
      final result = _apply([
        _n(NutrientId.protein, per100: _g(60)),
      ], config: const ParserConfig(maxGramsPer100: 50));
      expect(_flags(result, NutrientId.protein), {FieldFlag.valueOutOfRange});
    });

    test('keeps flags the nutrient already has', () {
      final result = _apply([
        _n(NutrientId.protein, per100: _g(200), flags: {FieldFlag.upperBound}),
      ]);
      expect(_flags(result, NutrientId.protein), {
        FieldFlag.upperBound,
        FieldFlag.valueOutOfRange,
      });
    });
  });

  group('R6 sub-item above its parent', () {
    test('flags saturates above fat on the child only', () {
      final result = _apply([
        _n(NutrientId.fat, per100: _g(3)),
        _n(NutrientId.saturatedFat, per100: _g(4)),
      ]);
      expect(_flags(result, NutrientId.saturatedFat), {
        FieldFlag.subItemExceedsParent,
      });
      expect(_flags(result, NutrientId.fat), isEmpty);
    });

    test('flags sugars above carbohydrate', () {
      final result = _apply([
        _n(NutrientId.carbohydrate, perServing: _g(10)),
        _n(NutrientId.sugars, perServing: _g(12)),
      ]);
      expect(_flags(result, NutrientId.sugars), {
        FieldFlag.subItemExceedsParent,
      });
    });

    test('accepts equal values and smaller children', () {
      final list = [
        _n(NutrientId.fat, per100: _g(3)),
        _n(NutrientId.saturatedFat, per100: _g(3)),
        _n(NutrientId.carbohydrate, per100: _g(10)),
        _n(NutrientId.sugars, per100: _g(2)),
      ];
      expect(_apply(list), list);
    });

    test('compares only values of the same basis', () {
      final list = [
        _n(NutrientId.fat, per100: _g(3)),
        _n(NutrientId.saturatedFat, perServing: _g(4)),
      ];
      expect(_apply(list), list);
    });

    test('compares values of an unknown basis with each other', () {
      final result = _apply([
        _n(NutrientId.fat, unknownBasis: _g(3)),
        _n(NutrientId.saturatedFat, unknownBasis: _g(4)),
      ]);
      expect(_flags(result, NutrientId.saturatedFat), {
        FieldFlag.subItemExceedsParent,
      });
    });

    test('skips a child with an upper bound or a value with no unit', () {
      final list = [
        _n(NutrientId.fat, per100: _g(3)),
        _n(NutrientId.saturatedFat, per100: _g(4, bound: true)),
        _n(NutrientId.carbohydrate, per100: _g(3)),
        _n(NutrientId.sugars, per100: _q(4, null)),
      ];
      expect(_apply(list), list);
    });

    test('flags an exact child above a parent upper bound', () {
      final result = _apply([
        _n(NutrientId.fat, per100: _g(0.5, bound: true)),
        _n(NutrientId.saturatedFat, per100: _g(0.6)),
      ]);
      expect(_flags(result, NutrientId.saturatedFat), {
        FieldFlag.subItemExceedsParent,
      });
    });

    test('skips a missing parent or an unreadable value', () {
      final list = [
        _n(NutrientId.saturatedFat, per100: _g(4)),
        _n(NutrientId.carbohydrate, per100: _g(null)),
        _n(NutrientId.sugars, per100: _g(2)),
      ];
      expect(_apply(list), list);
    });
  });

  group('R7 macro sum above 100, per 100 only', () {
    List<ParsedNutrient> macros(double fat, double carb, double protein) => [
      _n(NutrientId.fat, per100: _g(fat)),
      _n(NutrientId.carbohydrate, per100: _g(carb)),
      _n(NutrientId.protein, per100: _g(protein)),
    ];

    test('flags all three when the sum is above 100', () {
      final result = _apply(macros(40, 50, 10.5));
      for (final id in [
        NutrientId.fat,
        NutrientId.carbohydrate,
        NutrientId.protein,
      ]) {
        expect(_flags(result, id), {
          FieldFlag.macroSumExceeds100,
        }, reason: '$id');
      }
    });

    test('accepts a sum of exactly 100', () {
      final list = macros(40, 50, 10);
      expect(_apply(list), list);
    });

    test('adds the slack from the config', () {
      final list = macros(40, 50, 10.5);
      expect(_apply(list, config: const ParserConfig(macroSumSlack: 1)), list);
    });

    test('needs all three macros', () {
      final list = [
        _n(NutrientId.fat, per100: _g(90)),
        _n(NutrientId.carbohydrate, per100: _g(90)),
      ];
      expect(_apply(list), list);
    });

    test('does not judge a serving, an upper bound or a missing unit', () {
      final serving = [
        _n(NutrientId.fat, perServing: _g(90)),
        _n(NutrientId.carbohydrate, perServing: _g(90)),
        _n(NutrientId.protein, perServing: _g(90)),
      ];
      expect(_apply(serving), serving);
      final bound = [
        _n(NutrientId.fat, per100: _g(90, bound: true)),
        _n(NutrientId.carbohydrate, per100: _g(90)),
        _n(NutrientId.protein, per100: _g(90)),
      ];
      expect(
        _apply(
          bound,
        ).any((n) => n.flags.contains(FieldFlag.macroSumExceeds100)),
        isFalse,
      );
    });
  });

  group('R11 energy that does not match the macros', () {
    List<ParsedNutrient> label({
      double kcal = 250,
      double fat = 3.5,
      double carb = 60,
      double protein = 10,
      LabelUnit? kcalUnit = LabelUnit.kcal,
      bool serving = false,
    }) {
      ParsedNutrient energy(NutrientId id, ParsedQuantity q) =>
          serving ? _n(id, perServing: q) : _n(id, per100: q);
      return [
        energy(NutrientId.energyKcal, _q(kcal, kcalUnit)),
        energy(NutrientId.energyKj, _q(kcal * 4.184, LabelUnit.kj)),
        energy(NutrientId.fat, _g(fat)),
        energy(NutrientId.carbohydrate, _g(carb)),
        energy(NutrientId.protein, _g(protein)),
      ];
    }

    test('accepts a gap inside the tolerance', () {
      // 4*60 + 4*10 + 9*3.5 = 311.5. The gap to 250 is 24.6%.
      final list = label();
      expect(_apply(list), list);
    });

    test('flags both energy values when the gap is above the tolerance', () {
      // 311.5 against 240 is a 29.8% gap.
      final result = _apply(label(kcal: 240));
      expect(_flags(result, NutrientId.energyKcal), {
        FieldFlag.energyDoesNotMatchMacros,
      });
      expect(_flags(result, NutrientId.energyKj), {
        FieldFlag.energyDoesNotMatchMacros,
      });
      expect(_flags(result, NutrientId.fat), isEmpty);
    });

    test('judges a serving slot too', () {
      final result = _apply(label(kcal: 100, serving: true));
      expect(_flags(result, NutrientId.energyKcal), {
        FieldFlag.energyDoesNotMatchMacros,
      });
    });

    test('uses the tolerance from the config', () {
      final result = _apply(
        label(),
        config: const ParserConfig(atwaterTolerance: 0.1),
      );
      expect(_flags(result, NutrientId.energyKcal), {
        FieldFlag.energyDoesNotMatchMacros,
      });
    });

    test('needs all three macros, a positive energy and a kcal unit', () {
      final noProtein = label()..removeLast();
      expect(_apply(noProtein), noProtein);
      final zero = label(kcal: 0);
      expect(
        _apply(
          zero,
        ).any((n) => n.flags.contains(FieldFlag.energyDoesNotMatchMacros)),
        isFalse,
      );
      final noUnit = label(kcal: 100, kcalUnit: null);
      expect(
        _apply(
          noUnit,
        ).any((n) => n.flags.contains(FieldFlag.energyDoesNotMatchMacros)),
        isFalse,
      );
    });

    test('flags a derived kcal value as well', () {
      final list = label(kcal: 100);
      list[0] = _n(
        NutrientId.energyKcal,
        per100: _q(100, LabelUnit.kcal, derived: true),
      );
      expect(_flags(_apply(list), NutrientId.energyKcal), {
        FieldFlag.energyDoesNotMatchMacros,
      });
    });
  });

  test('a label with nothing to judge is unchanged', () {
    expect(_apply(const []), isEmpty);
    final list = [_n(NutrientId.calcium, per100: _q(120, LabelUnit.mg))];
    expect(_apply(list), list);
  });
}
