import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader/src/parser/table_adapter.dart';

RecognizedCell _cell(
  String text,
  int row,
  int column, {
  double? left,
  double top = 0.1,
  double width = 0.2,
  int rowSpan = 1,
  int columnSpan = 1,
}) {
  return RecognizedCell(
    text: text,
    row: row,
    column: column,
    rowSpan: rowSpan,
    columnSpan: columnSpan,
    box: LabelRect(
      left: left ?? 0.05 + column * 0.3,
      top: top + row * 0.05,
      width: width,
      height: 0.04,
    ),
  );
}

RecognizedTable _table(List<RecognizedCell> cells, {double top = 0.1}) {
  return RecognizedTable(
    box: LabelRect(left: 0, top: top, width: 1, height: 0.8),
    cells: cells,
  );
}

List<String> _texts(List rows) => rows
    .map((row) => row.tokens.map((t) => t.text).join('|') as String)
    .toList();

void main() {
  const adapter = TableAdapter();

  test('returns no rows for no tables', () {
    expect(adapter.adapt(const []), isEmpty);
  });

  test('builds one row per table row with real positions', () {
    final rows = adapter.adapt([
      _table([
        _cell('Protein', 1, 0),
        _cell('5 g', 1, 1),
        _cell('Per 100 g', 0, 1),
        _cell('Per serving', 0, 2),
        _cell('1 g', 1, 2),
      ]),
    ]);
    expect(_texts(rows), ['Per 100 g|Per serving', 'Protein|5 g|1 g']);
    expect(rows.every((r) => r.tokens.every((t) => !t.estimatedX)), isTrue);
    expect(rows.last.tokens[1].centerX, closeTo(0.05 + 0.3 + 0.1, 1e-12));
  });

  test('skips empty and blank cells', () {
    final rows = adapter.adapt([
      _table([_cell('Fat', 0, 0), _cell('', 0, 1), _cell('  ', 0, 2)]),
    ]);
    expect(_texts(rows), ['Fat']);
  });

  test('skips a row with no text', () {
    final rows = adapter.adapt([
      _table([_cell('', 0, 0), _cell('Fat', 1, 0)]),
    ]);
    expect(_texts(rows), ['Fat']);
  });

  test('copes with ragged rows', () {
    final rows = adapter.adapt([
      _table([
        _cell('Energy', 0, 0),
        _cell('1046 kJ', 0, 1),
        _cell('Fat', 1, 0),
        _cell('Salt', 2, 0),
        _cell('0,5 g', 2, 1),
        _cell('0,1 g', 2, 2),
      ]),
    ]);
    expect(_texts(rows), ['Energy|1046 kJ', 'Fat', 'Salt|0,5 g|0,1 g']);
  });

  test('puts a column span cell at its own box centre', () {
    final rows = adapter.adapt([
      _table([
        _cell('Nutrition', 0, 0, width: 0.9, columnSpan: 3, left: 0.05),
        _cell('Fat', 1, 0),
      ]),
    ]);
    expect(rows.first.tokens.single.centerX, closeTo(0.5, 1e-12));
  });

  test('lists a row-span cell once, in its first row', () {
    final rows = adapter.adapt([
      _table([
        _cell('Fat', 0, 0, rowSpan: 2),
        _cell('3 g', 0, 1),
        _cell('2 g', 1, 1),
      ]),
    ]);
    expect(_texts(rows), ['Fat|3 g', '2 g']);
  });

  test('orders cells by column even when listed out of order', () {
    final rows = adapter.adapt([
      _table([_cell('5 g', 0, 1), _cell('Protein', 0, 0)]),
    ]);
    expect(_texts(rows), ['Protein|5 g']);
  });

  test('keeps rows of several tables, top table first', () {
    final rows = adapter.adapt([
      _table([_cell('lower', 0, 0)], top: 0.6),
      _table([_cell('upper', 0, 0)], top: 0.1),
    ]);
    expect(_texts(rows), ['upper', 'lower']);
  });

  test('ignores a cell with a non-finite box', () {
    const nan = LabelRect(left: double.nan, top: 0, width: 0.1, height: 0.1);
    final rows = adapter.adapt([
      _table([
        const RecognizedCell(text: 'bad', box: nan, row: 0, column: 0),
        _cell('ok', 0, 1),
      ]),
    ]);
    expect(_texts(rows), ['ok']);
  });

  test('row box is the union of the cell boxes', () {
    final rows = adapter.adapt([
      _table([_cell('A', 0, 0), _cell('B', 0, 1)]),
    ]);
    expect(rows.single.box.left, closeTo(0.05, 1e-12));
    expect(rows.single.box.right, closeTo(0.35 + 0.2, 1e-12));
  });
}
