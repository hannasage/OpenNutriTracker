import 'package:equatable/equatable.dart';

import 'label_rect.dart';

/// Which recognizer produced a document.
enum RecognitionSource { iosDocuments, iosVisionText, androidMlKit }

/// One line or word of recognized text with its position.
class RecognizedTextBox extends Equatable {
  const RecognizedTextBox({required this.text, required this.box});

  final String text;
  final LabelRect box;

  @override
  List<Object?> get props => [text, box];
}

/// One cell of a recognized table.
class RecognizedCell extends Equatable {
  const RecognizedCell({
    required this.text,
    required this.box,
    required this.row,
    required this.column,
    this.rowSpan = 1,
    this.columnSpan = 1,
  });

  final String text;
  final LabelRect box;
  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;

  @override
  List<Object?> get props => [text, box, row, column, rowSpan, columnSpan];
}

/// A recognized table. Cells are in row-major order.
class RecognizedTable extends Equatable {
  const RecognizedTable({required this.box, required this.cells});

  final LabelRect box;
  final List<RecognizedCell> cells;

  @override
  List<Object?> get props => [box, cells];
}

/// What a text recognizer returned for one image.
///
/// This is input. The parser is the only code that reads numbers from it.
class RecognizedDocument extends Equatable {
  const RecognizedDocument({
    required this.source,
    required this.imageWidth,
    required this.imageHeight,
    required this.boxes,
    this.tables = const [],
    this.observationConfidence,
    this.detectedLanguages = const [],
  });

  final RecognitionSource source;

  /// Image size in pixels. Used for the aspect ratio only.
  final int imageWidth;
  final int imageHeight;

  /// Lines or words. Always set, on every source.
  final List<RecognizedTextBox> boxes;

  /// Recognized tables. Only the iOS documents source fills this.
  final List<RecognizedTable> tables;

  /// One value for the whole observation. Diagnostic only. The parser never
  /// reads it and a UI never shows it.
  final double? observationConfidence;

  /// BCP 47 tags. May be empty.
  final List<String> detectedLanguages;

  /// Slack for floating-point error in the 0 to 1 range checks.
  static const double _slack = 1e-9;

  /// Checks the geometry contract.
  ///
  /// Throws [ArgumentError] on the first violation.
  void validate() {
    if (imageWidth <= 0) {
      throw ArgumentError.value(imageWidth, 'imageWidth', 'must be positive');
    }
    if (imageHeight <= 0) {
      throw ArgumentError.value(imageHeight, 'imageHeight', 'must be positive');
    }
    final confidence = observationConfidence;
    if (confidence != null && !(confidence >= 0 && confidence <= 1)) {
      throw ArgumentError.value(
        confidence,
        'observationConfidence',
        'must be from 0 to 1',
      );
    }
    for (final box in boxes) {
      _checkRect(box.box, 'boxes');
    }
    for (final table in tables) {
      _checkRect(table.box, 'tables');
      for (final cell in table.cells) {
        _checkRect(cell.box, 'tables.cells');
        if (cell.row < 0) {
          throw ArgumentError.value(cell.row, 'row', 'must not be negative');
        }
        if (cell.column < 0) {
          throw ArgumentError.value(
            cell.column,
            'column',
            'must not be negative',
          );
        }
        if (cell.rowSpan < 1) {
          throw ArgumentError.value(
            cell.rowSpan,
            'rowSpan',
            'must be 1 or more',
          );
        }
        if (cell.columnSpan < 1) {
          throw ArgumentError.value(
            cell.columnSpan,
            'columnSpan',
            'must be 1 or more',
          );
        }
      }
    }
  }

  static void _checkRect(LabelRect rect, String name) {
    final values = [rect.left, rect.top, rect.width, rect.height];
    for (final value in values) {
      if (!value.isFinite) {
        throw ArgumentError.value(rect, name, 'has a non-finite coordinate');
      }
    }
    final inRange =
        rect.left >= -_slack &&
        rect.top >= -_slack &&
        rect.width >= 0 &&
        rect.height >= 0 &&
        rect.right <= 1 + _slack &&
        rect.bottom <= 1 + _slack;
    if (!inRange) {
      throw ArgumentError.value(rect, name, 'must lie inside 0..1');
    }
  }

  @override
  List<Object?> get props => [
    source,
    imageWidth,
    imageHeight,
    boxes,
    tables,
    observationConfidence,
    detectedLanguages,
  ];
}
