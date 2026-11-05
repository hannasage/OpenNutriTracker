import '../model/field_flag.dart';
import '../model/parsed_label.dart';
import 'text_normalizer.dart';

/// A value after unit rules ran.
class UnitOutcome {
  const UnitOutcome({this.value, this.unit, this.flags = const {}});

  /// Null when the unit makes the value untrustworthy.
  final double? value;
  final LabelUnit? unit;
  final Set<FieldFlag> flags;
}

/// Reads units and applies unit rules. Pure and total.
class UnitLexer {
  const UnitLexer._();

  /// Parses a unit word. Case does not matter. `cal` means kcal. Returns null
  /// for any other text.
  static LabelUnit? parse(String text) {
    switch (normalizeText(text).trim().toLowerCase()) {
      case 'g':
        return LabelUnit.g;
      case 'mg':
        return LabelUnit.mg;
      case 'µg':
      case 'ug':
      case 'mcg':
        return LabelUnit.ug;
      case 'kj':
        return LabelUnit.kj;
      case 'kcal':
      case 'cal':
        return LabelUnit.kcal;
      case 'ml':
        return LabelUnit.ml;
    }
    return null;
  }

  /// The unit a nutrient is kept in.
  static LabelUnit canonicalUnit(NutrientId id) {
    switch (id) {
      case NutrientId.energyKj:
        return LabelUnit.kj;
      case NutrientId.energyKcal:
        return LabelUnit.kcal;
      case NutrientId.fat:
      case NutrientId.saturatedFat:
      case NutrientId.transFat:
      case NutrientId.carbohydrate:
      case NutrientId.sugars:
      case NutrientId.fiber:
      case NutrientId.protein:
      case NutrientId.salt:
        return LabelUnit.g;
      case NutrientId.sodium:
      case NutrientId.cholesterol:
      case NutrientId.potassium:
      case NutrientId.calcium:
      case NutrientId.iron:
      case NutrientId.magnesium:
        return LabelUnit.mg;
      case NutrientId.vitaminD:
      case NutrientId.vitaminB12:
        return LabelUnit.ug;
    }
  }

  /// Applies the unit rules to a value read for [id].
  ///
  /// - No unit: the value stays and the result carries `unitMissing`.
  /// - A unit of the wrong class: no value and `unitUnexpected`.
  /// - Mass units convert exactly to the canonical unit with no flag.
  static UnitOutcome canonicalize(
    NutrientId id,
    double value,
    LabelUnit? unit,
  ) {
    if (unit == null) {
      return UnitOutcome(value: value, flags: {FieldFlag.unitMissing});
    }
    final target = canonicalUnit(id);
    if (unit == target) return UnitOutcome(value: value, unit: unit);
    final fromMicro = _microgramsPerUnit[unit];
    final toMicro = _microgramsPerUnit[target];
    if (fromMicro == null || toMicro == null) {
      return UnitOutcome(unit: unit, flags: {FieldFlag.unitUnexpected});
    }
    final converted = value * fromMicro / toMicro;
    // Drop floating-point noise from the division.
    final clean = double.parse(converted.toStringAsPrecision(12));
    return UnitOutcome(value: clean, unit: target);
  }

  static const _microgramsPerUnit = {
    LabelUnit.ug: 1,
    LabelUnit.mg: 1000,
    LabelUnit.g: 1000000,
  };
}
