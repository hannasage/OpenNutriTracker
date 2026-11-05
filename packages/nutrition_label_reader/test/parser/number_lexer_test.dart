import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/src/parser/number_lexer.dart';

void main() {
  group('plain numbers', () {
    const cases = <String, double>{
      '3.5': 3.5,
      '3,5': 3.5,
      '0,5': 0.5,
      '0.5': 0.5,
      '.5': 0.5,
      ',5': 0.5,
      '10': 10,
      '0': 0,
      '1046': 1046,
      '0,123': 0.123,
      '12345,678': 12345.678,
      '  7  ': 7,
    };
    cases.forEach((text, expected) {
      test('"$text" reads as $expected', () {
        final r = NumberLexer.read(text);
        expect(r.status, NumberStatus.value);
        expect(r.value, expected);
        expect(r.isUpperBound, isFalse);
      });
    });
  });

  group('both marks', () {
    test('1.234,5 is 1234.5', () {
      final r = NumberLexer.read('1.234,5');
      expect(r.status, NumberStatus.value);
      expect(r.value, 1234.5);
    });

    test('1,234.5 is 1234.5', () {
      final r = NumberLexer.read('1,234.5');
      expect(r.status, NumberStatus.value);
      expect(r.value, 1234.5);
    });

    test('a repeated mark with valid groups is a thousands mark', () {
      expect(NumberLexer.read('1,234,567').value, 1234567);
      expect(NumberLexer.read('1.234.567').value, 1234567);
    });

    test('bad grouping is unreadable', () {
      for (final text in ['1,23,4.5', '1.2,345,6', '3.5.2', '1,2,3']) {
        final r = NumberLexer.read(text);
        expect(r.status, NumberStatus.unreadable, reason: text);
        expect(r.value, isNull, reason: text);
      }
    });
  });

  group('one comma and three digits', () {
    test('is ambiguous when nothing decides', () {
      final r = NumberLexer.read('1,234');
      expect(r.status, NumberStatus.ambiguous);
      expect(r.value, isNull);
      expect(r.readings, [1.234, 1234]);
    });

    test('takes the only plausible reading', () {
      final r = NumberLexer.read('1,234', isPlausible: (v) => v > 100);
      expect(r.status, NumberStatus.value);
      expect(r.value, 1234);
      final small = NumberLexer.read('1,234', isPlausible: (v) => v <= 100);
      expect(small.status, NumberStatus.value);
      expect(small.value, 1.234);
    });

    test('stays ambiguous when both readings are plausible', () {
      final r = NumberLexer.read('1,234', isPlausible: (v) => v < 4000);
      expect(r.status, NumberStatus.ambiguous);
      expect(r.value, isNull);
    });

    test('stays ambiguous when neither reading is plausible', () {
      final r = NumberLexer.read('1,234', isPlausible: (v) => false);
      expect(r.status, NumberStatus.ambiguous);
      expect(r.value, isNull);
    });

    test('a leading zero or a long head is not a thousands group', () {
      expect(NumberLexer.read('0,123').status, NumberStatus.value);
      expect(NumberLexer.read('1234,567').status, NumberStatus.value);
    });

    test('a dot with three digits is a decimal', () {
      final r = NumberLexer.read('1.234');
      expect(r.status, NumberStatus.value);
      expect(r.value, 1.234);
    });
  });

  group('upper bound', () {
    test('<0.5 and < 0.5', () {
      for (final text in ['<0.5', '< 0.5', '<0,5']) {
        final r = NumberLexer.read(text);
        expect(r.status, NumberStatus.value, reason: text);
        expect(r.value, 0.5, reason: text);
        expect(r.isUpperBound, isTrue, reason: text);
      }
    });

    test('a bare < is not a number', () {
      expect(NumberLexer.read('<').status, NumberStatus.notNumeric);
    });
  });

  group('absent words', () {
    test('trace, nil, - and n/a carry no value', () {
      for (final text in ['trace', 'Trace', 'nil', 'NIL', '-', 'n/a', 'N/A']) {
        final r = NumberLexer.read(text);
        expect(r.status, NumberStatus.absent, reason: text);
        expect(r.value, isNull, reason: text);
      }
    });
  });

  group('no repair', () {
    test('digits with letters are unreadable', () {
      for (final text in [
        '1O',
        'l2',
        '5S',
        'O.5',
        '1 234',
        '-5',
        '5.',
        '1e3',
      ]) {
        final r = NumberLexer.read(text);
        expect(r.status, NumberStatus.unreadable, reason: text);
        expect(r.value, isNull, reason: text);
      }
    });

    test('text without digits is not numeric', () {
      for (final text in ['', '   ', 'Protein', 'g', 'O', 'l']) {
        final r = NumberLexer.read(text);
        expect(r.status, NumberStatus.notNumeric, reason: text);
        expect(r.value, isNull, reason: text);
      }
    });

    test('a huge digit run is unreadable, not infinity', () {
      final r = NumberLexer.read('9' * 400);
      expect(r.status, NumberStatus.unreadable);
      expect(r.value, isNull);
    });

    test('non-ASCII digits are not read', () {
      expect(NumberLexer.read('٣').status, NumberStatus.notNumeric);
    });
  });

  test('keeps the raw text', () {
    expect(NumberLexer.read(' <0,5 ').rawText, '<0,5');
  });
}
