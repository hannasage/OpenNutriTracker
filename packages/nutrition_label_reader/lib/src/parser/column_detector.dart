import '../model/field_flag.dart';
import '../model/parsed_label.dart';
import '../vocabulary/label_matcher.dart';
import 'label_row.dart';
import 'text_normalizer.dart';

/// What a column holds.
enum ColumnKind { per100, perServing, percent, prepared }

/// One column found in a header.
class ColumnInfo {
  const ColumnInfo({
    required this.kind,
    required this.centerX,
    required this.estimatedX,
    this.basis,
  });

  final ColumnKind kind;

  /// Set for [ColumnKind.per100] and [ColumnKind.perServing] only.
  final LabelBasis? basis;
  final double centerX;
  final bool estimatedX;

  /// True for a column whose values the parser keeps.
  bool get isData => kind == ColumnKind.per100 || kind == ColumnKind.perServing;
}

/// The columns of a label.
class ColumnLayout {
  const ColumnLayout({
    required this.columns,
    required this.warnings,
    required this.headerRows,
  });

  /// Columns from left to right.
  final List<ColumnInfo> columns;
  final Set<LabelWarning> warnings;

  /// Indexes of the rows that hold headers.
  final List<int> headerRows;

  bool get hasDataColumns => columns.any((c) => c.isData);
}

/// Where the cells of one row went.
class CellAssignment {
  const CellAssignment({
    this.byColumn = const {},
    this.unknownBasisCell,
    this.ambiguous = false,
    this.flags = const {},
  });

  /// Column index in [ColumnLayout.columns] to cell.
  final Map<int, LabelToken> byColumn;

  /// The one cell of a label that has no header. Its basis is unknown.
  final LabelToken? unknownBasisCell;

  /// True when the cells could not be placed. Nothing is assigned.
  final bool ambiguous;

  /// Flags for every nutrient on the row.
  final Set<FieldFlag> flags;
}

/// Finds the columns of a label and places cells in them.
class ColumnDetector {
  const ColumnDetector(this.matcher);

  final LabelMatcher matcher;

  /// Reads the header rows above the first nutrient row.
  ColumnLayout detect(List<LabelRow> rows) {
    final firstNutrient = rows.indexWhere(_isNutrientRow);
    final limit = firstNutrient < 0 ? rows.length : firstNutrient;
    final columns = <ColumnInfo>[];
    final headerRows = <int>[];
    for (var i = 0; i < limit; i++) {
      final found = _columnsIn(rows[i]);
      if (found.isEmpty) continue;
      final isServingSizeRow = matcher.containsPhrase(
        rows[i].text,
        matcher.vocabulary.servingSizePhrases,
      );
      if (isServingSizeRow &&
          found.every((c) => c.kind == ColumnKind.perServing)) {
        continue;
      }
      columns.addAll(found);
      headerRows.add(i);
    }
    columns.sort((a, b) => a.centerX.compareTo(b.centerX));
    final warnings = <LabelWarning>{
      if (columns.any((c) => c.kind == ColumnKind.percent))
        LabelWarning.percentColumnIgnored,
      if (columns.any((c) => c.kind == ColumnKind.prepared))
        LabelWarning.preparedColumnIgnored,
      if (!columns.any((c) => c.isData)) LabelWarning.basisUnknown,
    };
    return ColumnLayout(
      columns: columns,
      warnings: warnings,
      headerRows: headerRows,
    );
  }

  /// Places the value [cells] of one row. [cells] hold no percent values.
  ///
  /// Percent columns never take a cell. With real x for every cell and
  /// column, each cell goes to the nearest column. With any estimated x, cells
  /// go by order when the counts match and the row is ambiguous when they do
  /// not.
  CellAssignment assign(ColumnLayout layout, List<LabelToken> cells) {
    if (cells.isEmpty) return const CellAssignment();
    if (!layout.hasDataColumns) {
      if (cells.length == 1) {
        return CellAssignment(
          unknownBasisCell: cells.first,
          flags: const {FieldFlag.columnAmbiguous},
        );
      }
      return const CellAssignment(
        ambiguous: true,
        flags: {FieldFlag.columnAmbiguous},
      );
    }

    final candidates = [
      for (var i = 0; i < layout.columns.length; i++)
        if (layout.columns[i].kind != ColumnKind.percent) i,
    ];
    final anyEstimated =
        cells.any((c) => c.estimatedX) ||
        candidates.any((i) => layout.columns[i].estimatedX);

    if (!anyEstimated) {
      final byColumn = <int, LabelToken>{};
      for (final cell in cells) {
        var best = candidates.first;
        var bestDistance = double.infinity;
        for (final index in candidates) {
          final distance = (layout.columns[index].centerX - cell.centerX).abs();
          if (distance < bestDistance) {
            best = index;
            bestDistance = distance;
          }
        }
        if (byColumn.containsKey(best)) return _ambiguous;
        byColumn[best] = cell;
      }
      return CellAssignment(byColumn: byColumn);
    }

    if (cells.length != candidates.length) return _ambiguous;
    return CellAssignment(
      byColumn: {
        for (var i = 0; i < cells.length; i++) candidates[i]: cells[i],
      },
      flags: const {FieldFlag.columnFromOrderNotPosition},
    );
  }

  static const _ambiguous = CellAssignment(
    ambiguous: true,
    flags: {FieldFlag.columnAmbiguous},
  );

  bool _isNutrientRow(LabelRow row) {
    final match = matcher.match(row.text);
    return match != null && !match.isIgnored;
  }

  List<ColumnInfo> _columnsIn(LabelRow row) {
    final vocabulary = matcher.vocabulary;
    final result = <ColumnInfo>[];
    for (final token in row.tokens) {
      final candidates =
          <_Candidate>[
            for (final (kind, phrases) in [
              (ColumnKind.per100, vocabulary.per100Phrases),
              (ColumnKind.perServing, vocabulary.perServingPhrases),
              (ColumnKind.percent, vocabulary.percentColumnPhrases),
              (ColumnKind.prepared, vocabulary.preparedPhrases),
            ])
              for (final m in matcher.phraseMatches(token.text, phrases))
                _Candidate(kind, m),
          ]..sort((a, b) {
            final byStart = a.match.start.compareTo(b.match.start);
            return byStart != 0
                ? byStart
                : b.match.length.compareTo(a.match.length);
          });

      // Keep the longest match at each place. Drop any that overlaps.
      final chosen = <_Candidate>[];
      var lastEnd = 0;
      for (final candidate in candidates) {
        if (candidate.match.start >= lastEnd) {
          chosen.add(candidate);
          lastEnd = candidate.match.end;
        }
      }

      // "as prepared" turns the nearest basis phrase of the token into one
      // prepared column.
      final absorbed = <_Candidate>{};
      for (final prepared in chosen.where(
        (c) => c.kind == ColumnKind.prepared,
      )) {
        _Candidate? nearest;
        var nearestDistance = double.infinity;
        for (final other in chosen) {
          if (other.kind != ColumnKind.per100 &&
              other.kind != ColumnKind.perServing) {
            continue;
          }
          if (absorbed.contains(other)) continue;
          final distance = (other.center - prepared.center).abs();
          if (distance < nearestDistance) {
            nearest = other;
            nearestDistance = distance;
          }
        }
        if (nearest != null) absorbed.add(nearest);
      }
      final kept = [
        for (final c in chosen)
          if (!absorbed.contains(c)) c,
      ];

      final foldedLength = foldForMatching(token.text).length;
      for (final c in kept) {
        final single = kept.length == 1;
        final centerX = single
            ? token.centerX
            : token.box.left + token.box.width * c.center / foldedLength;
        result.add(
          ColumnInfo(
            kind: c.kind,
            basis: switch (c.kind) {
              ColumnKind.per100 =>
                c.match.phrase.contains('ml')
                    ? LabelBasis.per100ml
                    : LabelBasis.per100g,
              ColumnKind.perServing => LabelBasis.perServing,
              _ => null,
            },
            centerX: centerX,
            estimatedX: single ? token.estimatedX : true,
          ),
        );
      }
    }
    return result;
  }
}

class _Candidate {
  const _Candidate(this.kind, this.match);

  final ColumnKind kind;
  final PhraseMatch match;

  double get center => (match.start + match.end) / 2;
}
