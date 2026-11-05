import 'package:equatable/equatable.dart';

import '../model/label_rect.dart';

/// A piece of text in a row, with its place on the page.
class LabelToken extends Equatable {
  const LabelToken({
    required this.text,
    required this.box,
    this.estimatedX = false,
  });

  final String text;
  final LabelRect box;

  /// True when the position was estimated from character counts inside a
  /// merged line. It is not a measured position.
  final bool estimatedX;

  double get centerX => box.centerX;

  @override
  List<Object?> get props => [text, box, estimatedX];
}

/// An ordered row of tokens. Every rule after row building works on this type
/// only, so one parser serves every recognition source.
class LabelRow extends Equatable {
  const LabelRow({required this.tokens, required this.box});

  final List<LabelToken> tokens;
  final LabelRect box;

  /// The token texts joined by a space.
  String get text => tokens.map((t) => t.text).join(' ');

  @override
  List<Object?> get props => [tokens, box];
}

/// The smallest rectangle that holds every rectangle in [rects].
/// [rects] must not be empty.
LabelRect unionOf(Iterable<LabelRect> rects) {
  var left = double.infinity;
  var top = double.infinity;
  var right = double.negativeInfinity;
  var bottom = double.negativeInfinity;
  for (final rect in rects) {
    if (rect.left < left) left = rect.left;
    if (rect.top < top) top = rect.top;
    if (rect.right > right) right = rect.right;
    if (rect.bottom > bottom) bottom = rect.bottom;
  }
  return LabelRect(
    left: left,
    top: top,
    width: right - left,
    height: bottom - top,
  );
}

/// True when every coordinate of [rect] is a finite number.
bool isFiniteRect(LabelRect rect) =>
    rect.left.isFinite &&
    rect.top.isFinite &&
    rect.width.isFinite &&
    rect.height.isFinite;
