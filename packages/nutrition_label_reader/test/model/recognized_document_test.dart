import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';

const _rect = LabelRect(left: 0.1, top: 0.2, width: 0.3, height: 0.1);

RecognizedDocument _doc({
  int imageWidth = 1000,
  int imageHeight = 1500,
  List<RecognizedTextBox>? boxes,
  List<RecognizedTable> tables = const [],
  double? observationConfidence,
}) {
  return RecognizedDocument(
    source: RecognitionSource.androidMlKit,
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    boxes: boxes ?? const [RecognizedTextBox(text: 'Protein', box: _rect)],
    tables: tables,
    observationConfidence: observationConfidence,
  );
}

void main() {
  group('LabelRect', () {
    test('derives right, bottom and centers', () {
      expect(_rect.right, closeTo(0.4, 1e-12));
      expect(_rect.bottom, closeTo(0.3, 1e-12));
      expect(_rect.centerX, closeTo(0.25, 1e-12));
      expect(_rect.centerY, closeTo(0.25, 1e-12));
    });

    test('is equal by value', () {
      const same = LabelRect(left: 0.1, top: 0.2, width: 0.3, height: 0.1);
      const other = LabelRect(left: 0.1, top: 0.2, width: 0.3, height: 0.2);
      expect(_rect, same);
      expect(_rect.hashCode, same.hashCode);
      expect(_rect, isNot(other));
    });
  });

  group('equality', () {
    test('text box compares text and box', () {
      expect(
        const RecognizedTextBox(text: 'a', box: _rect),
        const RecognizedTextBox(text: 'a', box: _rect),
      );
      expect(
        const RecognizedTextBox(text: 'a', box: _rect),
        isNot(const RecognizedTextBox(text: 'b', box: _rect)),
      );
    });

    test('cell defaults both spans to 1', () {
      const cell = RecognizedCell(text: 'a', box: _rect, row: 0, column: 1);
      expect(cell.rowSpan, 1);
      expect(cell.columnSpan, 1);
      expect(
        cell,
        const RecognizedCell(text: 'a', box: _rect, row: 0, column: 1),
      );
      expect(
        cell,
        isNot(
          const RecognizedCell(
            text: 'a',
            box: _rect,
            row: 0,
            column: 1,
            columnSpan: 2,
          ),
        ),
      );
    });

    test('table compares cells', () {
      const cell = RecognizedCell(text: 'a', box: _rect, row: 0, column: 0);
      expect(
        const RecognizedTable(box: _rect, cells: [cell]),
        const RecognizedTable(box: _rect, cells: [cell]),
      );
      expect(
        const RecognizedTable(box: _rect, cells: [cell]),
        isNot(const RecognizedTable(box: _rect, cells: [])),
      );
    });

    test('document compares every field', () {
      expect(_doc(), _doc());
      expect(_doc(), isNot(_doc(imageWidth: 999)));
      expect(_doc(), isNot(_doc(observationConfidence: 0.5)));
      expect(_doc().tables, isEmpty);
      expect(_doc().detectedLanguages, isEmpty);
      expect(_doc().observationConfidence, isNull);
    });
  });

  group('validate', () {
    test('accepts a well formed document', () {
      const cell = RecognizedCell(text: 'a', box: _rect, row: 0, column: 0);
      expect(
        () => _doc(
          observationConfidence: 0.9,
          tables: const [
            RecognizedTable(box: _rect, cells: [cell]),
          ],
        ).validate(),
        returnsNormally,
      );
    });

    test('accepts a rect touching the edges', () {
      const edge = LabelRect(left: 0, top: 0, width: 1, height: 1);
      final doc = _doc(
        boxes: const [RecognizedTextBox(text: 'x', box: edge)],
      );
      expect(doc.validate, returnsNormally);
    });

    test('accepts floating-point noise at the edge', () {
      const noisy = LabelRect(left: 0.7, top: 0, width: 0.3 + 1e-12, height: 1);
      final doc = _doc(
        boxes: const [RecognizedTextBox(text: 'x', box: noisy)],
      );
      expect(doc.validate, returnsNormally);
    });

    test('accepts empty boxes', () {
      expect(_doc(boxes: const []).validate, returnsNormally);
    });

    test('rejects a non-positive image size', () {
      expect(_doc(imageWidth: 0).validate, throwsArgumentError);
      expect(_doc(imageHeight: -1).validate, throwsArgumentError);
    });

    test('rejects a box outside 0..1', () {
      const rects = [
        LabelRect(left: -0.01, top: 0, width: 0.1, height: 0.1),
        LabelRect(left: 0, top: -0.01, width: 0.1, height: 0.1),
        LabelRect(left: 0.95, top: 0, width: 0.1, height: 0.1),
        LabelRect(left: 0, top: 0.95, width: 0.1, height: 0.1),
        LabelRect(left: 0, top: 0, width: -0.1, height: 0.1),
        LabelRect(left: 0, top: 0, width: 0.1, height: -0.1),
      ];
      for (final rect in rects) {
        final doc = _doc(
          boxes: [RecognizedTextBox(text: 'x', box: rect)],
        );
        expect(doc.validate, throwsArgumentError, reason: '$rect');
      }
    });

    test('rejects NaN and infinite coordinates', () {
      for (final value in [double.nan, double.infinity]) {
        final rect = LabelRect(left: value, top: 0, width: 0.1, height: 0.1);
        final doc = _doc(
          boxes: [RecognizedTextBox(text: 'x', box: rect)],
        );
        expect(doc.validate, throwsArgumentError);
      }
    });

    test('rejects a bad table box or cell', () {
      const bad = LabelRect(left: 2, top: 0, width: 0.1, height: 0.1);
      const cell = RecognizedCell(text: 'a', box: _rect, row: 0, column: 0);
      const badCell = RecognizedCell(text: 'a', box: bad, row: 0, column: 0);
      expect(
        _doc(
          tables: const [
            RecognizedTable(box: bad, cells: [cell]),
          ],
        ).validate,
        throwsArgumentError,
      );
      expect(
        _doc(
          tables: const [
            RecognizedTable(box: _rect, cells: [badCell]),
          ],
        ).validate,
        throwsArgumentError,
      );
    });

    test('rejects a negative cell index or a span below 1', () {
      const cells = [
        RecognizedCell(text: 'a', box: _rect, row: -1, column: 0),
        RecognizedCell(text: 'a', box: _rect, row: 0, column: -1),
        RecognizedCell(text: 'a', box: _rect, row: 0, column: 0, rowSpan: 0),
        RecognizedCell(text: 'a', box: _rect, row: 0, column: 0, columnSpan: 0),
      ];
      for (final cell in cells) {
        final doc = _doc(
          tables: [
            RecognizedTable(box: _rect, cells: [cell]),
          ],
        );
        expect(doc.validate, throwsArgumentError);
      }
    });

    test('rejects a confidence outside 0..1', () {
      expect(_doc(observationConfidence: -0.1).validate, throwsArgumentError);
      expect(_doc(observationConfidence: 1.1).validate, throwsArgumentError);
      expect(
        _doc(observationConfidence: double.nan).validate,
        throwsArgumentError,
      );
    });
  });
}
