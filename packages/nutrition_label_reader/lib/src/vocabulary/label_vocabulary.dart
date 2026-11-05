import '../model/parsed_label.dart';

/// The words of one language. A vocabulary adds words only. Every number and
/// unit rule stays shared.
///
/// Every phrase must be lowercase with single spaces, so that matching is an
/// exact comparison. These strings are parser data, not UI strings.
abstract class LabelVocabulary {
  /// A BCP 47 tag, for example `en`.
  String get languageTag;

  /// Names a nutrient row can carry. A phrase belongs to one id only, with
  /// one exception.
  ///
  /// A generic energy word such as "energy" is listed under both
  /// [NutrientId.energyKj] and [NutrientId.energyKcal]. The matcher then gives
  /// no id, and the unit of each quantity decides which one it becomes. A word
  /// that names a unit, such as "kcal", is listed under its own id only.
  Map<NutrientId, List<String>> get nutrientNames;

  /// Header phrases for a per 100 g or per 100 ml column. A phrase carries its
  /// own `g` or `ml`.
  List<String> get per100Phrases;
  List<String> get perServingPhrases;
  List<String> get servingSizePhrases;

  /// Headers of a percent-of-reference column.
  List<String> get percentColumnPhrases;

  /// Headers of an "as prepared" column.
  List<String> get preparedPhrases;

  /// Words that start a sub-item row, such as "of which".
  List<String> get subItemPrefixes;

  /// Row names that are seen and not mapped, such as "added sugars".
  List<String> get ignoredNutrientNames;
}
