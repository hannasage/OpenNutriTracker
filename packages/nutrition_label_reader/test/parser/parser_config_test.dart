import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';

void main() {
  test('defaults match the blueprint', () {
    const config = ParserConfig();
    expect(config.minNutrientNames, 4);
    expect(config.minValues, 3);
    expect(config.atwaterTolerance, 0.25);
    expect(config.energyUnitTolerance, 0.05);
    expect(config.rowYToleranceFactor, 0.5);
  });

  test('is equal by value', () {
    expect(const ParserConfig(), const ParserConfig());
    expect(
      const ParserConfig(),
      isNot(const ParserConfig(minNutrientNames: 5)),
    );
  });

  group('isPlausible', () {
    const config = ParserConfig();

    test('applies the per 100 ceilings', () {
      expect(
        config.isPlausible(NutrientId.fat, 100, LabelBasis.per100g),
        isTrue,
      );
      expect(
        config.isPlausible(NutrientId.fat, 100.1, LabelBasis.per100g),
        isFalse,
      );
      expect(
        config.isPlausible(NutrientId.salt, 1234, LabelBasis.per100ml),
        isFalse,
      );
      expect(
        config.isPlausible(NutrientId.energyKj, 4000, LabelBasis.per100g),
        isTrue,
      );
      expect(
        config.isPlausible(NutrientId.energyKj, 4001, LabelBasis.per100g),
        isFalse,
      );
      expect(
        config.isPlausible(NutrientId.energyKcal, 950, LabelBasis.per100g),
        isTrue,
      );
      expect(
        config.isPlausible(NutrientId.energyKcal, 951, LabelBasis.per100g),
        isFalse,
      );
    });

    test('has no ceiling for mg and microgram nutrients', () {
      expect(
        config.isPlausible(NutrientId.sodium, 99999, LabelBasis.per100g),
        isTrue,
      );
      expect(
        config.isPlausible(NutrientId.vitaminD, 99999, LabelBasis.per100g),
        isTrue,
      );
    });

    test('has no ceiling for a serving or an unknown basis', () {
      expect(
        config.isPlausible(NutrientId.fat, 500, LabelBasis.perServing),
        isTrue,
      );
      expect(config.isPlausible(NutrientId.fat, 500, null), isTrue);
    });

    test('rejects a negative value', () {
      expect(
        config.isPlausible(NutrientId.fat, -1, LabelBasis.per100g),
        isFalse,
      );
    });

    test('has no energy floor by default and honours one when set', () {
      expect(
        config.isPlausible(NutrientId.energyKj, 1.234, LabelBasis.per100g),
        isTrue,
      );
      const floor = ParserConfig(minEnergyKjPer100: 100);
      expect(
        floor.isPlausible(NutrientId.energyKj, 1.234, LabelBasis.per100g),
        isFalse,
      );
      expect(
        floor.isPlausible(NutrientId.energyKj, 1234, LabelBasis.per100g),
        isTrue,
      );
    });
  });
}
