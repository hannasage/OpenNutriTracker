import 'package:equatable/equatable.dart';

import '../model/recognized_document.dart';

/// Options for one recognition. The public twin of the Pigeon options message.
class RecognizeOptions extends Equatable {
  const RecognizeOptions({this.languageHints = const [], this.forceSource});

  /// BCP 47 tags, most likely first.
  final List<String> languageHints;

  /// A test and UAT switch to pick one recognizer.
  final RecognitionSource? forceSource;

  @override
  List<Object?> get props => [languageHints, forceSource];
}
