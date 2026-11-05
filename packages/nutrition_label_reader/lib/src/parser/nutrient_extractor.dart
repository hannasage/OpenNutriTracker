import '../model/field_flag.dart';
import '../model/label_rect.dart';
import '../model/parsed_label.dart';
import '../vocabulary/label_matcher.dart';
import 'column_detector.dart';
import 'label_row.dart';
import 'number_lexer.dart';
import 'parser_config.dart';
import 'quantity_lexer.dart';
import 'quantity_scanner.dart';
import 'row_builder.dart';

/// What the extractor found.
class ExtractionResult {
  const ExtractionResult({
    required this.nutrients,
    required this.warnings,
    required this.ignoredRows,
    required this.nameMatches,
    required this.valueMatches,
    required this.primaryBasis,
  });

  final List<ParsedNutrient> nutrients;
  final Set<LabelWarning> warnings;
  final List<String> ignoredRows;

  /// Distinct nutrient names matched on rows.
  final int nameMatches;

  /// Quantities with a digit on matched rows, percent values left out.
  final int valueMatches;
  final LabelBasis primaryBasis;
}

/// Reads nutrient rows into [ParsedNutrient] values.
class NutrientExtractor {
  const NutrientExtractor({required this.matcher, required this.config});

  final LabelMatcher matcher;
  final ParserConfig config;

  /// Distinct nutrient names matched on [rows]. All energy words count as one
  /// name.
  static int countNames(List<LabelRow> rows, LabelMatcher matcher) {
    final keys = <String>{};
    for (final row in rows) {
      final match = matcher.match(_partsOf(row).label);
      if (match == null || match.isIgnored) continue;
      keys.add(match.isEnergy ? 'energy' : match.id!.name);
    }
    return keys.length;
  }

  ExtractionResult extract(List<LabelRow> rows, ColumnLayout layout) {
    final detector = ColumnDetector(matcher);
    final headerRows = layout.headerRows.toSet();
    final drafts = <NutrientId, _Draft>{};
    final ignored = <String>[];
    final names = <String>{};
    final duplicates = <NutrientId>{};
    var valueMatches = 0;
    var percentSeen = false;
    LabelMatch? previousEnergy;

    for (var i = 0; i < rows.length; i++) {
      final carried = previousEnergy;
      previousEnergy = null;
      if (headerRows.contains(i)) continue;
      final row = rows[i];
      if (matcher.containsPhrase(
        row.text,
        matcher.vocabulary.servingSizePhrases,
      )) {
        continue;
      }
      final parts = _partsOf(row);
      var match = matcher.match(parts.label);
      // Energy can run over two rows: the kJ value, then the kcal value on a
      // row of its own with no label.
      if (match == null &&
          carried != null &&
          parts.label.isEmpty &&
          parts.values.isNotEmpty &&
          _onlyEnergyUnits(parts.values)) {
        match = carried;
      }
      if (match == null) {
        if (parts.values.isNotEmpty) ignored.add(row.text);
        continue;
      }
      if (match.isIgnored) {
        ignored.add(row.text);
        continue;
      }
      names.add(match.isEnergy ? 'energy' : match.id!.name);
      if (match.isEnergy) previousEnergy = match;
      if (parts.values.isEmpty) {
        ignored.add(row.text);
        continue;
      }

      final cells = <LabelToken>[];
      for (final token in parts.values) {
        final quantities = QuantityScanner.quantities(token.text);
        final isPercent =
            quantities.isNotEmpty &&
            quantities.every((q) => q.trim().endsWith('%'));
        if (isPercent) {
          percentSeen = true;
          continue;
        }
        cells.add(token);
        valueMatches += quantities
            .where((q) => q.contains(RegExp('[0-9]')))
            .length;
      }

      final assignment = detector.assign(layout, cells);
      final created = <NutrientId>{};
      final slots = <_Slot>[];
      assignment.byColumn.forEach((index, cell) {
        final column = layout.columns[index];
        if (column.kind == ColumnKind.per100) {
          slots.add(_Slot(cell, _SlotKind.per100, column.basis));
        } else if (column.kind == ColumnKind.perServing) {
          slots.add(_Slot(cell, _SlotKind.perServing, LabelBasis.perServing));
        }
        // A prepared column is read and dropped.
      });
      final unknown = assignment.unknownBasisCell;
      if (unknown != null) slots.add(_Slot(unknown, _SlotKind.unknown, null));

      if (assignment.ambiguous && match.id != null) {
        _draft(
          drafts,
          created,
          duplicates,
          match.id!,
          row.box,
        )?.flags.addAll(assignment.flags);
      }

      var mapped = false;
      for (final slot in slots) {
        final quantities = QuantityScanner.quantities(slot.cell.text);
        if (match.isEnergy) {
          for (final q in quantities) {
            final unit = QuantityScanner.unitOf(q);
            final id = switch (unit) {
              LabelUnit.kj => NutrientId.energyKj,
              LabelUnit.kcal => NutrientId.energyKcal,
              _ => match.id,
            };
            if (id == null) continue;
            mapped = true;
            _put(
              drafts,
              created,
              duplicates,
              id,
              row.box,
              slot,
              q,
              assignment.flags,
            );
          }
        } else if (quantities.length == 1) {
          mapped = true;
          _put(
            drafts,
            created,
            duplicates,
            match.id!,
            row.box,
            slot,
            quantities.single,
            assignment.flags,
          );
        } else {
          mapped = true;
          final draft = _draft(drafts, created, duplicates, match.id!, row.box);
          if (draft != null) {
            _store(
              draft,
              slot.kind,
              ParsedQuantity(
                value: null,
                unit: null,
                rawText: slot.cell.text.trim(),
              ),
            );
            draft.flags
              ..add(FieldFlag.ambiguousNumber)
              ..addAll(assignment.flags);
          }
        }
      }
      if (!mapped && !assignment.ambiguous) ignored.add(row.text);
    }

    // A second full panel, such as the same label in another language, repeats
    // at least as many nutrients as a panel needs. The first panel wins and
    // the label says so. A smaller repeat is a duplicate row on each nutrient.
    final isSecondPanel = duplicates.length >= config.minNutrientNames;
    if (!isSecondPanel) {
      for (final id in duplicates) {
        drafts[id]!.flags.add(FieldFlag.duplicateRow);
      }
    }
    final warnings = {
      ...layout.warnings,
      if (percentSeen) LabelWarning.percentColumnIgnored,
      if (isSecondPanel) LabelWarning.duplicatePanelIgnored,
    };
    return ExtractionResult(
      nutrients: [for (final d in drafts.values) d.build()],
      warnings: warnings,
      ignoredRows: ignored,
      nameMatches: names.length,
      valueMatches: valueMatches,
      primaryBasis: _primaryBasis(layout),
    );
  }

  void _put(
    Map<NutrientId, _Draft> drafts,
    Set<NutrientId> created,
    Set<NutrientId> duplicates,
    NutrientId id,
    LabelRect box,
    _Slot slot,
    String text,
    Set<FieldFlag> rowFlags,
  ) {
    final draft = _draft(drafts, created, duplicates, id, box);
    if (draft == null) return;
    if (draft.has(slot.kind)) return;
    final reading = QuantityLexer.read(
      text,
      id,
      isPlausible: (value) => config.isPlausible(id, value, slot.basis),
    );
    if (reading.status == NumberStatus.notNumeric) return;
    _store(draft, slot.kind, reading.quantity);
    draft.flags
      ..addAll(reading.flags)
      ..addAll(rowFlags);
  }

  /// The draft for [id], or null when an earlier row already has it. A later
  /// row for the same nutrient adds [id] to [duplicates].
  _Draft? _draft(
    Map<NutrientId, _Draft> drafts,
    Set<NutrientId> created,
    Set<NutrientId> duplicates,
    NutrientId id,
    LabelRect box,
  ) {
    final existing = drafts[id];
    if (existing == null) {
      created.add(id);
      return drafts[id] = _Draft(id, box);
    }
    if (created.contains(id)) return existing;
    duplicates.add(id);
    return null;
  }

  static void _store(_Draft draft, _SlotKind kind, ParsedQuantity quantity) {
    switch (kind) {
      case _SlotKind.per100:
        draft.per100 = quantity;
      case _SlotKind.perServing:
        draft.perServing = quantity;
      case _SlotKind.unknown:
        draft.unknownBasis = quantity;
    }
  }

  static LabelBasis _primaryBasis(ColumnLayout layout) {
    for (final column in layout.columns) {
      if (column.kind == ColumnKind.per100) return column.basis!;
    }
    for (final column in layout.columns) {
      if (column.kind == ColumnKind.perServing) return LabelBasis.perServing;
    }
    return LabelBasis.unknown;
  }

  static bool _onlyEnergyUnits(List<LabelToken> values) {
    final quantities = [
      for (final token in values) ...QuantityScanner.quantities(token.text),
    ];
    return quantities.isNotEmpty &&
        quantities.every((q) {
          final unit = QuantityScanner.unitOf(q);
          return unit == LabelUnit.kj || unit == LabelUnit.kcal;
        });
  }

  static _RowParts _partsOf(LabelRow row) {
    final tokens = LineSplitter.split(row).tokens;
    final first = tokens.indexWhere((t) => QuantityScanner.isValueText(t.text));
    final label = (first < 0 ? tokens : tokens.sublist(0, first))
        .map((t) => t.text)
        .join(' ');
    final values = first < 0
        ? const <LabelToken>[]
        : [
            for (final t in tokens.skip(first))
              if (QuantityScanner.isValueText(t.text)) t,
          ];
    return _RowParts(label, values);
  }
}

class _RowParts {
  const _RowParts(this.label, this.values);
  final String label;
  final List<LabelToken> values;
}

enum _SlotKind { per100, perServing, unknown }

class _Slot {
  const _Slot(this.cell, this.kind, this.basis);
  final LabelToken cell;
  final _SlotKind kind;

  /// Null when the basis is unknown.
  final LabelBasis? basis;
}

class _Draft {
  _Draft(this.id, this.box);

  final NutrientId id;
  final LabelRect box;
  final Set<FieldFlag> flags = {};
  ParsedQuantity? per100;
  ParsedQuantity? perServing;
  ParsedQuantity? unknownBasis;

  bool has(_SlotKind kind) => switch (kind) {
    _SlotKind.per100 => per100 != null,
    _SlotKind.perServing => perServing != null,
    _SlotKind.unknown => unknownBasis != null,
  };

  ParsedNutrient build() => ParsedNutrient(
    id: id,
    per100: per100,
    perServing: perServing,
    unknownBasis: unknownBasis,
    flags: Set.unmodifiable(flags),
    sourceBox: box,
  );
}
