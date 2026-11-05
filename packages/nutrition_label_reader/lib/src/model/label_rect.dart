import 'package:equatable/equatable.dart';

/// A rectangle in normalized image space.
///
/// x and y run from 0 to 1. The origin is the top-left corner and y grows
/// downward. Native code applies the image orientation before it builds a
/// rectangle.
class LabelRect extends Equatable {
  const LabelRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;

  @override
  List<Object?> get props => [left, top, width, height];

  @override
  String toString() =>
      'LabelRect(left: $left, top: $top, width: $width, height: $height)';
}
