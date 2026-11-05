// SYNTHETIC. Hand-written OCR-style data. Not from a real product and not from a real recognition run.

import 'dart:math';

import 'package:nutrition_label_reader/nutrition_label_reader.dart';

/// A grid of cell texts. Column 0 holds labels. An empty string is no cell.
///
/// It builds the same content in three shapes:
/// - [asTable]: tier A, cells in `tables`, with boxes too.
/// - [asSeparateBoxes]: tiers B and C, one box per cell.
/// - [asMergedLines]: tiers B and C, one box for each whole line.
///
/// Jitter comes from a seeded generator, so a test never flakes.
class FixtureGrid {
  const FixtureGrid(this.rows, {this.languages = const []});

  final List<List<String>> rows;
  final List<String> languages;

  static const _top = 0.1;
  static const _rowStep = 0.04;
  static const _height = 0.02;
  static const _labelLeft = 0.05;
  static const _labelWidth = 0.4;
  static const _valueLeft = 0.5;
  static const _valueStep = 0.25;
  static const _valueWidth = 0.2;

  LabelRect _cellRect(int row, int column, {double jitter = 0}) {
    final top = _top + row * _rowStep + jitter;
    if (column == 0) {
      return LabelRect(
        left: _labelLeft,
        top: top,
        width: _labelWidth,
        height: _height,
      );
    }
    return LabelRect(
      left: _valueLeft + (column - 1) * _valueStep,
      top: top,
      width: _valueWidth,
      height: _height,
    );
  }

  RecognizedDocument asTable({double? observationConfidence}) {
    final cells = <RecognizedCell>[];
    final boxes = <RecognizedTextBox>[];
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        final text = rows[r][c];
        if (text.isEmpty) continue;
        final box = _cellRect(r, c);
        cells.add(RecognizedCell(text: text, box: box, row: r, column: c));
        boxes.add(RecognizedTextBox(text: text, box: box));
      }
    }
    final columns = rows.map((r) => r.length).reduce(max);
    return RecognizedDocument(
      source: RecognitionSource.iosDocuments,
      imageWidth: 1000,
      imageHeight: 1500,
      boxes: boxes,
      tables: [
        RecognizedTable(
          box: LabelRect(
            left: _labelLeft,
            top: _top,
            width: _valueLeft + (columns - 1) * _valueStep - _labelLeft,
            height: rows.length * _rowStep,
          ),
          cells: cells,
        ),
      ],
      observationConfidence: observationConfidence,
      detectedLanguages: languages,
    );
  }

  RecognizedDocument asSeparateBoxes({double? observationConfidence}) {
    final random = Random(7);
    final boxes = <RecognizedTextBox>[];
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        final text = rows[r][c];
        if (text.isEmpty) continue;
        final jitter = (random.nextDouble() - 0.5) * 0.006;
        boxes.add(
          RecognizedTextBox(
            text: text,
            box: _cellRect(r, c, jitter: jitter),
          ),
        );
      }
    }
    return RecognizedDocument(
      source: RecognitionSource.androidMlKit,
      imageWidth: 1000,
      imageHeight: 1500,
      boxes: boxes,
      observationConfidence: observationConfidence,
      detectedLanguages: languages,
    );
  }

  RecognizedDocument asMergedLines({double? observationConfidence}) {
    final boxes = <RecognizedTextBox>[];
    for (var r = 0; r < rows.length; r++) {
      final used = [
        for (var c = 0; c < rows[r].length; c++)
          if (rows[r][c].isNotEmpty) c,
      ];
      if (used.isEmpty) continue;
      final first = _cellRect(r, used.first);
      final last = _cellRect(r, used.last);
      boxes.add(
        RecognizedTextBox(
          text: [for (final c in used) rows[r][c]].join(' '),
          box: LabelRect(
            left: first.left,
            top: first.top,
            width: last.right - first.left,
            height: _height,
          ),
        ),
      );
    }
    return RecognizedDocument(
      source: RecognitionSource.iosVisionText,
      imageWidth: 1000,
      imageHeight: 1500,
      boxes: boxes,
      observationConfidence: observationConfidence,
      detectedLanguages: languages,
    );
  }

  /// The text of every cell, for the "no invented number" check.
  String get allText => rows.expand((r) => r).join('\n');
}
