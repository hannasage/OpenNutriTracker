import '../model/parse_result.dart';
import '../model/parsed_label.dart';
import '../model/recognized_document.dart';
import '../vocabulary/english.dart';
import '../vocabulary/label_matcher.dart';
import '../vocabulary/label_vocabulary.dart';
import 'column_detector.dart';
import 'energy_rules.dart';
import 'label_row.dart';
import 'nutrient_extractor.dart';
import 'parser_config.dart';
import 'quantity_scanner.dart';
import 'salt_sodium_rules.dart';
import 'row_builder.dart';
import 'serving_parser.dart';
import 'table_adapter.dart';

/// Reads a nutrition panel from recognized text.
///
/// The parser is pure and synchronous. It reads numbers from text. A model
/// never gives it a number. It never repairs a digit, never picks a side of an
/// ambiguous comma number when both readings fit, never assumes a missing
/// unit, and never fills a missing nutrient.
class LabelParser {
  const LabelParser({
    this.vocabularies = const [englishLabelVocabulary],
    this.config = const ParserConfig(),
  });

  final List<LabelVocabulary> vocabularies;
  final ParserConfig config;

  static const _nutritionUnits = {
    LabelUnit.g,
    LabelUnit.mg,
    LabelUnit.ug,
    LabelUnit.kj,
    LabelUnit.kcal,
  };

  LabelParseResult parse(RecognizedDocument document) {
    if (document.boxes.isEmpty) {
      return const LabelNotRead(
        reason: LabelFailureReason.noText,
        nameMatches: 0,
        valueMatches: 0,
      );
    }

    // Rows: tables when they hold a panel, boxes otherwise.
    final boxRows = RowBuilder(
      rowYToleranceFactor: config.rowYToleranceFactor,
    ).build(document.boxes);
    var rows = boxRows;
    var fellBack = false;
    if (document.tables.isNotEmpty) {
      final tableRows = const TableAdapter().adapt(document.tables);
      final best = _pick(tableRows);
      if (best != null && best.names >= config.minNutrientNames) {
        rows = tableRows;
      } else {
        fellBack = true;
      }
    }

    final pick = _pick(rows);
    if (pick == null) {
      return LabelNotRead(
        reason: LabelFailureReason.unsupportedLanguage,
        nameMatches: 0,
        valueMatches: _unitValueCount(rows),
      );
    }
    if (pick.names < config.minNutrientNames) {
      final values = _unitValueCount(rows);
      final looksLikeAPanel = values >= config.minValues && pick.names < values;
      return LabelNotRead(
        reason: looksLikeAPanel
            ? LabelFailureReason.unsupportedLanguage
            : LabelFailureReason.noNutritionPanel,
        nameMatches: pick.names,
        valueMatches: values,
      );
    }

    final matcher = LabelMatcher(pick.vocabulary);
    final layout = ColumnDetector(matcher).detect(rows);
    final extraction = NutrientExtractor(
      matcher: matcher,
      config: config,
    ).extract(rows, layout);

    LabelNotRead failure(LabelFailureReason reason) => LabelNotRead(
      reason: reason,
      nameMatches: extraction.nameMatches,
      valueMatches: extraction.valueMatches,
    );

    if (extraction.valueMatches < config.minValues) {
      return failure(LabelFailureReason.noNutritionPanel);
    }
    bool hasValueIn(ParsedNutrient n) =>
        n.per100?.value != null ||
        n.perServing?.value != null ||
        n.unknownBasis?.value != null;
    final hasValue = extraction.nutrients.any(hasValueIn);
    if (!hasValue) return failure(LabelFailureReason.noReadableValues);
    final hasEnergy = extraction.nutrients.any(
      (n) =>
          (n.id == NutrientId.energyKj || n.id == NutrientId.energyKcal) &&
          hasValueIn(n),
    );
    if (!hasEnergy) return failure(LabelFailureReason.noEnergyRow);

    return LabelParsed(
      ParsedLabel(
        nutrients: applySaltSodiumRules(
          applyEnergyRules(extraction.nutrients, config),
        ),
        primaryBasis: extraction.primaryBasis,
        languageTag: pick.vocabulary.languageTag,
        serving: ServingParser(matcher).parse(rows),
        warnings: {
          ...extraction.warnings,
          if (pick.ambiguous) LabelWarning.languageAmbiguous,
          if (fellBack) LabelWarning.tableFallbackToBoxes,
        },
        ignoredRows: extraction.ignoredRows,
      ),
    );
  }

  /// The vocabulary that matches the most names. A second vocabulary within
  /// one name of the best makes the pick ambiguous. Null when there is no
  /// vocabulary.
  _Pick? _pick(List<LabelRow> rows) {
    if (vocabularies.isEmpty) return null;
    final counts = [
      for (final vocabulary in vocabularies)
        NutrientExtractor.countNames(rows, LabelMatcher(vocabulary)),
    ];
    var best = 0;
    for (var i = 1; i < counts.length; i++) {
      if (counts[i] > counts[best]) best = i;
    }
    var ambiguous = false;
    for (var i = 0; i < counts.length; i++) {
      if (i != best && counts[i] > 0 && counts[best] - counts[i] <= 1) {
        ambiguous = true;
      }
    }
    return _Pick(vocabularies[best], counts[best], ambiguous);
  }

  /// Quantities with a nutrition unit, on every row. Used to tell a panel in
  /// an unknown language from text that is no panel.
  static int _unitValueCount(List<LabelRow> rows) {
    var count = 0;
    for (final row in rows) {
      for (final token in LineSplitter.split(row).tokens) {
        for (final quantity in QuantityScanner.quantities(token.text)) {
          if (_nutritionUnits.contains(QuantityScanner.unitOf(quantity))) {
            count++;
          }
        }
      }
    }
    return count;
  }
}

class _Pick {
  const _Pick(this.vocabulary, this.names, this.ambiguous);
  final LabelVocabulary vocabulary;
  final int names;
  final bool ambiguous;
}
