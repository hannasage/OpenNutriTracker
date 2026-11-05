import 'package:equatable/equatable.dart';

import 'recognized_document.dart';

/// What the text recognizer on this device can do.
class ReaderSupport extends Equatable {
  const ReaderSupport({
    required this.isAvailable,
    this.source,
    this.osVersion,
    this.supportedLanguages = const [],
  });

  final bool isAvailable;

  /// The recognizer that would run. Null when none is available.
  final RecognitionSource? source;
  final String? osVersion;

  /// BCP 47 tags.
  final List<String> supportedLanguages;

  @override
  List<Object?> get props => [
    isAvailable,
    source,
    osVersion,
    supportedLanguages,
  ];
}
