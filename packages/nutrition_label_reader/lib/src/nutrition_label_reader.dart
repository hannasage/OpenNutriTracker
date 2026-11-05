import 'package:flutter/services.dart';

import 'exceptions.dart';
import 'model/parse_result.dart';
import 'model/reader_support.dart';
import 'model/recognized_document.dart';
import 'parser/label_parser.dart';
import 'platform/label_reader_platform.dart';
import 'platform/message_mapper.dart';
import 'platform/recognize_options.dart';

/// Reads a nutrition label from an image file.
///
/// The device recognizes text. The [LabelParser] reads the numbers. A model
/// never gives a nutrition number. The reader keeps no photo. Native code
/// deletes any temp file it makes.
class NutritionLabelReader {
  NutritionLabelReader({
    NutritionLabelReaderPlatform? platform,
    LabelParser parser = const LabelParser(),
  }) : _platform = platform,
       _parser = parser;

  final NutritionLabelReaderPlatform? _platform;
  final LabelParser _parser;

  NutritionLabelReaderPlatform get _device =>
      _platform ?? NutritionLabelReaderPlatform.instance;

  /// What text recognition this device offers.
  ///
  /// Throws [LabelReaderException] on a platform error.
  Future<ReaderSupport> getSupport() async {
    try {
      return await _device.getSupport();
    } on PlatformException catch (error) {
      throw exceptionFromPlatform(error);
    }
  }

  /// Recognizes the text in the image at [path] and parses it.
  ///
  /// A label that was recognized and not read is a [LabelNotRead] result. It
  /// is not an exception. [LabelReaderException] means the device could not
  /// produce text, or produced geometry outside 0 to 1.
  Future<LabelParseResult> readImageFile(
    String path, {
    List<String> languageHints = const [],
    RecognitionSource? forceSource,
  }) async {
    final RecognizedDocument document;
    try {
      document = await _device.recognize(
        path,
        RecognizeOptions(
          languageHints: languageHints,
          forceSource: forceSource,
        ),
      );
    } on PlatformException catch (error) {
      throw exceptionFromPlatform(error);
    }
    try {
      document.validate();
    } on ArgumentError catch (error) {
      throw LabelReaderException(
        LabelReaderErrorCode.recognitionFailed,
        'The recognizer returned invalid geometry: ${error.message}',
      );
    }
    return _parser.parse(document);
  }

  /// Parses a recognized document. Pure and synchronous.
  LabelParseResult parseDocument(RecognizedDocument document) =>
      _parser.parse(document);
}
