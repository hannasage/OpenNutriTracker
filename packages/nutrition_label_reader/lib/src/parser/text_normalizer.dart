/// Maps special spaces to a plain space and both mu characters to one form.
///
/// It keeps case. It never changes a letter into a digit.
String normalizeText(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    switch (rune) {
      case 0x00a0: // no-break space
      case 0x202f: // narrow no-break space
      case 0x2009: // thin space
        buffer.write(' ');
      case 0x03bc: // Greek small letter mu
      case 0x00b5: // micro sign
        buffer.writeCharCode(0x00b5);
      default:
        buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Lowercases, collapses runs of white space and trims. For matching only.
/// Keep the original text for anything shown to a person.
String foldForMatching(String text) {
  return normalizeText(text)
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((part) {
        return part.isNotEmpty;
      })
      .join(' ');
}
