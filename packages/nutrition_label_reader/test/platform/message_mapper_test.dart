import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader/src/platform/message_mapper.dart';
import 'package:nutrition_label_reader/src/platform/messages.g.dart';
import 'package:nutrition_label_reader/src/platform/pigeon_label_reader.dart';
import 'package:nutrition_label_reader/testing.dart';

LabelRectMessage _rect([double left = 0.1]) =>
    LabelRectMessage(left: left, top: 0.2, width: 0.3, height: 0.05);

void main() {
  group('recognition source', () {
    test('maps each value both ways', () {
      const pairs = {
        RecognitionSourceMessage.iosDocuments: RecognitionSource.iosDocuments,
        RecognitionSourceMessage.iosVisionText: RecognitionSource.iosVisionText,
        RecognitionSourceMessage.androidMlKit: RecognitionSource.androidMlKit,
      };
      expect(pairs.length, RecognitionSourceMessage.values.length);
      expect(pairs.length, RecognitionSource.values.length);
      pairs.forEach((message, source) {
        expect(recognitionSourceFromMessage(message), source);
        expect(recognitionSourceToMessage(source), message);
      });
    });
  });

  group('recognized document', () {
    test('maps boxes, tables, cells and the diagnostic fields', () {
      final message = RecognizedDocumentMessage(
        source: RecognitionSourceMessage.iosDocuments,
        imageWidth: 1000,
        imageHeight: 1500,
        boxes: [TextBoxMessage(text: 'Protein', box: _rect())],
        tables: [
          TableMessage(
            box: _rect(0),
            cells: [
              CellMessage(
                text: 'Fat',
                box: _rect(0.2),
                row: 1,
                column: 2,
                rowSpan: 3,
                columnSpan: 4,
              ),
            ],
          ),
        ],
        observationConfidence: 0.75,
        detectedLanguages: ['en', 'de'],
      );
      final document = recognizedDocumentFromMessage(message);
      expect(document.source, RecognitionSource.iosDocuments);
      expect(document.imageWidth, 1000);
      expect(document.imageHeight, 1500);
      expect(document.boxes, [
        const RecognizedTextBox(
          text: 'Protein',
          box: LabelRect(left: 0.1, top: 0.2, width: 0.3, height: 0.05),
        ),
      ]);
      expect(document.tables.single.box.left, 0);
      expect(
        document.tables.single.cells.single,
        const RecognizedCell(
          text: 'Fat',
          box: LabelRect(left: 0.2, top: 0.2, width: 0.3, height: 0.05),
          row: 1,
          column: 2,
          rowSpan: 3,
          columnSpan: 4,
        ),
      );
      expect(document.observationConfidence, 0.75);
      expect(document.detectedLanguages, ['en', 'de']);
      expect(document.validate, returnsNormally);
    });

    test('maps a document with nothing optional', () {
      final document = recognizedDocumentFromMessage(
        RecognizedDocumentMessage(
          source: RecognitionSourceMessage.androidMlKit,
          imageWidth: 10,
          imageHeight: 20,
          boxes: [],
          tables: [],
          detectedLanguages: [],
        ),
      );
      expect(document.boxes, isEmpty);
      expect(document.tables, isEmpty);
      expect(document.observationConfidence, isNull);
      expect(document.detectedLanguages, isEmpty);
    });

    test('keeps the order of boxes', () {
      final document = recognizedDocumentFromMessage(
        RecognizedDocumentMessage(
          source: RecognitionSourceMessage.iosVisionText,
          imageWidth: 10,
          imageHeight: 20,
          boxes: [
            for (var i = 0; i < 50; i++)
              TextBoxMessage(text: 'b$i', box: _rect()),
          ],
          tables: [],
          detectedLanguages: [],
        ),
      );
      expect(document.boxes.map((b) => b.text), [
        for (var i = 0; i < 50; i++) 'b$i',
      ]);
    });

    test('out-of-range coordinates make validate throw', () {
      final document = recognizedDocumentFromMessage(
        RecognizedDocumentMessage(
          source: RecognitionSourceMessage.iosVisionText,
          imageWidth: 10,
          imageHeight: 20,
          boxes: [TextBoxMessage(text: 'x', box: _rect(1.5))],
          tables: [],
          detectedLanguages: [],
        ),
      );
      expect(document.validate, throwsArgumentError);
    });

    test('the mapper does not repair or drop what it is given', () {
      final document = recognizedDocumentFromMessage(
        RecognizedDocumentMessage(
          source: RecognitionSourceMessage.iosVisionText,
          imageWidth: 0,
          imageHeight: 20,
          boxes: [TextBoxMessage(text: '', box: _rect(-1))],
          tables: [],
          detectedLanguages: [],
        ),
      );
      expect(document.boxes, hasLength(1));
      expect(document.imageWidth, 0);
      expect(document.validate, throwsArgumentError);
    });
  });

  group('support info', () {
    test('maps every field', () {
      final support = readerSupportFromMessage(
        SupportInfoMessage(
          isAvailable: true,
          source: RecognitionSourceMessage.iosVisionText,
          osVersion: '18.2',
          supportedLanguages: ['en'],
        ),
      );
      expect(
        support,
        const ReaderSupport(
          isAvailable: true,
          source: RecognitionSource.iosVisionText,
          osVersion: '18.2',
          supportedLanguages: ['en'],
        ),
      );
    });

    test('maps an unavailable reader with no source', () {
      final support = readerSupportFromMessage(
        SupportInfoMessage(isAvailable: false, supportedLanguages: []),
      );
      expect(support.isAvailable, isFalse);
      expect(support.source, isNull);
      expect(support.osVersion, isNull);
      expect(support.supportedLanguages, isEmpty);
    });
  });

  group('options', () {
    test('maps hints and a forced source', () {
      final message = recognizeOptionsToMessage(
        const RecognizeOptions(
          languageHints: ['de', 'en'],
          forceSource: RecognitionSource.iosVisionText,
        ),
      );
      expect(message.languageHints, ['de', 'en']);
      expect(message.forceSource, RecognitionSourceMessage.iosVisionText);
    });

    test('maps the defaults', () {
      final message = recognizeOptionsToMessage(const RecognizeOptions());
      expect(message.languageHints, isEmpty);
      expect(message.forceSource, isNull);
    });
  });

  group('error codes', () {
    test('maps each platform code', () {
      const codes = {
        'file_not_found': LabelReaderErrorCode.fileNotFound,
        'decode_failed': LabelReaderErrorCode.decodeFailed,
        'unsupported_os': LabelReaderErrorCode.unsupportedOs,
        'recognition_failed': LabelReaderErrorCode.recognitionFailed,
        'cancelled': LabelReaderErrorCode.cancelled,
      };
      expect(codes.length, LabelReaderErrorCode.values.length);
      codes.forEach((code, expected) {
        expect(errorCodeFromPlatform(code), expected, reason: code);
      });
    });

    test('an unknown code becomes recognitionFailed', () {
      expect(
        errorCodeFromPlatform('boom'),
        LabelReaderErrorCode.recognitionFailed,
      );
      expect(errorCodeFromPlatform(''), LabelReaderErrorCode.recognitionFailed);
    });

    test('a platform exception keeps its code and message', () {
      final exception = exceptionFromPlatform(
        PlatformException(code: 'decode_failed', message: 'bad jpeg'),
      );
      expect(exception.code, LabelReaderErrorCode.decodeFailed);
      expect(exception.message, 'bad jpeg');
    });

    test('an unknown code keeps the original code in the message', () {
      final exception = exceptionFromPlatform(
        PlatformException(code: 'boom', message: 'oops'),
      );
      expect(exception.code, LabelReaderErrorCode.recognitionFailed);
      expect(exception.message, contains('boom'));
      expect(exception.message, contains('oops'));
    });
  });

  group('LabelReaderException', () {
    test('prints its code and message', () {
      expect(
        const LabelReaderException(
          LabelReaderErrorCode.cancelled,
          'stop',
        ).toString(),
        contains('cancelled'),
      );
      expect(
        const LabelReaderException(
          LabelReaderErrorCode.cancelled,
          'stop',
        ).toString(),
        contains('stop'),
      );
      expect(
        const LabelReaderException(LabelReaderErrorCode.cancelled).toString(),
        contains('cancelled'),
      );
    });
  });

  group('ReaderSupport', () {
    test('defaults and equality', () {
      const support = ReaderSupport(isAvailable: true);
      expect(support.source, isNull);
      expect(support.osVersion, isNull);
      expect(support.supportedLanguages, isEmpty);
      expect(support, const ReaderSupport(isAvailable: true));
      expect(support, isNot(const ReaderSupport(isAvailable: false)));
    });
  });

  group('PigeonLabelReader', () {
    test(
      'passes the path and options to the host API and maps the reply',
      () async {
        final api = _FakeHostApi();
        final reader = PigeonLabelReader(api: api);
        final document = await reader.recognize(
          '/tmp/label.jpg',
          const RecognizeOptions(languageHints: ['en']),
        );
        expect(api.paths, ['/tmp/label.jpg']);
        expect(api.options.single.languageHints, ['en']);
        expect(document.boxes.single.text, 'Protein');
      },
    );

    test('maps the support reply', () async {
      final reader = PigeonLabelReader(api: _FakeHostApi());
      final support = await reader.getSupport();
      expect(support.isAvailable, isTrue);
      expect(support.source, RecognitionSource.androidMlKit);
    });

    test('lets a platform exception through', () {
      final reader = PigeonLabelReader(
        api: _FakeHostApi(error: PlatformException(code: 'cancelled')),
      );
      expect(
        reader.recognize('/x', const RecognizeOptions()),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('platform interface', () {
    test('the default instance is the Pigeon reader', () {
      expect(NutritionLabelReaderPlatform.instance, isA<PigeonLabelReader>());
    });

    test('accepts a fake', () {
      final original = NutritionLabelReaderPlatform.instance;
      addTearDown(() => NutritionLabelReaderPlatform.instance = original);
      final fake = FakeLabelReaderPlatform();
      NutritionLabelReaderPlatform.instance = fake;
      expect(NutritionLabelReaderPlatform.instance, same(fake));
    });
  });

  group('FakeLabelReaderPlatform', () {
    test('returns what it was given and records calls', () async {
      const document = RecognizedDocument(
        source: RecognitionSource.androidMlKit,
        imageWidth: 1,
        imageHeight: 1,
        boxes: [],
      );
      final fake = FakeLabelReaderPlatform(document: document);
      expect((await fake.getSupport()).isAvailable, isTrue);
      expect(await fake.recognize('/a', const RecognizeOptions()), document);
      expect(fake.recognizedPaths, ['/a']);
      expect(fake.supportCalls, 1);
    });

    test('throws the error it was given', () {
      final fake = FakeLabelReaderPlatform(error: StateError('x'));
      expect(fake.getSupport(), throwsStateError);
      expect(fake.recognize('/a', const RecognizeOptions()), throwsStateError);
    });

    test('says so when it has no document', () {
      final fake = FakeLabelReaderPlatform();
      expect(fake.recognize('/a', const RecognizeOptions()), throwsStateError);
    });
  });
}

class _FakeHostApi extends LabelReaderHostApi {
  _FakeHostApi({this.error});

  final Object? error;
  final paths = <String>[];
  final options = <RecognizeOptionsMessage>[];

  @override
  Future<SupportInfoMessage> getSupportInfo() async => SupportInfoMessage(
    isAvailable: true,
    source: RecognitionSourceMessage.androidMlKit,
    supportedLanguages: ['en'],
  );

  @override
  Future<RecognizedDocumentMessage> recognizeFile(
    String path,
    RecognizeOptionsMessage options,
  ) async {
    if (error != null) throw error!;
    paths.add(path);
    this.options.add(options);
    return RecognizedDocumentMessage(
      source: RecognitionSourceMessage.androidMlKit,
      imageWidth: 10,
      imageHeight: 10,
      boxes: [TextBoxMessage(text: 'Protein', box: _rect())],
      tables: [],
      detectedLanguages: [],
    );
  }
}
