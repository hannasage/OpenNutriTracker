import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader/testing.dart';

import 'fixtures/eu_one_column.dart';
import 'fixtures/fixture_builder.dart';

const _menu = FixtureGrid([
  ['Test menu'],
  ['Soup of the day', '\$4.50'],
  ['House salad', '\$6'],
  ['Grilled cheese', '\$7.25'],
  ['Iced tea', '\$2'],
]);

void main() {
  group('readImageFile', () {
    test('returns the parse of what the platform recognized', () async {
      final fake = FakeLabelReaderPlatform(
        document: euOneColumn.asSeparateBoxes(),
      );
      final reader = NutritionLabelReader(platform: fake);
      final result = await reader.readImageFile('/tmp/label.jpg');
      expect(result, isA<LabelParsed>());
      final label = (result as LabelParsed).label;
      expect(label.nutrient(NutrientId.fat)!.per100!.value, 3.5);
      expect(label.nutrient(NutrientId.protein)!.per100!.value, 10);
    });

    test('is the same as parsing the document directly', () async {
      final document = euOneColumn.asTable();
      final reader = NutritionLabelReader(
        platform: FakeLabelReaderPlatform(document: document),
      );
      expect(await reader.readImageFile('/x'), reader.parseDocument(document));
    });

    test('passes the path, hints and forced source to the platform', () async {
      final fake = FakeLabelReaderPlatform(
        document: euOneColumn.asSeparateBoxes(),
      );
      await NutritionLabelReader(platform: fake).readImageFile(
        '/tmp/a.jpg',
        languageHints: const ['de', 'en'],
        forceSource: RecognitionSource.iosVisionText,
      );
      expect(fake.recognizedPaths, ['/tmp/a.jpg']);
      expect(
        fake.recognizedOptions.single,
        const RecognizeOptions(
          languageHints: ['de', 'en'],
          forceSource: RecognitionSource.iosVisionText,
        ),
      );
    });

    test('passes no hints and no forced source by default', () async {
      final fake = FakeLabelReaderPlatform(
        document: euOneColumn.asSeparateBoxes(),
      );
      await NutritionLabelReader(platform: fake).readImageFile('/x');
      expect(fake.recognizedOptions.single, const RecognizeOptions());
    });

    test('a label that was not read is a result, not an exception', () async {
      final reader = NutritionLabelReader(
        platform: FakeLabelReaderPlatform(document: _menu.asSeparateBoxes()),
      );
      final result = await reader.readImageFile('/x');
      expect(result, isA<LabelNotRead>());
      expect(
        (result as LabelNotRead).reason,
        LabelFailureReason.noNutritionPanel,
      );
    });

    test('a platform exception becomes a LabelReaderException', () {
      final reader = NutritionLabelReader(
        platform: FakeLabelReaderPlatform(
          error: PlatformException(code: 'file_not_found', message: 'no file'),
        ),
      );
      expect(
        reader.readImageFile('/missing'),
        throwsA(
          isA<LabelReaderException>()
              .having((e) => e.code, 'code', LabelReaderErrorCode.fileNotFound)
              .having((e) => e.message, 'message', 'no file'),
        ),
      );
    });

    test('every platform code maps to its error code', () async {
      const codes = {
        'file_not_found': LabelReaderErrorCode.fileNotFound,
        'decode_failed': LabelReaderErrorCode.decodeFailed,
        'unsupported_os': LabelReaderErrorCode.unsupportedOs,
        'recognition_failed': LabelReaderErrorCode.recognitionFailed,
        'cancelled': LabelReaderErrorCode.cancelled,
      };
      for (final entry in codes.entries) {
        final reader = NutritionLabelReader(
          platform: FakeLabelReaderPlatform(
            error: PlatformException(code: entry.key),
          ),
        );
        await expectLater(
          reader.readImageFile('/x'),
          throwsA(
            isA<LabelReaderException>().having(
              (e) => e.code,
              'code',
              entry.value,
            ),
          ),
          reason: entry.key,
        );
      }
    });

    test('a LabelReaderException from the platform passes through', () {
      const error = LabelReaderException(LabelReaderErrorCode.cancelled);
      final reader = NutritionLabelReader(
        platform: FakeLabelReaderPlatform(error: error),
      );
      expect(reader.readImageFile('/x'), throwsA(same(error)));
    });

    test('an error that is not a platform error is not hidden', () {
      final reader = NutritionLabelReader(
        platform: FakeLabelReaderPlatform(error: StateError('bug')),
      );
      expect(reader.readImageFile('/x'), throwsStateError);
    });

    test('geometry outside 0 to 1 becomes recognitionFailed', () {
      const bad = RecognizedDocument(
        source: RecognitionSource.androidMlKit,
        imageWidth: 100,
        imageHeight: 100,
        boxes: [
          RecognizedTextBox(
            text: 'x',
            box: LabelRect(left: 2, top: 0, width: 0.1, height: 0.1),
          ),
        ],
      );
      final reader = NutritionLabelReader(
        platform: FakeLabelReaderPlatform(document: bad),
      );
      expect(
        reader.readImageFile('/x'),
        throwsA(
          isA<LabelReaderException>()
              .having(
                (e) => e.code,
                'code',
                LabelReaderErrorCode.recognitionFailed,
              )
              .having((e) => e.message, 'message', contains('geometry')),
        ),
      );
    });

    test('uses the parser it was given', () async {
      final document = euOneColumn.asSeparateBoxes();
      final strict = NutritionLabelReader(
        platform: FakeLabelReaderPlatform(document: document),
        parser: const LabelParser(config: ParserConfig(minNutrientNames: 50)),
      );
      expect(await strict.readImageFile('/x'), isA<LabelNotRead>());
    });
  });

  group('getSupport', () {
    test('passes the platform answer through', () async {
      const support = ReaderSupport(
        isAvailable: true,
        source: RecognitionSource.androidMlKit,
        osVersion: '14',
        supportedLanguages: ['en'],
      );
      final reader = NutritionLabelReader(
        platform: FakeLabelReaderPlatform(support: support),
      );
      expect(await reader.getSupport(), support);
    });

    test('reports an unavailable reader', () async {
      final reader = NutritionLabelReader(
        platform: FakeLabelReaderPlatform(
          support: const ReaderSupport(isAvailable: false),
        ),
      );
      expect((await reader.getSupport()).isAvailable, isFalse);
    });

    test('a platform exception becomes a LabelReaderException', () {
      final reader = NutritionLabelReader(
        platform: FakeLabelReaderPlatform(
          error: PlatformException(code: 'unsupported_os'),
        ),
      );
      expect(
        reader.getSupport(),
        throwsA(
          isA<LabelReaderException>().having(
            (e) => e.code,
            'code',
            LabelReaderErrorCode.unsupportedOs,
          ),
        ),
      );
    });
  });

  group('platform choice', () {
    test('uses the current platform instance when none is given', () async {
      final original = NutritionLabelReaderPlatform.instance;
      addTearDown(() => NutritionLabelReaderPlatform.instance = original);
      final reader = NutritionLabelReader();
      final fake = FakeLabelReaderPlatform(
        support: const ReaderSupport(isAvailable: false),
      );
      NutritionLabelReaderPlatform.instance = fake;
      expect((await reader.getSupport()).isAvailable, isFalse);
      expect(fake.supportCalls, 1);
    });
  });

  group('parseDocument', () {
    test('is pure and needs no platform', () {
      final reader = NutritionLabelReader(
        platform: FakeLabelReaderPlatform(error: StateError('unused')),
      );
      final result = reader.parseDocument(euOneColumn.asTable());
      expect(result, isA<LabelParsed>());
    });
  });
}
