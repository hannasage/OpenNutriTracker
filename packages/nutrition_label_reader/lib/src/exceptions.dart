/// Why the device could not produce recognized text.
enum LabelReaderErrorCode {
  fileNotFound,
  decodeFailed,
  unsupportedOs,
  recognitionFailed,
  cancelled,
}

/// A failure to get recognized text. A label that was recognized and not
/// read is not an exception. It is a `LabelNotRead` result.
class LabelReaderException implements Exception {
  const LabelReaderException(this.code, [this.message]);

  final LabelReaderErrorCode code;
  final String? message;

  @override
  String toString() {
    final text = message;
    return text == null
        ? 'LabelReaderException(${code.name})'
        : 'LabelReaderException(${code.name}): $text';
  }
}
