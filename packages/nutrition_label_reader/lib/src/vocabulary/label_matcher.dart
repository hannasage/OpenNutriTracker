import '../model/parsed_label.dart';
import '../parser/text_normalizer.dart';
import 'label_vocabulary.dart';

/// What a row label matched.
class LabelMatch {
  const LabelMatch({
    required this.phrase,
    this.id,
    this.isSubItem = false,
    this.isIgnored = false,
    this.isEnergy = false,
  });

  /// The folded phrase that matched.
  final String phrase;

  /// Null when the row is ignored, and null for a generic energy word such as
  /// "energy". Then the unit of each quantity decides the id.
  final NutrientId? id;
  final bool isSubItem;

  /// True when the row name is on the vocabulary's ignore list.
  final bool isIgnored;

  /// True for every word of the energy family.
  final bool isEnergy;
}

/// One place a phrase occurs in folded text.
class PhraseMatch {
  const PhraseMatch(this.start, this.end, this.phrase);

  final int start;
  final int end;
  final String phrase;

  int get length => end - start;
}

/// Matches row labels to nutrients with exact phrases. No fuzzy matching.
class LabelMatcher {
  const LabelMatcher(this.vocabulary);

  final LabelVocabulary vocabulary;

  static const _dashes = {'-', '–', '—'};
  static const _bullets = {'•', '*', '·', '▪', '●'};
  static final _quantityStart = RegExp(r'^(<\s*)?[.,]?[0-9]');

  /// Matches the whole text, or the text up to its first quantity token.
  /// Returns null when nothing matches.
  LabelMatch? match(String text) {
    var folded = foldForMatching(text);
    var isSubItem = false;

    // Leading bullets and dashes. A dash also marks a sub-item.
    while (folded.isNotEmpty) {
      final first = folded[0];
      if (_dashes.contains(first)) {
        isSubItem = true;
      } else if (!_bullets.contains(first)) {
        break;
      }
      folded = folded.substring(1).trimLeft();
    }

    // A leading sub-item prefix such as "of which".
    for (final raw in vocabulary.subItemPrefixes) {
      final prefix = foldForMatching(raw);
      if (prefix.isEmpty || _dashes.contains(prefix)) continue;
      if (folded.startsWith('$prefix ')) {
        isSubItem = true;
        folded = folded.substring(prefix.length).trimLeft();
        break;
      }
    }
    if (folded.isEmpty) return null;

    return _lookup(folded, isSubItem) ??
        _lookup(_beforeQuantity(folded), isSubItem);
  }

  /// True when [text] holds any of [phrases] as a whole word or number.
  bool containsPhrase(String text, List<String> phrases) =>
      phraseMatches(text, phrases).isNotEmpty;

  /// Every place a phrase of [phrases] occurs in [text] as a whole word or
  /// number. Positions are in the folded text (see [foldForMatching]). Matches
  /// may overlap.
  List<PhraseMatch> phraseMatches(String text, List<String> phrases) {
    final folded = foldForMatching(text);
    final matches = <PhraseMatch>[];
    if (folded.isEmpty) return matches;
    for (final raw in phrases) {
      final phrase = foldForMatching(raw);
      if (phrase.isEmpty) continue;
      var from = 0;
      while (true) {
        final at = folded.indexOf(phrase, from);
        if (at < 0) break;
        final before = at == 0 ? '' : folded[at - 1];
        final end = at + phrase.length;
        final after = end >= folded.length ? '' : folded[end];
        if (!_isWordChar(before) && !_isWordChar(after)) {
          matches.add(PhraseMatch(at, end, phrase));
        }
        from = at + 1;
      }
    }
    return matches;
  }

  static bool _isWordChar(String char) =>
      char.isNotEmpty && RegExp(r'[a-z0-9]').hasMatch(char);

  static String _beforeQuantity(String folded) {
    final tokens = folded.split(' ');
    final kept = <String>[];
    for (final token in tokens) {
      if (_quantityStart.hasMatch(token)) break;
      kept.add(token);
    }
    var label = kept.join(' ').trim();
    while (label.endsWith(':')) {
      label = label.substring(0, label.length - 1).trimRight();
    }
    return label;
  }

  LabelMatch? _lookup(String phrase, bool isSubItem) {
    var clean = phrase;
    while (clean.endsWith(':')) {
      clean = clean.substring(0, clean.length - 1).trimRight();
    }
    if (clean.isEmpty) return null;
    for (final raw in vocabulary.ignoredNutrientNames) {
      if (foldForMatching(raw) == clean) {
        return LabelMatch(phrase: clean, isSubItem: isSubItem, isIgnored: true);
      }
    }
    final ids = <NutrientId>{};
    for (final entry in vocabulary.nutrientNames.entries) {
      for (final raw in entry.value) {
        if (foldForMatching(raw) == clean) ids.add(entry.key);
      }
    }
    if (ids.isEmpty) return null;
    const energy = {NutrientId.energyKj, NutrientId.energyKcal};
    if (ids.length > 1 && energy.containsAll(ids)) {
      return LabelMatch(phrase: clean, isSubItem: isSubItem, isEnergy: true);
    }
    final id = ids.first;
    return LabelMatch(
      phrase: clean,
      id: id,
      isSubItem: isSubItem,
      isEnergy: energy.contains(id),
    );
  }
}
