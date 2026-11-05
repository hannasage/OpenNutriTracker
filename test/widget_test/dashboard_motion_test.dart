import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/utils/energy_unit_provider.dart';
import 'package:opennutritracker/features/home/presentation/widgets/dashboard_widget.dart';
import 'package:opennutritracker/generated/l10n.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';

Future<void> _pumpDashboard(
  WidgetTester tester, {
  required bool disableAnimations,
  double kcalLeft = 1200,
}) {
  return tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => EnergyUnitProvider(usesKilojoules: false),
      child: MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: DashboardWidget(
              totalKcalDaily: 2000,
              totalKcalLeft: kcalLeft,
              totalKcalSupplied: 800,
              totalKcalBurned: 0,
              totalCarbsIntake: 50,
              totalFatsIntake: 20,
              totalProteinsIntake: 30,
              totalCarbsGoal: 250,
              totalFatsGoal: 70,
              totalProteinsGoal: 100,
            ),
          ),
        ),
      ),
    ),
  );
}

CircularPercentIndicator _ring(WidgetTester tester) =>
    tester.widget(find.byType(CircularPercentIndicator));

AnimatedFlipCounter _counter(WidgetTester tester) =>
    tester.widget(find.byType(AnimatedFlipCounter));

void main() {
  group('home ring and kcal counter motion', () {
    testWidgets('keep the 800 ms animation by default', (tester) async {
      await _pumpDashboard(tester, disableAnimations: false);

      expect(_ring(tester).animationDuration, 800);
      expect(_counter(tester).duration, const Duration(milliseconds: 800));
    });

    testWidgets('do not animate when the platform reduces motion', (
      tester,
    ) async {
      await _pumpDashboard(tester, disableAnimations: true);

      expect(_ring(tester).animationDuration, 0);
      expect(_counter(tester).duration, Duration.zero);
      expect(_counter(tester).negativeSignDuration, Duration.zero);
    });

    testWidgets('start no animation on a new value when motion is reduced', (
      tester,
    ) async {
      await _pumpDashboard(tester, disableAnimations: true);

      await _pumpDashboard(tester, disableAnimations: true, kcalLeft: 400);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('run an animation on a new value by default', (tester) async {
      await _pumpDashboard(tester, disableAnimations: false);

      await _pumpDashboard(tester, disableAnimations: false, kcalLeft: 400);
      await tester.pump();

      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });
  });
}
