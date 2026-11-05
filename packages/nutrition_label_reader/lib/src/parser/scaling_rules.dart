import '../model/field_flag.dart';
import '../model/parsed_label.dart';
import 'derive_helpers.dart';

/// The result of [applyServingScaling].
class ScalingOutcome {
  const ScalingOutcome(this.nutrients, this.warnings);

  final List<ParsedNutrient> nutrients;
  final Set<LabelWarning> warnings;
}

/// Scales a label that has only per-serving values. Rules R14 and R15.
///
/// A label is per-serving-only when some nutrient has a serving value and no
/// nutrient has a per 100 value.
/// - R14: with a serving amount in grams or millilitres above zero, each
///   serving value with a number and a unit becomes a per 100 value, value *
///   100 / amount. The new value has `isDerived`, and its nutrient has
///   `scaledFromServing`. The serving value stays.
/// - R15: with no such amount, no per 100 value is made and the outcome has
///   `servingSizeMissing`.
///
/// A value with no unit is not scaled. Scaled values are not rounded. Any
/// other label is returned as it is.
ScalingOutcome applyServingScaling(
  List<ParsedNutrient> nutrients,
  ServingInfo? serving,
) {
  final hasServing = nutrients.any((n) => n.perServing != null);
  final hasPer100 = nutrients.any((n) => n.per100 != null);
  if (!hasServing || hasPer100) return ScalingOutcome(nutrients, const {});

  final amount = serving?.amount;
  if (amount == null || !amount.isFinite || amount <= 0) {
    return ScalingOutcome(nutrients, const {LabelWarning.servingSizeMissing});
  }

  final scaled = <ParsedNutrient>[];
  for (final n in nutrients) {
    final q = n.perServing;
    final value = q?.value;
    if (q == null || value == null || q.unit == null) {
      scaled.add(n);
      continue;
    }
    final per100 = value * 100 / amount;
    if (!per100.isFinite) {
      scaled.add(n);
      continue;
    }
    scaled.add(
      copyNutrient(
        n,
        per100: ParsedQuantity(
          value: per100,
          unit: q.unit,
          rawText: q.rawText,
          isUpperBound: q.isUpperBound,
          isDerived: true,
        ),
        flags: {...n.flags, FieldFlag.scaledFromServing},
      ),
    );
  }
  return ScalingOutcome(scaled, const {});
}
