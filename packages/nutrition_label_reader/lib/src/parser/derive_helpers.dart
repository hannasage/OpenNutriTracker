import '../model/field_flag.dart';
import '../model/label_rect.dart';
import '../model/parsed_label.dart';

/// The three places a nutrient keeps a value.
enum Slot { per100, perServing, unknownBasis }

/// Flags of a source value that carry over to a value derived from it.
const inheritedFlags = {
  FieldFlag.columnFromOrderNotPosition,
  FieldFlag.columnAmbiguous,
};

ParsedQuantity? slotOf(ParsedNutrient? nutrient, Slot slot) {
  if (nutrient == null) return null;
  return switch (slot) {
    Slot.per100 => nutrient.per100,
    Slot.perServing => nutrient.perServing,
    Slot.unknownBasis => nutrient.unknownBasis,
  };
}

/// True when [quantity] was read: it has a number, the unit [unit], no `<`,
/// and no rule made it.
bool isRead(ParsedQuantity? quantity, LabelUnit unit) =>
    quantity != null &&
    quantity.value != null &&
    quantity.unit == unit &&
    !quantity.isUpperBound &&
    !quantity.isDerived;

ParsedNutrient addFlags(ParsedNutrient nutrient, Set<FieldFlag> flags) {
  return copyNutrient(nutrient, flags: {...nutrient.flags, ...flags});
}

/// Puts [derived] in [slot] of [target], or of a new nutrient with [id] when
/// [target] is null. The nutrient gets `derivedFromOtherUnit` and the column
/// doubts of [source].
ParsedNutrient withDerived(
  ParsedNutrient? target,
  NutrientId id,
  LabelRect? box,
  Slot slot,
  ParsedQuantity derived,
  ParsedNutrient source,
) {
  final flags = {
    FieldFlag.derivedFromOtherUnit,
    ...source.flags.intersection(inheritedFlags),
  };
  final base = target ?? ParsedNutrient(id: id, sourceBox: box);
  return copyNutrient(
    base,
    per100: slot == Slot.per100 ? derived : null,
    perServing: slot == Slot.perServing ? derived : null,
    unknownBasis: slot == Slot.unknownBasis ? derived : null,
    flags: {...base.flags, ...flags},
  );
}

/// A copy of [n]. A slot argument replaces the slot when it is not null.
ParsedNutrient copyNutrient(
  ParsedNutrient n, {
  ParsedQuantity? per100,
  ParsedQuantity? perServing,
  ParsedQuantity? unknownBasis,
  Set<FieldFlag>? flags,
}) {
  return ParsedNutrient(
    id: n.id,
    per100: per100 ?? n.per100,
    perServing: perServing ?? n.perServing,
    unknownBasis: unknownBasis ?? n.unknownBasis,
    flags: flags ?? n.flags,
    sourceBox: n.sourceBox,
  );
}
