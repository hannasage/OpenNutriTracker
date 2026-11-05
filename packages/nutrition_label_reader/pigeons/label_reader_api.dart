// Pigeon schema for the text recognition bridge. This file is input to the
// generator and is not shipped with the package.
//
// Generate with these two commands, from the package folder:
//   dart run pigeon --input pigeons/label_reader_api.dart
//   dart format lib/src/platform/messages.g.dart
// The second command keeps lines within 80 columns. Pigeon does not do it.
//
// Geometry contract. Every rectangle is in normalized image space: x and y run
// from 0 to 1, the origin is the top-left corner, y grows downward, and the
// image orientation (EXIF) is already applied. Native code converts from its
// own space. Vision uses a bottom-left origin. ML Kit uses pixels.
//
// Native contract (for the native task):
// - Return flat line boxes in `boxes` on every source. The iOS documents
//   source also fills `tables`.
// - Run text recognition only. No language model.
// - Delete any temp file made. Never keep the image.
// - Report an error as a FlutterError with one of these codes: file_not_found,
//   decode_failed, unsupported_os, recognition_failed, cancelled.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/platform/messages.g.dart',
    dartPackageName: 'nutrition_label_reader',
  ),
)
enum RecognitionSourceMessage { iosDocuments, iosVisionText, androidMlKit }

class LabelRectMessage {
  LabelRectMessage({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double left;
  double top;
  double width;
  double height;
}

class TextBoxMessage {
  TextBoxMessage({required this.text, required this.box});

  String text;
  LabelRectMessage box;
}

class CellMessage {
  CellMessage({
    required this.text,
    required this.box,
    required this.row,
    required this.column,
    required this.rowSpan,
    required this.columnSpan,
  });

  String text;
  LabelRectMessage box;
  int row;
  int column;
  int rowSpan;
  int columnSpan;
}

class TableMessage {
  TableMessage({required this.box, required this.cells});

  LabelRectMessage box;

  /// Row-major.
  List<CellMessage> cells;
}

class RecognizedDocumentMessage {
  RecognizedDocumentMessage({
    required this.source,
    required this.imageWidth,
    required this.imageHeight,
    required this.boxes,
    required this.tables,
    required this.detectedLanguages,
    this.observationConfidence,
  });

  RecognitionSourceMessage source;

  /// Pixels. Used for the aspect ratio only.
  int imageWidth;
  int imageHeight;
  List<TextBoxMessage> boxes;
  List<TableMessage> tables;

  /// One value for the whole observation. Diagnostic only.
  double? observationConfidence;

  /// BCP 47 tags. May be empty.
  List<String> detectedLanguages;
}

class RecognizeOptionsMessage {
  RecognizeOptionsMessage({required this.languageHints, this.forceSource});

  List<String> languageHints;
  RecognitionSourceMessage? forceSource;
}

class SupportInfoMessage {
  SupportInfoMessage({
    required this.isAvailable,
    required this.supportedLanguages,
    this.source,
    this.osVersion,
  });

  bool isAvailable;
  RecognitionSourceMessage? source;
  String? osVersion;
  List<String> supportedLanguages;
}

@HostApi()
abstract class LabelReaderHostApi {
  @async
  SupportInfoMessage getSupportInfo();

  @async
  RecognizedDocumentMessage recognizeFile(
    String path,
    RecognizeOptionsMessage options,
  );
}
