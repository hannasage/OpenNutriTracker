import '../model/reader_support.dart';
import '../model/recognized_document.dart';
import 'label_reader_platform.dart';
import 'recognize_options.dart';

/// A platform for tests. It returns the values it was given and records its
/// calls. No channel, no device.
class FakeLabelReaderPlatform extends NutritionLabelReaderPlatform {
  FakeLabelReaderPlatform({
    this.support = const ReaderSupport(
      isAvailable: true,
      source: RecognitionSource.iosVisionText,
    ),
    this.document,
    this.error,
  });

  ReaderSupport support;

  /// What [recognize] returns. When null, [recognize] throws a [StateError].
  RecognizedDocument? document;

  /// When set, both methods throw it.
  Object? error;

  int supportCalls = 0;
  final List<String> recognizedPaths = [];
  final List<RecognizeOptions> recognizedOptions = [];

  @override
  Future<ReaderSupport> getSupport() async {
    supportCalls++;
    final failure = error;
    if (failure != null) throw failure;
    return support;
  }

  @override
  Future<RecognizedDocument> recognize(
    String path,
    RecognizeOptions options,
  ) async {
    recognizedPaths.add(path);
    recognizedOptions.add(options);
    final failure = error;
    if (failure != null) throw failure;
    final result = document;
    if (result == null) {
      throw StateError('FakeLabelReaderPlatform has no document to return.');
    }
    return result;
  }
}
