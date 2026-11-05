/// Why a field needs a second look. A UI never shows these names. It shows
/// [FieldReview].
enum FieldFlag {
  unitMissing,
  unitUnexpected,
  ambiguousNumber,
  unreadableNumber,
  valueOutOfRange,
  subItemExceedsParent,
  macroSumExceeds100,
  energyUnitsDisagree,
  energyDoesNotMatchMacros,
  columnFromOrderNotPosition,
  columnAmbiguous,
  duplicateRow,
  upperBound,
  derivedFromOtherUnit,
  scaledFromServing,
  labelFuzzyMatch,
}

/// The only signal a UI shows for a field.
enum FieldReview { looksRight, checkThis }
