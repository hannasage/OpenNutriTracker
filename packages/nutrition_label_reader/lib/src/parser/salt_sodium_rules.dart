import '../model/parsed_label.dart';
import 'derive_helpers.dart';

/// Salt equals sodium times this factor (salt in g, sodium in g).
///
/// Source: Regulation (EU) No 1169/2011, Annex I, point 11. "Salt" means the
/// salt equivalent content, calculated with salt = sodium x 2.5. Read on
/// 2026-11-05 in the original Official Journal text at
/// https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32011R1169
/// (a consolidated version was not checked). So 1 g of salt holds 400 mg of
/// sodium. The rounding guidance for the number is non-binding and is not
/// used.
const double _saltPerSodium = 2.5;

/// Links salt and sodium. Rules R12 and R13.
///
/// For each slot (per 100, per serving, unknown basis):
/// - Salt read, sodium absent: sodium in mg is derived as salt in g * 1000 /
///   2.5.
/// - Sodium read, salt absent: salt in g is derived as sodium in mg * 2.5 /
///   1000.
///
/// A derived value has `isDerived`, and its nutrient has
/// `derivedFromOtherUnit`. When both are read, nothing changes. When neither
/// is read, no entry is made, so a missing salt is never zero. A slot that
/// was read and rejected is never filled. Derived values are not rounded.
List<ParsedNutrient> applySaltSodiumRules(List<ParsedNutrient> nutrients) {
  final saltIndex = nutrients.indexWhere((n) => n.id == NutrientId.salt);
  final sodiumIndex = nutrients.indexWhere((n) => n.id == NutrientId.sodium);
  if (saltIndex < 0 && sodiumIndex < 0) return nutrients;

  var salt = saltIndex < 0 ? null : nutrients[saltIndex];
  var sodium = sodiumIndex < 0 ? null : nutrients[sodiumIndex];
  final saltBefore = salt;
  final sodiumBefore = sodium;
  final box = (salt ?? sodium)!.sourceBox;

  for (final slot in Slot.values) {
    final saltQuantity = slotOf(salt, slot);
    final sodiumQuantity = slotOf(sodium, slot);
    final saltRead = isRead(saltQuantity, LabelUnit.g);
    final sodiumRead = isRead(sodiumQuantity, LabelUnit.mg);
    if (saltRead && sodiumQuantity == null) {
      final derived = ParsedQuantity(
        value: saltQuantity!.value! * 1000 / _saltPerSodium,
        unit: LabelUnit.mg,
        rawText: saltQuantity.rawText,
        isDerived: true,
      );
      sodium = withDerived(
        sodium,
        NutrientId.sodium,
        box,
        slot,
        derived,
        salt!,
      );
    } else if (sodiumRead && saltQuantity == null) {
      final derived = ParsedQuantity(
        value: sodiumQuantity!.value! * _saltPerSodium / 1000,
        unit: LabelUnit.g,
        rawText: sodiumQuantity.rawText,
        isDerived: true,
      );
      salt = withDerived(salt, NutrientId.salt, box, slot, derived, sodium!);
    }
  }

  if (identical(salt, saltBefore) && identical(sodium, sodiumBefore)) {
    return nutrients;
  }

  final result = [...nutrients];
  if (saltIndex >= 0) result[saltIndex] = salt!;
  if (sodiumIndex >= 0) result[sodiumIndex] = sodium!;
  // A nutrient made by a rule goes right after the one it came from.
  if (saltIndex < 0 && salt != null) {
    result.insert(sodiumIndex + 1, salt);
  } else if (sodiumIndex < 0 && sodium != null) {
    result.insert(saltIndex + 1, sodium);
  }
  return result;
}
