import '../model/recognized_document.dart';
import 'label_row.dart';

/// Turns recognized tables into rows. Positions are real, not estimated.
class TableAdapter {
  const TableAdapter();

  /// Rows of every table, the upper table first. Blank cells and cells with a
  /// non-finite box are skipped. A cell with a row span is listed once, in its
  /// first row. A row with no text is skipped.
  List<LabelRow> adapt(List<RecognizedTable> tables) {
    final ordered = [...tables]
      ..sort((a, b) {
        final byTop = _compare(a.box.top, b.box.top);
        return byTop != 0 ? byTop : _compare(a.box.left, b.box.left);
      });
    final rows = <LabelRow>[];
    for (final table in ordered) {
      final byRow = <int, List<RecognizedCell>>{};
      for (final cell in table.cells) {
        if (cell.text.trim().isEmpty || !isFiniteRect(cell.box)) continue;
        byRow.putIfAbsent(cell.row, () => []).add(cell);
      }
      final rowIndexes = byRow.keys.toList()..sort();
      for (final index in rowIndexes) {
        final cells = byRow[index]!
          ..sort((a, b) {
            final byColumn = a.column.compareTo(b.column);
            if (byColumn != 0) return byColumn;
            final byLeft = _compare(a.box.left, b.box.left);
            return byLeft != 0 ? byLeft : a.text.compareTo(b.text);
          });
        rows.add(
          LabelRow(
            tokens: [
              for (final cell in cells)
                LabelToken(text: cell.text.trim(), box: cell.box),
            ],
            box: unionOf(cells.map((c) => c.box)),
          ),
        );
      }
    }
    return rows;
  }

  static int _compare(double a, double b) => a.compareTo(b);
}
