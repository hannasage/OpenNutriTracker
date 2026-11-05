// SYNTHETIC. Hand-written OCR-style data. Not from a real product and
// not from a real recognition run.

import 'package:nutrition_label_reader/nutrition_label_reader.dart';

const _labelLeft = 0.05;
const _labelWidth = 0.4;
const _valueLeft = 0.5;
const _valueWidth = 0.2;
const _rowHeight = 0.02;
const _rowStep = 0.04;

RecognizedTextBox _box(String text, double left, double width, int row) {
  return RecognizedTextBox(
    text: text,
    box: LabelRect(
      left: left,
      top: 0.1 + row * _rowStep,
      width: width,
      height: _rowHeight,
    ),
  );
}

const _rows = [
  ['Test cereal'],
  ['', 'Per 100 g'],
  ['Energy', '1300 kJ / 311 kcal'],
  ['Fat', '3.5 g'],
  ['of which saturates', '1.2 g'],
  ['Carbohydrate', '60 g'],
  ['of which sugars', '12 g'],
  ['Protein', '10 g'],
  ['Salt', '0.5 g'],
];

/// One text box per cell, as a recognizer without tables returns them.
final RecognizedDocument sampleDocument = RecognizedDocument(
  source: RecognitionSource.androidMlKit,
  imageWidth: 1000,
  imageHeight: 1500,
  boxes: [
    for (var r = 0; r < _rows.length; r++) ...[
      if (_rows[r][0].isNotEmpty) _box(_rows[r][0], _labelLeft, _labelWidth, r),
      if (_rows[r].length > 1) _box(_rows[r][1], _valueLeft, _valueWidth, r),
    ],
  ],
);
