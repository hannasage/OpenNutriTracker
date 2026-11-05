import '../model/label_rect.dart';
import '../model/recognized_document.dart';
import 'label_row.dart';
import 'quantity_scanner.dart';

/// Rebuilds rows from loose text boxes. Used for sources that give no tables.
class RowBuilder {
  const RowBuilder({this.rowYToleranceFactor = 0.5});

  /// A box joins a row when its vertical centre is within this factor times
  /// the median box height of the row's mean centre.
  final double rowYToleranceFactor;

  /// Builds rows, top to bottom, each sorted left to right.
  ///
  /// Boxes with blank text or a non-finite coordinate are dropped. Boxes in a
  /// row that are closer than one median height join into one token. The
  /// result does not depend on the order of [boxes].
  List<LabelRow> build(List<RecognizedTextBox> boxes) {
    final valid = [
      for (final box in boxes)
        if (box.text.trim().isNotEmpty && isFiniteRect(box.box)) box,
    ];
    if (valid.isEmpty) return const [];

    final heights = [for (final box in valid) box.box.height]..sort();
    final mid = heights.length ~/ 2;
    final medianHeight = heights.length.isOdd
        ? heights[mid]
        : (heights[mid - 1] + heights[mid]) / 2;
    final tolerance = rowYToleranceFactor * medianHeight;

    valid.sort((a, b) {
      final byY = a.box.centerY.compareTo(b.box.centerY);
      if (byY != 0) return byY;
      final byX = a.box.left.compareTo(b.box.left);
      return byX != 0 ? byX : a.text.compareTo(b.text);
    });

    final groups = <List<RecognizedTextBox>>[];
    var sum = 0.0;
    for (final box in valid) {
      if (groups.isNotEmpty) {
        final mean = sum / groups.last.length;
        if ((box.box.centerY - mean).abs() <= tolerance) {
          groups.last.add(box);
          sum += box.box.centerY;
          continue;
        }
      }
      groups.add([box]);
      sum = box.box.centerY;
    }

    return [for (final group in groups) _row(group, medianHeight)];
  }

  static LabelRow _row(List<RecognizedTextBox> group, double medianHeight) {
    group.sort((a, b) {
      final byX = a.box.left.compareTo(b.box.left);
      return byX != 0 ? byX : a.text.compareTo(b.text);
    });
    final tokens = <LabelToken>[];
    var text = group.first.text.trim();
    var box = group.first.box;
    for (final next in group.skip(1)) {
      final gap = next.box.left - box.right;
      if (gap < medianHeight) {
        text = '$text ${next.text.trim()}';
        box = unionOf([box, next.box]);
      } else {
        tokens.add(LabelToken(text: text, box: box));
        text = next.text.trim();
        box = next.box;
      }
    }
    tokens.add(LabelToken(text: text, box: box));
    return LabelRow(tokens: tokens, box: unionOf(group.map((b) => b.box)));
  }
}

/// Splits merged lines such as `Protein 5 g 10 g` into a label token and
/// quantity tokens.
///
/// Recognizers on some platforms return a whole line as one box. A token made
/// by a split has an estimated x: the centre of its characters inside the box.
/// Quantities joined by a slash, such as `1046 kJ / 250 kcal`, stay together.
/// Apply it to nutrient rows. Do not apply it to header rows, which hold
/// phrases such as `per 100 g`.
class LineSplitter {
  const LineSplitter._();

  static LabelRow split(LabelRow row) {
    final tokens = <LabelToken>[];
    var changed = false;
    for (final token in row.tokens) {
      final pieces = _splitToken(token);
      if (pieces.length > 1) changed = true;
      tokens.addAll(pieces);
    }
    return changed ? LabelRow(tokens: tokens, box: row.box) : row;
  }

  static List<LabelToken> _splitToken(LabelToken token) {
    final text = token.text;
    final segments = QuantityScanner.segments(text, joinSlash: true);
    if (segments.length <= 1) return [token];
    final length = text.length;
    final box = token.box;
    return [
      for (final segment in segments)
        LabelToken(
          text: text.substring(segment.start, segment.end),
          box: LabelRect(
            left: box.left + box.width * segment.start / length,
            top: box.top,
            width: box.width * (segment.end - segment.start) / length,
            height: box.height,
          ),
          estimatedX: true,
        ),
    ];
  }
}
