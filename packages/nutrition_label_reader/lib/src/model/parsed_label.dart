import 'package:equatable/equatable.dart';

import 'field_flag.dart';
import 'label_rect.dart';

/// The basis of a nutrition column.
enum LabelBasis { per100g, per100ml, perServing }

/// A nutrient the parser can read.
enum NutrientId {
  energyKj,
  energyKcal,
  fat,
  saturatedFat,
  transFat,
  carbohydrate,
  sugars,
  fiber,
  protein,
  salt,
  sodium,
  cholesterol,
  potassium,
  calcium,
  iron,
  magnesium,
  vitaminD,
  vitaminB12,
}

/// A unit the parser accepts. [ug] is micrograms.
enum LabelUnit { g, mg, ug, kj, kcal, ml }

/// One number read from a label.
class ParsedQuantity extends Equatable {
  const ParsedQuantity({
    required this.value,
    required this.unit,
    required this.rawText,
    this.isUpperBound = false,
    this.isDerived = false,
  });

  /// Null when the number is not trustworthy.
  final double? value;

  /// Null when the label gave no unit.
  final LabelUnit? unit;

  /// The exact text the number was read from.
  final String rawText;

  /// True for a value printed with a leading `<`.
  final bool isUpperBound;

  /// True when a rule computed the value. It was not read.
  final bool isDerived;

  @override
  List<Object?> get props => [value, unit, rawText, isUpperBound, isDerived];
}

/// One nutrient found on a label.
class ParsedNutrient extends Equatable {
  const ParsedNutrient({
    required this.id,
    this.per100,
    this.perServing,
    this.flags = const {},
    this.sourceBox,
  });

  final NutrientId id;
  final ParsedQuantity? per100;
  final ParsedQuantity? perServing;
  final Set<FieldFlag> flags;

  /// The row's box, for a "show source" view.
  final LabelRect? sourceBox;

  FieldReview get review =>
      flags.isEmpty ? FieldReview.looksRight : FieldReview.checkThis;

  @override
  List<Object?> get props => [id, per100, perServing, flags, sourceBox];
}

/// The serving size printed on a label.
class ServingInfo extends Equatable {
  const ServingInfo({
    required this.rawText,
    this.amount,
    this.isMillilitres = false,
    this.servingsPerContainer,
  });

  final String rawText;

  /// Grams or millilitres. Null when the label gives neither.
  final double? amount;
  final bool isMillilitres;
  final double? servingsPerContainer;

  @override
  List<Object?> get props => [
    rawText,
    amount,
    isMillilitres,
    servingsPerContainer,
  ];
}

/// A note about the whole label.
enum LabelWarning {
  basisUnknown,
  servingSizeMissing,
  preparedColumnIgnored,
  percentColumnIgnored,
  duplicatePanelIgnored,
  languageAmbiguous,
  tableFallbackToBoxes,
}

/// A label the parser read.
class ParsedLabel extends Equatable {
  const ParsedLabel({
    required this.nutrients,
    required this.primaryBasis,
    required this.languageTag,
    this.serving,
    this.warnings = const {},
    this.ignoredRows = const [],
  });

  final List<ParsedNutrient> nutrients;
  final LabelBasis primaryBasis;

  /// The vocabulary used, for example `en`.
  final String languageTag;
  final ServingInfo? serving;
  final Set<LabelWarning> warnings;

  /// Raw text of rows that were seen and not mapped.
  final List<String> ignoredRows;

  /// The nutrient with [id], or null when the label has none.
  ParsedNutrient? nutrient(NutrientId id) {
    for (final nutrient in nutrients) {
      if (nutrient.id == id) return nutrient;
    }
    return null;
  }

  @override
  List<Object?> get props => [
    nutrients,
    primaryBasis,
    languageTag,
    serving,
    warnings,
    ignoredRows,
  ];
}
