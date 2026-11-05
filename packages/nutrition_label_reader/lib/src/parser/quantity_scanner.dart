import '../model/parsed_label.dart';
import 'text_normalizer.dart';
import 'unit_lexer.dart';

/// A run of words in a text. A quantity run is a number with an optional unit.
class QuantitySegment {
  const QuantitySegment(this.start, this.end, this.isQuantity);

  final int start;
  final int end;
  final bool isQuantity;
}

/// Finds quantities such as `5 g`, `<0.5g`, `12%` or `trace` in text.
/// Pure and total. It never repairs a digit.
class QuantityScanner {
  const QuantityScanner._();

  /// `n/a` is one word. A lone slash is a word of its own.
  static final _words = RegExp(r'n/a|[^\s/]+|/', caseSensitive: false);
  static final _pureNumber = RegExp(r'^<?[.,]?[0-9][0-9.,]*$');
  static final _numberStart = RegExp(r'^<?[.,]?[0-9]');
  static const _absentWords = {'trace', 'nil', 'n/a'};

  /// Splits [text] into quantity runs and runs of other words.
  ///
  /// With [joinSlash], quantities joined by a slash, such as
  /// `1046 kJ / 250 kcal`, form one run.
  static List<QuantitySegment> segments(String text, {bool joinSlash = false}) {
    final words = _words.allMatches(normalizeText(text)).toList();
    final segments = <QuantitySegment>[];
    var i = 0;
    while (i < words.length) {
      var end = _quantityEnd(words, i, allowDash: i > 0);
      if (end >= 0) {
        if (joinSlash) {
          while (end + 2 < words.length && words[end + 1].group(0) == '/') {
            final next = _quantityEnd(words, end + 2, allowDash: false);
            if (next < 0) break;
            end = next;
          }
        }
        segments.add(QuantitySegment(words[i].start, words[end].end, true));
        i = end + 1;
        continue;
      }
      final previous = segments.isEmpty ? null : segments.last;
      if (previous != null && !previous.isQuantity) {
        segments[segments.length - 1] = QuantitySegment(
          previous.start,
          words[i].end,
          false,
        );
      } else {
        segments.add(QuantitySegment(words[i].start, words[i].end, false));
      }
      i++;
    }
    return segments;
  }

  /// Each quantity in [text], as written. Slash-joined quantities come apart.
  static List<String> quantities(String text) {
    return [
      for (final segment in segments(text))
        if (segment.isQuantity) text.substring(segment.start, segment.end),
    ];
  }

  /// True when [text] starts with a quantity, or is a lone dash.
  static bool isValueText(String text) {
    final trimmed = text.trim();
    if (trimmed == '-') return true;
    final words = _words.allMatches(normalizeText(trimmed)).toList();
    if (words.isEmpty) return false;
    return _quantityEnd(words, 0, allowDash: false) >= 0;
  }

  /// The unit written after the number of [quantity], or null.
  static LabelUnit? unitOf(String quantity) {
    final rest = normalizeText(
      quantity,
    ).trim().replaceFirst(RegExp(r'^<?\s*[0-9.,]+'), '').trim();
    return rest.isEmpty ? null : UnitLexer.parse(rest);
  }

  /// The index of the last word of the quantity that starts at word [i], or
  /// -1 when no quantity starts there.
  static int _quantityEnd(
    List<RegExpMatch> words,
    int i, {
    required bool allowDash,
  }) {
    final word = words[i].group(0)!;
    var end = i;
    if (word == '<' &&
        i + 1 < words.length &&
        _pureNumber.hasMatch(words[i + 1].group(0)!)) {
      end = i + 1;
    } else if (_numberStart.hasMatch(word)) {
      end = i;
    } else if (_absentWords.contains(word.toLowerCase()) ||
        (word == '-' && allowDash)) {
      return i;
    } else {
      return -1;
    }
    final last = words[end].group(0)!;
    if (_pureNumber.hasMatch(last) && end + 1 < words.length) {
      final next = words[end + 1].group(0)!;
      if (next == '%' || UnitLexer.parse(next) != null) end++;
    }
    return end;
  }
}
