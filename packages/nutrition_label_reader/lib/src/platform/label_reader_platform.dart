import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../model/reader_support.dart';
import '../model/recognized_document.dart';
import 'pigeon_label_reader.dart';
import 'recognize_options.dart';

/// The seam between the Dart package and the device. A test swaps in a fake.
abstract class NutritionLabelReaderPlatform extends PlatformInterface {
  NutritionLabelReaderPlatform() : super(token: _token);

  static final Object _token = Object();

  static NutritionLabelReaderPlatform _instance = PigeonLabelReader();

  static NutritionLabelReaderPlatform get instance => _instance;

  static set instance(NutritionLabelReaderPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<ReaderSupport> getSupport();

  /// Runs text recognition on the image at [path]. It returns recognized text.
  /// It reads no nutrition number.
  Future<RecognizedDocument> recognize(String path, RecognizeOptions options);
}
