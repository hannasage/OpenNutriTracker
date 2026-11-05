import 'package:equatable/equatable.dart';

import 'parsed_label.dart';

/// Why a label was not read.
enum LabelFailureReason {
  /// There were no text boxes.
  noText,

  /// Too few nutrient names or numbers.
  noNutritionPanel,

  /// A panel was found with no kJ or kcal value.
  noEnergyRow,

  /// Names were found and every value was rejected.
  noReadableValues,

  /// No vocabulary matched enough names.
  unsupportedLanguage,
}

/// The result of a parse.
sealed class LabelParseResult extends Equatable {
  const LabelParseResult();
}

/// The parser read a label.
class LabelParsed extends LabelParseResult {
  const LabelParsed(this.label);

  final ParsedLabel label;

  @override
  List<Object?> get props => [label];
}

/// The parser did not read a label. The counts let a UI say what was seen.
class LabelNotRead extends LabelParseResult {
  const LabelNotRead({
    required this.reason,
    required this.nameMatches,
    required this.valueMatches,
  });

  final LabelFailureReason reason;
  final int nameMatches;
  final int valueMatches;

  @override
  List<Object?> get props => [reason, nameMatches, valueMatches];
}
