import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';

import '../fixtures/comma_decimals.dart';
import '../fixtures/duplicate_rows.dart';
import '../fixtures/eu_one_column.dart';
import '../fixtures/eu_two_column.dart';
import '../fixtures/fixture_builder.dart';
import '../fixtures/kj_only.dart';
import '../fixtures/mg_versus_g.dart';
import '../fixtures/missing_salt.dart';
import '../fixtures/per_serving_scaled.dart';
import '../fixtures/repeated_panels.dart';
import '../fixtures/upper_bounds.dart';
import '../fixtures/us_style.dart';
import '../support/shape_properties.dart';

void expectValues(FixtureGrid grid, Map<NutrientId, (double?, double?)> want) {
  for (final entry in shapesOf(grid).entries) {
    expect(valuesOf(parsedLabel(entry.value)), want, reason: entry.key);
  }
}

void main() {
  final all = <String, FixtureGrid>{
    '1 EU two columns': euTwoColumn,
    '2 EU one column': euOneColumn,
    '3 US style': usStyle,
    '4 comma decimals': commaDecimals,
    '5 mg versus g': mgVersusG,
    '6 kJ only': kjOnly,
    '7 no salt and no sodium': missingSalt,
    '8 per serving, 30 g': perServingScaled,
    '9 per serving, 1 cup': perServingCup,
    '10 repeated panels': repeatedPanels,
    '11 upper bounds': upperBounds,
    '12 duplicate rows': duplicateRows,
  };

  group('properties of every fixture', () {
    all.forEach((name, grid) {
      group(name, () => registerShapeProperties(grid));
    });
  });

  group('fixture 4: comma decimals', () {
    test('reads every comma as a decimal point', () {
      expectValues(commaDecimals, {
        NutrientId.energyKj: (1300, 392),
        NutrientId.energyKcal: (311, 94),
        NutrientId.fat: (3.5, 1.1),
        NutrientId.saturatedFat: (1.2, 0.4),
        NutrientId.carbohydrate: (60, 18),
        NutrientId.sugars: (12.5, 3.8),
        NutrientId.fiber: (8.2, 2.5),
        NutrientId.protein: (10.5, 3.2),
        NutrientId.salt: (0.5, 0.15),
        NutrientId.sodium: (0.5 * 1000 / 2.5, 0.15 * 1000 / 2.5),
      });
    });

    test('keeps the text it read, comma and all', () {
      final label = parsedLabel(commaDecimals.asTable());
      expect(label.nutrient(NutrientId.fat)!.per100!.rawText, '3,5 g');
      expect(label.nutrient(NutrientId.protein)!.perServing!.rawText, '3,2 g');
    });

    test('has no ambiguous value', () {
      for (final entry in shapesOf(commaDecimals).entries) {
        for (final n in parsedLabel(entry.value).nutrients) {
          expect(
            n.flags.contains(FieldFlag.ambiguousNumber),
            isFalse,
            reason: '${entry.key} ${n.id}',
          );
        }
      }
    });
  });

  group('fixture 5: mg versus g', () {
    test('converts to the canonical unit without a flag', () {
      for (final entry in shapesOf(mgVersusG).entries) {
        final label = parsedLabel(entry.value);
        void expectRead(NutrientId id, double value, LabelUnit unit) {
          final n = label.nutrient(id)!;
          expect(n.per100!.value, value, reason: '${entry.key} $id');
          expect(n.per100!.unit, unit, reason: '${entry.key} $id');
          expect(
            n.flags.difference({FieldFlag.columnFromOrderNotPosition}),
            isEmpty,
            reason: '${entry.key} $id',
          );
        }

        expectRead(NutrientId.fat, 3.5, LabelUnit.g);
        expectRead(NutrientId.calcium, 120, LabelUnit.mg);
        expectRead(NutrientId.potassium, 300, LabelUnit.mg);
        expectRead(NutrientId.vitaminD, 10, LabelUnit.ug);
        expectRead(NutrientId.iron, 1.5, LabelUnit.mg);
      }
    });

    test('keeps the text as printed', () {
      final label = parsedLabel(mgVersusG.asTable());
      expect(label.nutrient(NutrientId.fat)!.per100!.rawText, '3500 mg');
      expect(label.nutrient(NutrientId.iron)!.per100!.rawText, '1500 µg');
    });
  });

  group('fixture 10: repeated panels', () {
    test('the first panel wins and the label says so', () {
      for (final entry in shapesOf(repeatedPanels).entries) {
        final label = parsedLabel(entry.value);
        expect(
          label.warnings,
          contains(LabelWarning.duplicatePanelIgnored),
          reason: entry.key,
        );
        expect(label.nutrient(NutrientId.fat)!.per100!.value, 3.5);
        expect(label.nutrient(NutrientId.protein)!.per100!.value, 10);
        expect(label.nutrient(NutrientId.energyKj)!.per100!.value, 1300);
        for (final n in label.nutrients) {
          expect(n.flags.contains(FieldFlag.duplicateRow), isFalse);
        }
      }
    });
  });

  group('fixture 11: upper bounds', () {
    test('keeps the value, marks the bound and flags it', () {
      for (final entry in shapesOf(upperBounds).entries) {
        final label = parsedLabel(entry.value);
        final fat = label.nutrient(NutrientId.fat)!;
        expect(fat.per100!.value, 0.5, reason: entry.key);
        expect(fat.per100!.isUpperBound, isTrue, reason: entry.key);
        expect(fat.flags, contains(FieldFlag.upperBound));
        final saturates = label.nutrient(NutrientId.saturatedFat)!;
        expect(saturates.per100!.value, 0.1, reason: entry.key);
        expect(saturates.per100!.isUpperBound, isTrue);
        expect(saturates.per100!.rawText, '<0.1 g');
        expect(
          label.nutrient(NutrientId.protein)!.per100!.isUpperBound,
          isFalse,
        );
      }
    });

    test('a bound is never turned into zero or into an exact value', () {
      final fat = parsedLabel(upperBounds.asTable()).nutrient(NutrientId.fat)!;
      expect(fat.per100!.value, isNot(0));
      expect(fat.review, FieldReview.checkThis);
    });

    test('no rule uses a bound as an exact value', () {
      for (final entry in shapesOf(upperBounds).entries) {
        for (final n in parsedLabel(entry.value).nutrients) {
          expect(
            n.flags.contains(FieldFlag.macroSumExceeds100) ||
                n.flags.contains(FieldFlag.subItemExceedsParent) ||
                n.flags.contains(FieldFlag.energyDoesNotMatchMacros),
            isFalse,
            reason: '${entry.key} ${n.id}',
          );
        }
      }
    });
  });

  group('fixture 12: duplicate rows', () {
    test('the first row wins and the nutrient is flagged', () {
      for (final entry in shapesOf(duplicateRows).entries) {
        final label = parsedLabel(entry.value);
        final protein = label.nutrient(NutrientId.protein)!;
        final fat = label.nutrient(NutrientId.fat)!;
        expect(protein.per100!.value, 10, reason: entry.key);
        expect(fat.per100!.value, 3.5, reason: entry.key);
        expect(protein.flags, contains(FieldFlag.duplicateRow));
        expect(fat.flags, contains(FieldFlag.duplicateRow));
        expect(
          label
              .nutrient(NutrientId.carbohydrate)!
              .flags
              .contains(FieldFlag.duplicateRow),
          isFalse,
        );
        expect(label.warnings, isEmpty);
      }
    });
  });
}
