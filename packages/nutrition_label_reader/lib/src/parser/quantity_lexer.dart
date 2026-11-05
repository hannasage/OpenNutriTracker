import '../model/field_flag.dart';
import '../model/parsed_label.dart';
import 'number_lexer.dart';
import 'text_normalizer.dart';
import 'unit_lexer.dart';

/// A number and its unit, read for one nutrient.
class QuantityReading {
  const QuantityReading({
    required this.status,
    required this.quantity,
    this.flags = const {},
  });

  final NumberStatus status;
  final ParsedQuantity quantity;
  final Set<FieldFlag> flags;
}

/// Reads text such as `5 g`, `<0.5g` or `1046kJ` for a known nutrient.
/// Pure and total.
class QuantityLexer {
  const QuantityLexer._();

  static final _split = RegExp(r'^(<\s*)?([0-9.,]+)\s*(\S.*)?$');
  static final _digit = RegExp('[0-9]');

  /// [isPlausible] gets a candidate in the nutrient's canonical unit. It only
  /// matters for a number that reads two ways.
  static QuantityReading read(
    String text,
    NutrientId id, {
    bool Function(double canonicalValue)? isPlausible,
  }) {
    final raw = text.trim();
    final normalized = normalizeText(raw).trim();
    QuantityReading plain(NumberStatus status, {Set<FieldFlag>? flags}) {
      return QuantityReading(
        status: status,
        quantity: ParsedQuantity(value: null, unit: null, rawText: raw),
        flags: flags ?? const {},
      );
    }

    final lower = normalized.toLowerCase();
    if (const {'trace', 'nil', '-', 'n/a'}.contains(lower)) {
      return plain(NumberStatus.absent);
    }
    final match = _split.firstMatch(normalized);
    if (match == null) {
      return _digit.hasMatch(normalized)
          ? plain(NumberStatus.unreadable, flags: {FieldFlag.unreadableNumber})
          : plain(NumberStatus.notNumeric);
    }
    final bound = match.group(1) != null;
    final numberText = '${bound ? '<' : ''}${match.group(2)}';
    final unitText = (match.group(3) ?? '').trim();
    final unit = unitText.isEmpty ? null : UnitLexer.parse(unitText);
    if (unitText.isNotEmpty && unit == null) {
      // Digits followed by something that is not a unit. No repair.
      return QuantityReading(
        status: NumberStatus.unreadable,
        quantity: ParsedQuantity(
          value: null,
          unit: null,
          rawText: raw,
          isUpperBound: bound,
        ),
        flags: {FieldFlag.unreadableNumber, if (bound) FieldFlag.upperBound},
      );
    }

    bool Function(double)? check;
    if (isPlausible != null) {
      check = (candidate) {
        final outcome = UnitLexer.canonicalize(id, candidate, unit);
        final value = outcome.value;
        return unit != null && value != null && isPlausible(value);
      };
    }
    final number = NumberLexer.read(numberText, isPlausible: check);
    final extra = {if (bound) FieldFlag.upperBound};

    switch (number.status) {
      case NumberStatus.value:
        final outcome = UnitLexer.canonicalize(id, number.value!, unit);
        return QuantityReading(
          status: NumberStatus.value,
          quantity: ParsedQuantity(
            value: outcome.value,
            unit: outcome.unit,
            rawText: raw,
            isUpperBound: bound,
          ),
          flags: {...outcome.flags, ...extra},
        );
      case NumberStatus.ambiguous:
        return QuantityReading(
          status: NumberStatus.ambiguous,
          quantity: ParsedQuantity(
            value: null,
            unit: unit,
            rawText: raw,
            isUpperBound: bound,
          ),
          flags: {FieldFlag.ambiguousNumber, ...extra},
        );
      case NumberStatus.unreadable:
        return QuantityReading(
          status: NumberStatus.unreadable,
          quantity: ParsedQuantity(
            value: null,
            unit: unit,
            rawText: raw,
            isUpperBound: bound,
          ),
          flags: {FieldFlag.unreadableNumber, ...extra},
        );
      case NumberStatus.absent:
        return plain(NumberStatus.absent);
      case NumberStatus.notNumeric:
        return plain(NumberStatus.notNumeric);
    }
  }
}
