import '../model/field_flag.dart';
import '../model/parsed_label.dart';
import 'derive_helpers.dart';
import 'parser_config.dart';

/// Energy per gram of carbohydrate, protein and fat, in kcal. The app uses
/// the same general Atwater factors, 4, 4 and 9, in
/// lib/features/add_meal/domain/entity/meal_nutriments_entity.dart:404-425.
/// The plugin must not import app code, so the values are repeated here. The
/// app judges the gap with a tolerance of 0.25; the plugin reads its own from
/// [ParserConfig.atwaterTolerance].
const double _kcalPerGramCarbohydrate = 4;
const double _kcalPerGramProtein = 4;
const double _kcalPerGramFat = 9;

/// Flags values that look wrong. Rules R5, R6, R7 and R11.
///
/// Every rule only adds a flag. No value changes. A value with no unit, no
/// number, or a leading `<` is not judged where a comparison needs an exact
/// value.
///
/// - R5: a per 100 value above its range gets `valueOutOfRange`. The ranges are
///   in [ParserConfig.isPlausible]. A serving or unknown basis has none.
/// - R6: saturates above fat, or sugars above carbohydrate, in the same
///   slot, gets `subItemExceedsParent` on the child.
/// - R7: fat, carbohydrate and protein per 100 adding up to more than 100 plus
///   [ParserConfig.macroSumSlack] get `macroSumExceeds100` on all three.
/// - R11: kcal that differs from 4 * carbohydrate + 4 * protein + 9 * fat by
///   more than [ParserConfig.atwaterTolerance] of the kcal value gets
///   `energyDoesNotMatchMacros` on both energy nutrients.
List<ParsedNutrient> applyPlausibilityRules(
  List<ParsedNutrient> nutrients,
  ParserConfig config,
) {
  if (nutrients.isEmpty) return nutrients;
  final byId = {for (final n in nutrients) n.id: n};
  final added = <NutrientId, Set<FieldFlag>>{};
  void flag(NutrientId id, FieldFlag flag) =>
      added.putIfAbsent(id, () => {}).add(flag);

  // R5
  for (final n in nutrients) {
    final q = n.per100;
    final value = q?.value;
    if (q == null || value == null || q.unit == null) continue;
    if (!config.isPlausible(n.id, value, LabelBasis.per100g)) {
      flag(n.id, FieldFlag.valueOutOfRange);
    }
  }

  // R6
  const pairs = [
    (NutrientId.saturatedFat, NutrientId.fat),
    (NutrientId.sugars, NutrientId.carbohydrate),
  ];
  for (final slot in Slot.values) {
    for (final (childId, parentId) in pairs) {
      final child = slotOf(byId[childId], slot);
      final parent = slotOf(byId[parentId], slot);
      if (!_exact(child, LabelUnit.g, allowBound: false)) continue;
      if (!_exact(parent, LabelUnit.g, allowBound: true)) continue;
      if (child!.value! > parent!.value!) {
        flag(childId, FieldFlag.subItemExceedsParent);
      }
    }
  }

  // R7
  const macroIds = [
    NutrientId.fat,
    NutrientId.carbohydrate,
    NutrientId.protein,
  ];
  final macroValues = [for (final id in macroIds) byId[id]?.per100];
  if (macroValues.every((q) => _exact(q, LabelUnit.g, allowBound: false))) {
    final sum = macroValues.fold<double>(0, (sum, q) => sum + q!.value!);
    if (sum > 100 + config.macroSumSlack) {
      for (final id in macroIds) {
        flag(id, FieldFlag.macroSumExceeds100);
      }
    }
  }

  // R11
  for (final slot in Slot.values) {
    final kcal = slotOf(byId[NutrientId.energyKcal], slot);
    final fat = slotOf(byId[NutrientId.fat], slot);
    final carbohydrate = slotOf(byId[NutrientId.carbohydrate], slot);
    final protein = slotOf(byId[NutrientId.protein], slot);
    if (!_exact(kcal, LabelUnit.kcal, allowBound: false) ||
        !_exact(fat, LabelUnit.g, allowBound: false) ||
        !_exact(carbohydrate, LabelUnit.g, allowBound: false) ||
        !_exact(protein, LabelUnit.g, allowBound: false)) {
      continue;
    }
    final declared = kcal!.value!;
    if (declared <= 0) continue;
    final computed =
        _kcalPerGramCarbohydrate * carbohydrate!.value! +
        _kcalPerGramProtein * protein!.value! +
        _kcalPerGramFat * fat!.value!;
    if ((declared - computed).abs() / declared > config.atwaterTolerance) {
      flag(NutrientId.energyKcal, FieldFlag.energyDoesNotMatchMacros);
      flag(NutrientId.energyKj, FieldFlag.energyDoesNotMatchMacros);
    }
  }

  if (added.isEmpty) return nutrients;
  return [
    for (final n in nutrients)
      added.containsKey(n.id) ? addFlags(n, added[n.id]!) : n,
  ];
}

/// True when [q] has a number and the unit [unit], and, unless [allowBound],
/// no leading `<`.
bool _exact(ParsedQuantity? q, LabelUnit unit, {required bool allowBound}) =>
    q != null &&
    q.value != null &&
    q.unit == unit &&
    (allowBound || !q.isUpperBound);
