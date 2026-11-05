import '../model/field_flag.dart';
import '../model/parsed_label.dart';
import 'derive_helpers.dart';
import 'parser_config.dart';

/// Kilojoules in one kilocalorie. The app uses the same value at
/// lib/core/utils/calc/unit_calc.dart:10 (`UnitCalc.kcalToKjFactor`). The
/// plugin must not import app code, so the value is repeated here.
const double _kcalToKjFactor = 4.184;

/// Reconciles kJ and kcal. Rules R8 to R10.
///
/// For each slot (per 100, per serving, unknown basis):
/// - Both read: when the two disagree by more than
///   [ParserConfig.energyUnitTolerance], both get `energyUnitsDisagree`. No
///   value changes.
/// - Only kJ read: kcal is derived as kJ / 4.184. The derived value has
///   `isDerived` and the nutrient has `derivedFromOtherUnit`.
/// - Only kcal read: kJ is derived as kcal * 4.184, flagged the same way.
///
/// A value is read when it has a number, the matching unit, and no `<`. A slot
/// that was read and rejected is never filled. Derived values are not rounded.
List<ParsedNutrient> applyEnergyRules(
  List<ParsedNutrient> nutrients,
  ParserConfig config,
) {
  final kjIndex = nutrients.indexWhere((n) => n.id == NutrientId.energyKj);
  final kcalIndex = nutrients.indexWhere((n) => n.id == NutrientId.energyKcal);
  if (kjIndex < 0 && kcalIndex < 0) return nutrients;

  var kj = kjIndex < 0 ? null : nutrients[kjIndex];
  var kcal = kcalIndex < 0 ? null : nutrients[kcalIndex];
  final kjBefore = kj;
  final kcalBefore = kcal;
  final box = (kj ?? kcal)!.sourceBox;

  for (final slot in Slot.values) {
    final kjQuantity = slotOf(kj, slot);
    final kcalQuantity = slotOf(kcal, slot);
    final kjRead = isRead(kjQuantity, LabelUnit.kj);
    final kcalRead = isRead(kcalQuantity, LabelUnit.kcal);
    if (kjRead && kcalRead) {
      if (_disagree(kjQuantity!.value!, kcalQuantity!.value!, config)) {
        kj = addFlags(kj!, {FieldFlag.energyUnitsDisagree});
        kcal = addFlags(kcal!, {FieldFlag.energyUnitsDisagree});
      }
    } else if (kjRead && kcalQuantity == null) {
      final derived = ParsedQuantity(
        value: kjQuantity!.value! / _kcalToKjFactor,
        unit: LabelUnit.kcal,
        rawText: kjQuantity.rawText,
        isDerived: true,
      );
      kcal = withDerived(kcal, NutrientId.energyKcal, box, slot, derived, kj!);
    } else if (kcalRead && kjQuantity == null) {
      final derived = ParsedQuantity(
        value: kcalQuantity!.value! * _kcalToKjFactor,
        unit: LabelUnit.kj,
        rawText: kcalQuantity.rawText,
        isDerived: true,
      );
      kj = withDerived(kj, NutrientId.energyKj, box, slot, derived, kcal!);
    }
  }

  if (identical(kj, kjBefore) && identical(kcal, kcalBefore)) return nutrients;

  final result = [...nutrients];
  if (kjIndex >= 0) result[kjIndex] = kj!;
  if (kcalIndex >= 0) result[kcalIndex] = kcal!;
  // A nutrient made by a rule goes right after the one it came from.
  if (kjIndex < 0 && kj != null) {
    result.insert(kcalIndex + 1, kj);
  } else if (kcalIndex < 0 && kcal != null) {
    result.insert(kjIndex + 1, kcal);
  }
  return result;
}

bool _disagree(double kj, double kcal, ParserConfig config) {
  final converted = kcal * _kcalToKjFactor;
  if (kj <= 0) return converted != 0;
  return (kj - converted).abs() / kj > config.energyUnitTolerance;
}
