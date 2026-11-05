import 'package:equatable/equatable.dart';

import '../model/parsed_label.dart';

/// Tuning values for [LabelParser].
///
/// None of these values is checked against real labels. No label photo set
/// exists yet. Each one is a starting point to tune, not a fact.
class ParserConfig extends Equatable {
  const ParserConfig({
    this.minNutrientNames = 4,
    this.minValues = 3,
    this.atwaterTolerance = 0.25,
    this.energyUnitTolerance = 0.05,
    this.rowYToleranceFactor = 0.5,
    this.maxEnergyKjPer100 = 4000,
    this.maxEnergyKcalPer100 = 950,
    this.maxGramsPer100 = 100,
    this.minEnergyKjPer100 = 0,
    this.minEnergyKcalPer100 = 0,
    this.macroSumSlack = 0,
  });

  /// Matched nutrient names a panel needs. Unverified tuning value.
  final int minNutrientNames;

  /// Numbers a panel needs. Unverified tuning value.
  final int minValues;

  /// Relative gap between declared energy and energy from macros. The app uses
  /// the same number for food data
  /// (lib/features/add_meal/domain/entity/meal_nutriments_entity.dart:404).
  /// Unverified for printed labels.
  final double atwaterTolerance;

  /// Relative gap between kJ and kcal read from one row. Unverified tuning
  /// value. Nothing in the repo or the notes says what real labels need.
  final double energyUnitTolerance;

  /// A box joins a row within this factor times the median box height.
  /// Unverified tuning value.
  final double rowYToleranceFactor;

  /// Highest plausible kJ per 100 g or 100 ml. Unverified tuning value.
  final double maxEnergyKjPer100;

  /// Highest plausible kcal per 100 g or 100 ml. Unverified tuning value.
  final double maxEnergyKcalPer100;

  /// Highest plausible grams per 100 g or 100 ml, for every nutrient kept in
  /// grams. Unverified tuning value.
  final double maxGramsPer100;

  /// Lowest plausible kJ per 100 g or 100 ml. Zero means no floor. No floor is
  /// known, so the default is zero. Set one only after measuring real labels.
  final double minEnergyKjPer100;

  /// Lowest plausible kcal per 100 g or 100 ml. Zero means no floor. See
  /// [minEnergyKjPer100].
  final double minEnergyKcalPer100;

  /// Whether [canonicalValue] can be right for [id] on a label with [basis].
  ///
  /// The lexer uses this to decide a number that reads two ways, such as
  /// `1,234`. Only a per 100 g or per 100 ml basis has limits. For a serving
  /// or an unknown basis the answer is true for any value not below zero, so
  /// both readings stay plausible and the number stays ambiguous.
  bool isPlausible(NutrientId id, double canonicalValue, LabelBasis? basis) {
    if (canonicalValue < 0) return false;
    if (basis != LabelBasis.per100g && basis != LabelBasis.per100ml) {
      return true;
    }
    switch (id) {
      case NutrientId.energyKj:
        return canonicalValue >= minEnergyKjPer100 &&
            canonicalValue <= maxEnergyKjPer100;
      case NutrientId.energyKcal:
        return canonicalValue >= minEnergyKcalPer100 &&
            canonicalValue <= maxEnergyKcalPer100;
      case NutrientId.fat:
      case NutrientId.saturatedFat:
      case NutrientId.transFat:
      case NutrientId.carbohydrate:
      case NutrientId.sugars:
      case NutrientId.fiber:
      case NutrientId.protein:
      case NutrientId.salt:
        return canonicalValue <= maxGramsPer100;
      case NutrientId.sodium:
      case NutrientId.cholesterol:
      case NutrientId.potassium:
      case NutrientId.calcium:
      case NutrientId.iron:
      case NutrientId.magnesium:
      case NutrientId.vitaminD:
      case NutrientId.vitaminB12:
        return true;
    }
  }

  /// Grams added to 100 before the macro sum counts as too high. Zero means no
  /// slack. No slack is known, so the default is zero. Unverified tuning
  /// value.
  final double macroSumSlack;

  @override
  List<Object?> get props => [
    minNutrientNames,
    minValues,
    atwaterTolerance,
    energyUnitTolerance,
    rowYToleranceFactor,
    maxEnergyKjPer100,
    maxEnergyKcalPer100,
    maxGramsPer100,
    minEnergyKjPer100,
    minEnergyKcalPer100,
    macroSumSlack,
  ];
}
