import '../model/parsed_label.dart';
import '../vocabulary/label_matcher.dart';
import 'label_row.dart';
import 'number_lexer.dart';
import 'text_normalizer.dart';

/// Reads the serving size and the servings per container from label rows.
class ServingParser {
  const ServingParser(this.matcher);

  final LabelMatcher matcher;

  static final _amount = RegExp(
    r'([0-9]+(?:[.,][0-9]+)?)\s*(ml|g)\b',
    caseSensitive: false,
  );
  static final _bareCount = RegExp(r'^[^0-9()]{0,20}?([0-9][0-9.,]*)\s*$');

  /// Returns null when no row names a serving.
  ///
  /// A row that names a serving phrase and then holds only a number, with at
  /// most a few words before it, gives servings per container. Any other row
  /// gives the serving size. The first row of each kind wins.
  ServingInfo? parse(List<LabelRow> rows) {
    final phrases = [...matcher.vocabulary.servingSizePhrases]
      ..sort((a, b) => b.length.compareTo(a.length));
    String? sizeText;
    double? amount;
    var isMillilitres = false;
    String? containerText;
    double? perContainer;

    for (final row in rows) {
      final remainder = _remainder(row.text, phrases);
      if (remainder == null) continue;
      final count = _bareCount.firstMatch(remainder);
      if (count != null) {
        if (containerText != null) continue;
        containerText = remainder;
        final reading = NumberLexer.read(count.group(1)!);
        perContainer = reading.status == NumberStatus.value
            ? reading.value
            : null;
        continue;
      }
      if (sizeText != null) continue;
      sizeText = remainder;
      final match = _amount.firstMatch(remainder);
      if (match != null) {
        final reading = NumberLexer.read(match.group(1)!);
        if (reading.status == NumberStatus.value) {
          amount = reading.value;
          isMillilitres = match.group(2)!.toLowerCase() == 'ml';
        }
      }
    }

    final raw = sizeText ?? containerText;
    if (raw == null) return null;
    return ServingInfo(
      rawText: raw,
      amount: amount,
      isMillilitres: isMillilitres,
      servingsPerContainer: perContainer,
    );
  }

  /// The text after the first serving phrase, or null when the row has no
  /// phrase or nothing follows it.
  String? _remainder(String text, List<String> phrases) {
    final normalized = normalizeText(text);
    final lowered = normalized.toLowerCase();
    if (lowered.length != normalized.length) return null;
    for (final phrase in phrases) {
      final folded = foldForMatching(phrase);
      if (folded.isEmpty) continue;
      final at = lowered.indexOf(folded);
      if (at < 0) continue;
      final end = at + folded.length;
      final before = at == 0 ? '' : lowered[at - 1];
      final after = end >= lowered.length ? '' : lowered[end];
      if (RegExp('[a-z0-9]').hasMatch(before) ||
          RegExp('[a-z0-9]').hasMatch(after)) {
        continue;
      }
      final rest = normalized
          .substring(end)
          .replaceFirst(RegExp(r'^[\s:=\-]+'), '')
          .trim();
      return rest.isEmpty ? null : rest;
    }
    return null;
  }
}
