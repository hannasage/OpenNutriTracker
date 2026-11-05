/// Test support: the platform seam and a fake.
///
/// An app test sets `NutritionLabelReaderPlatform.instance` to a
/// `FakeLabelReaderPlatform`.
library;

export 'src/platform/fake_label_reader_platform.dart';
export 'src/platform/label_reader_platform.dart';
export 'src/platform/recognize_options.dart';
