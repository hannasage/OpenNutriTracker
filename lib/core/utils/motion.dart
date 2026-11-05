import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:opennutritracker/core/styles/dimens.dart';

/// [normal], or [Duration.zero] when the platform asks to reduce motion
/// (iOS "Reduce Motion", Android "Remove animations").
Duration motionDuration(BuildContext context, Duration normal) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : normal;

/// Scrolls at most once in the lifetime of one instance.
///
/// A detail screen keeps one in its `State`, so each visit starts with a
/// fresh turn. The first call scrolls; later calls do nothing. Scrolling
/// on every keystroke fights a person who is typing or has scrolled away.
class ScrollOncePerVisit {
  bool _hasScrolled = false;

  /// Whether this instance has already used its turn.
  bool get hasScrolled => _hasScrolled;

  /// Scrolls [controller] to [offset], clamped to the scrollable range.
  ///
  /// Animates for [AppMotion.durationShort] on [AppMotion.emphasized], or
  /// jumps when [reduceMotion] is true. Returns true if it scrolled. It
  /// returns false, and keeps its turn, when [controller] has no attached
  /// scroll view yet.
  bool scrollTo(
    ScrollController controller,
    double offset, {
    required bool reduceMotion,
  }) {
    if (_hasScrolled || !controller.hasClients) return false;
    _hasScrolled = true;
    final position = controller.position;
    final target = math.min(
      math.max(offset, position.minScrollExtent),
      position.maxScrollExtent,
    );
    if (reduceMotion) {
      controller.jumpTo(target);
    } else {
      controller.animateTo(
        target,
        duration: AppMotion.durationShort,
        curve: AppMotion.emphasized,
      );
    }
    return true;
  }
}
