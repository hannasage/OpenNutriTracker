import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader/src/parser/label_row.dart';
import 'package:nutrition_label_reader/src/parser/serving_parser.dart';
import 'package:nutrition_label_reader/src/vocabulary/label_matcher.dart';

const _parser = ServingParser(LabelMatcher(englishLabelVocabulary));

LabelRow _row(String text) {
  const box = LabelRect(left: 0.1, top: 0.1, width: 0.8, height: 0.02);
  return LabelRow(
    tokens: [LabelToken(text: text, box: box)],
    box: box,
  );
}

ServingInfo? _parse(List<String> lines) =>
    _parser.parse(lines.map(_row).toList());

void main() {
  test('returns null when no row names a serving', () {
    expect(_parse(['Energy 1046 kJ', 'Protein 5 g']), isNull);
    expect(_parse([]), isNull);
  });

  test('reads 30 g', () {
    final s = _parse(['Serving size 30 g'])!;
    expect(s.rawText, '30 g');
    expect(s.amount, 30);
    expect(s.isMillilitres, isFalse);
    expect(s.servingsPerContainer, isNull);
  });

  test('reads 1 cup (240 ml)', () {
    final s = _parse(['Serving size 1 cup (240 ml)'])!;
    expect(s.rawText, '1 cup (240 ml)');
    expect(s.amount, 240);
    expect(s.isMillilitres, isTrue);
  });

  test('reads 2/3 cup (55 g) and ignores the 3 of 2/3', () {
    final s = _parse(['Serving size 2/3 cup (55 g)'])!;
    expect(s.rawText, '2/3 cup (55 g)');
    expect(s.amount, 55);
    expect(s.isMillilitres, isFalse);
  });

  test('keeps 1 slice with no amount', () {
    final s = _parse(['Serving size 1 slice'])!;
    expect(s.rawText, '1 slice');
    expect(s.amount, isNull);
    expect(s.isMillilitres, isFalse);
  });

  test('reads servings per container', () {
    final s = _parse(['Servings per container 8'])!;
    expect(s.servingsPerContainer, 8);
    expect(s.amount, isNull);
  });

  test('reads servings per container with a word before the number', () {
    expect(_parse(['Servings per container about 8'])!.servingsPerContainer, 8);
  });

  test('joins a size row and a container row', () {
    final s = _parse([
      'Servings per container 8',
      'Serving size 2/3 cup (55 g)',
    ])!;
    expect(s.rawText, '2/3 cup (55 g)');
    expect(s.amount, 55);
    expect(s.servingsPerContainer, 8);
  });

  test('accepts portion size, a colon and any case', () {
    final s = _parse(['PORTION SIZE: 25g'])!;
    expect(s.rawText, '25g');
    expect(s.amount, 25);
  });

  test('reads a comma decimal amount', () {
    expect(_parse(['Serving size 12,5 g'])!.amount, 12.5);
  });

  test('gives no amount for an ambiguous comma number', () {
    final s = _parse(['Serving size 1,234 g'])!;
    expect(s.rawText, '1,234 g');
    expect(s.amount, isNull);
  });

  test('does not read mg or kg as a serving amount', () {
    expect(_parse(['Serving size 5 mg'])!.amount, isNull);
    expect(_parse(['Serving size 2 kg'])!.amount, isNull);
  });

  test('skips a row with a phrase and nothing after it', () {
    expect(_parse(['Serving size']), isNull);
    expect(_parse(['Serving size:']), isNull);
  });

  test('uses the first size row when two exist', () {
    final s = _parse(['Serving size 30 g', 'Serving size 40 g'])!;
    expect(s.amount, 30);
  });

  test('works on a row of several tokens', () {
    const box = LabelRect(left: 0.1, top: 0.1, width: 0.4, height: 0.02);
    final row = LabelRow(
      tokens: const [
        LabelToken(text: 'Serving size', box: box),
        LabelToken(text: '30 g', box: box),
      ],
      box: box,
    );
    expect(_parser.parse([row])!.amount, 30);
  });
}
