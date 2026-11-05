import '../model/reader_support.dart';
import '../model/recognized_document.dart';
import 'label_reader_platform.dart';
import 'message_mapper.dart';
import 'messages.g.dart';
import 'recognize_options.dart';

/// The platform implementation over the Pigeon host API.
///
/// A platform error reaches the caller as a `PlatformException`. The facade
/// turns it into a `LabelReaderException`.
class PigeonLabelReader extends NutritionLabelReaderPlatform {
  PigeonLabelReader({LabelReaderHostApi? api})
    : _api = api ?? LabelReaderHostApi();

  final LabelReaderHostApi _api;

  @override
  Future<ReaderSupport> getSupport() async {
    return readerSupportFromMessage(await _api.getSupportInfo());
  }

  @override
  Future<RecognizedDocument> recognize(
    String path,
    RecognizeOptions options,
  ) async {
    final message = await _api.recognizeFile(
      path,
      recognizeOptionsToMessage(options),
    );
    return recognizedDocumentFromMessage(message);
  }
}
