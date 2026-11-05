import 'package:flutter/services.dart';

import '../exceptions.dart';
import '../model/label_rect.dart';
import '../model/reader_support.dart';
import '../model/recognized_document.dart';
import 'messages.g.dart';
import 'recognize_options.dart';

/// Maps Pigeon messages to the public types and back. A mapper copies what it
/// is given. It does not check geometry (call `RecognizedDocument.validate`),
/// and it does not drop or repair a field.

RecognitionSource recognitionSourceFromMessage(
  RecognitionSourceMessage message,
) {
  switch (message) {
    case RecognitionSourceMessage.iosDocuments:
      return RecognitionSource.iosDocuments;
    case RecognitionSourceMessage.iosVisionText:
      return RecognitionSource.iosVisionText;
    case RecognitionSourceMessage.androidMlKit:
      return RecognitionSource.androidMlKit;
  }
}

RecognitionSourceMessage recognitionSourceToMessage(RecognitionSource source) {
  switch (source) {
    case RecognitionSource.iosDocuments:
      return RecognitionSourceMessage.iosDocuments;
    case RecognitionSource.iosVisionText:
      return RecognitionSourceMessage.iosVisionText;
    case RecognitionSource.androidMlKit:
      return RecognitionSourceMessage.androidMlKit;
  }
}

LabelRect labelRectFromMessage(LabelRectMessage message) => LabelRect(
  left: message.left,
  top: message.top,
  width: message.width,
  height: message.height,
);

RecognizedDocument recognizedDocumentFromMessage(
  RecognizedDocumentMessage message,
) {
  return RecognizedDocument(
    source: recognitionSourceFromMessage(message.source),
    imageWidth: message.imageWidth,
    imageHeight: message.imageHeight,
    boxes: [
      for (final box in message.boxes)
        RecognizedTextBox(text: box.text, box: labelRectFromMessage(box.box)),
    ],
    tables: [
      for (final table in message.tables)
        RecognizedTable(
          box: labelRectFromMessage(table.box),
          cells: [
            for (final cell in table.cells)
              RecognizedCell(
                text: cell.text,
                box: labelRectFromMessage(cell.box),
                row: cell.row,
                column: cell.column,
                rowSpan: cell.rowSpan,
                columnSpan: cell.columnSpan,
              ),
          ],
        ),
    ],
    observationConfidence: message.observationConfidence,
    detectedLanguages: List.of(message.detectedLanguages),
  );
}

ReaderSupport readerSupportFromMessage(SupportInfoMessage message) {
  final source = message.source;
  return ReaderSupport(
    isAvailable: message.isAvailable,
    source: source == null ? null : recognitionSourceFromMessage(source),
    osVersion: message.osVersion,
    supportedLanguages: List.of(message.supportedLanguages),
  );
}

RecognizeOptionsMessage recognizeOptionsToMessage(RecognizeOptions options) {
  final source = options.forceSource;
  return RecognizeOptionsMessage(
    languageHints: List.of(options.languageHints),
    forceSource: source == null ? null : recognitionSourceToMessage(source),
  );
}

/// Maps a platform error code. An unknown code becomes `recognitionFailed`.
LabelReaderErrorCode errorCodeFromPlatform(String code) {
  switch (code) {
    case 'file_not_found':
      return LabelReaderErrorCode.fileNotFound;
    case 'decode_failed':
      return LabelReaderErrorCode.decodeFailed;
    case 'unsupported_os':
      return LabelReaderErrorCode.unsupportedOs;
    case 'recognition_failed':
      return LabelReaderErrorCode.recognitionFailed;
    case 'cancelled':
      return LabelReaderErrorCode.cancelled;
  }
  return LabelReaderErrorCode.recognitionFailed;
}

/// Wraps a platform error. An unknown code stays visible in the message.
LabelReaderException exceptionFromPlatform(PlatformException error) {
  final code = errorCodeFromPlatform(error.code);
  final known = const {
    'file_not_found',
    'decode_failed',
    'unsupported_os',
    'recognition_failed',
    'cancelled',
  }.contains(error.code);
  final message = known
      ? error.message
      : 'platform error "${error.code}"'
            '${error.message == null ? '' : ': ${error.message}'}';
  return LabelReaderException(code, message);
}
