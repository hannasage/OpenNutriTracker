import 'text_normalizer.dart';

/// How a piece of text read as a number.
enum NumberStatus {
  /// A clean number.
  value,

  /// A comma number that reads two ways and nothing decides.
  ambiguous,

  /// A word such as `trace`. There is no number to read.
  absent,

  /// The text has digits but no clean number. Nothing is repaired.
  unreadable,

  /// The text has no ASCII digit and is not an absent word.
  notNumeric,
}

/// The result of reading one number.
class NumberReading {
  const NumberReading({
    required this.rawText,
    required this.status,
    this.value,
    this.isUpperBound = false,
    this.readings = const [],
  });

  /// The text read, trimmed.
  final String rawText;
  final NumberStatus status;

  /// Set only when [status] is [NumberStatus.value].
  final double? value;

  /// True when the text starts with `<`.
  final bool isUpperBound;

  /// Both readings of an ambiguous number: the decimal reading, then the
  /// thousands reading. Empty for any other status.
  final List<double> readings;
}

/// Reads numbers from label text. Pure and total: it never throws.
///
/// Rules:
/// - `1,5` and `1.5` are 1.5.
/// - With both marks, the last mark is the decimal mark.
/// - One comma or one dot and exactly three digits (`1,234`, `1.046`) reads
///   two ways. The caller may pass [isPlausible] to decide. When both readings
///   are plausible, or neither is, the number stays ambiguous.
/// - A letter is never turned into a digit.
class NumberLexer {
  const NumberLexer._();

  static const _absentWords = {'trace', 'nil', '-', 'n/a'};
  static final _digit = RegExp('[0-9]');
  static final _numberBody = RegExp(r'^[0-9.,]+$');

  static NumberReading read(
    String text, {
    bool Function(double value)? isPlausible,
  }) {
    final raw = text.trim();
    final normalized = normalizeText(raw).trim();
    NumberReading result(
      NumberStatus status, {
      double? value,
      bool bound = false,
      List<double> readings = const [],
    }) {
      return NumberReading(
        rawText: raw,
        status: status,
        value: value,
        isUpperBound: bound,
        readings: readings,
      );
    }

    if (_absentWords.contains(normalized.toLowerCase())) {
      return result(NumberStatus.absent);
    }
    var bound = false;
    var body = normalized;
    if (body.startsWith('<')) {
      bound = true;
      body = body.substring(1).trim();
    }
    if (!_digit.hasMatch(body)) return result(NumberStatus.notNumeric);
    if (!_numberBody.hasMatch(body)) {
      return result(NumberStatus.unreadable, bound: bound);
    }

    final parsed = _parse(body);
    if (parsed == null) return result(NumberStatus.unreadable, bound: bound);
    if (parsed.length == 1) {
      return result(NumberStatus.value, value: parsed.first, bound: bound);
    }
    // Two readings: decimal first, thousands second.
    if (isPlausible != null) {
      final plausible = parsed.where(isPlausible).toList();
      if (plausible.length == 1) {
        return result(NumberStatus.value, value: plausible.first, bound: bound);
      }
    }
    return result(NumberStatus.ambiguous, bound: bound, readings: parsed);
  }

  /// Returns one value, two values for an ambiguous comma, or null when the
  /// body is not a clean number.
  static List<double>? _parse(String body) {
    final commas = ','.allMatches(body).length;
    final dots = '.'.allMatches(body).length;

    if (commas == 0 && dots == 0) return _finite(body);

    if (commas > 0 && dots > 0) {
      final decimalMark = body.lastIndexOf(',') > body.lastIndexOf('.')
          ? ','
          : '.';
      final thousandsMark = decimalMark == ',' ? '.' : ',';
      final decimalCount = decimalMark == ',' ? commas : dots;
      if (decimalCount != 1) return null;
      final at = body.indexOf(decimalMark);
      final integerPart = body.substring(0, at);
      final fraction = body.substring(at + 1);
      if (fraction.isEmpty) return null;
      final groups = integerPart.split(thousandsMark);
      if (!_validGroups(groups)) return null;
      return _finite('${groups.join()}.$fraction');
    }

    final mark = commas > 0 ? ',' : '.';
    final parts = body.split(mark);
    if (parts.length > 2) {
      return _validGroups(parts) ? _finite(parts.join()) : null;
    }
    final head = parts[0];
    final tail = parts[1];
    if (tail.isEmpty) return null;
    final decimal = _finite('${head.isEmpty ? '0' : head}.$tail');
    if (decimal == null) return null;
    // A group of three digits after the only mark could be a thousands group.
    // A comma head may not start with 0. A dot head may be a single 0, so
    // 0.125 reads two ways. That asymmetry is deliberate (owner decision).
    final headFits =
        head.isNotEmpty &&
        head.length <= 3 &&
        (!head.startsWith('0') || (mark == '.' && head == '0'));
    final couldBeThousands = tail.length == 3 && headFits;
    if (!couldBeThousands) return decimal;
    final thousands = _finite('$head$tail');
    if (thousands == null) return decimal;
    return [decimal.first, thousands.first];
  }

  /// A thousands grouping: the first group has one to three digits and does
  /// not start with 0. Every other group has exactly three digits.
  static bool _validGroups(List<String> groups) {
    if (groups.isEmpty) return false;
    final first = groups.first;
    if (first.isEmpty || first.length > 3) return false;
    if (groups.length > 1 && first.startsWith('0')) return false;
    for (final group in groups.skip(1)) {
      if (group.length != 3) return false;
    }
    return true;
  }

  static List<double>? _finite(String text) {
    final value = double.tryParse(text);
    if (value == null || !value.isFinite) return null;
    return [value];
  }
}
