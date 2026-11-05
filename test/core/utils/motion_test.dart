import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/styles/dimens.dart';
import 'package:opennutritracker/core/utils/motion.dart';

const double _target = 300;

/// Pumps a tall list so [controller] has room to scroll to [_target].
Future<void> _pumpList(WidgetTester tester, ScrollController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ListView(
        controller: controller,
        children: const [SizedBox(height: 3000)],
      ),
    ),
  );
}

void main() {
  group('ScrollOncePerVisit', () {
    late ScrollController controller;

    setUp(() => controller = ScrollController());
    tearDown(() => controller.dispose());

    testWidgets('the first edit scrolls in 200 ms and decelerates', (
      tester,
    ) async {
      await _pumpList(tester, controller);
      final once = ScrollOncePerVisit();

      final scrolled = once.scrollTo(controller, _target, reduceMotion: false);
      await tester.pump(); // starts the animation
      await tester.pump(AppMotion.durationShort ~/ 2);

      expect(scrolled, isTrue);
      // Halfway through the time, a decelerating curve is past halfway
      // through the distance; the old easeInOut sat at exactly half.
      expect(controller.offset, greaterThan(_target / 2));
      expect(controller.offset, lessThan(_target));

      await tester.pump(AppMotion.durationShort ~/ 2);
      expect(controller.offset, _target);
      expect(AppMotion.durationShort, const Duration(milliseconds: 200));
    });

    testWidgets('a second edit does not scroll', (tester) async {
      await _pumpList(tester, controller);
      final once = ScrollOncePerVisit();
      once.scrollTo(controller, _target, reduceMotion: false);
      await tester.pumpAndSettle();
      controller.jumpTo(10); // the user scrolled back up by hand

      final scrolled = once.scrollTo(controller, _target, reduceMotion: false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(scrolled, isFalse);
      expect(controller.offset, 10);
    });

    testWidgets('reduced motion jumps at once', (tester) async {
      await _pumpList(tester, controller);
      final once = ScrollOncePerVisit();

      final scrolled = once.scrollTo(controller, _target, reduceMotion: true);

      // No pump: a jump has already landed, an animation has not.
      expect(scrolled, isTrue);
      expect(controller.offset, _target);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('reduced motion still scrolls only once', (tester) async {
      await _pumpList(tester, controller);
      final once = ScrollOncePerVisit();
      once.scrollTo(controller, _target, reduceMotion: true);
      controller.jumpTo(10);

      final scrolled = once.scrollTo(controller, _target, reduceMotion: true);

      expect(scrolled, isFalse);
      expect(controller.offset, 10);
    });

    testWidgets('a new instance, a new visit, scrolls again', (tester) async {
      await _pumpList(tester, controller);
      ScrollOncePerVisit().scrollTo(controller, _target, reduceMotion: true);
      controller.jumpTo(0);

      final scrolled = ScrollOncePerVisit().scrollTo(
        controller,
        _target,
        reduceMotion: true,
      );

      expect(scrolled, isTrue);
      expect(controller.offset, _target);
    });

    test('with nothing to scroll it does nothing and keeps its turn', () {
      final once = ScrollOncePerVisit();

      expect(once.scrollTo(controller, _target, reduceMotion: false), isFalse);
      expect(once.hasScrolled, isFalse);
    });

    testWidgets('stops at the end of a short page', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ListView(
            controller: controller,
            children: const [SizedBox(height: 1000)],
          ),
        ),
      );
      final maxExtent = controller.position.maxScrollExtent;
      final once = ScrollOncePerVisit();

      once.scrollTo(controller, maxExtent + 500, reduceMotion: true);
      await tester.pumpAndSettle();

      expect(controller.offset, maxExtent);
    });
  });

  group('motionDuration', () {
    Future<Duration> read(
      WidgetTester tester, {
      required bool disableAnimations,
    }) async {
      late Duration result;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: Builder(
            builder: (context) {
              result = motionDuration(
                context,
                const Duration(milliseconds: 800),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('keeps the duration by default', (tester) async {
      expect(
        await read(tester, disableAnimations: false),
        const Duration(milliseconds: 800),
      );
    });

    testWidgets('is zero when the platform asks to reduce motion', (
      tester,
    ) async {
      expect(await read(tester, disableAnimations: true), Duration.zero);
    });
  });
}
