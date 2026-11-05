import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opennutritracker/core/styles/app_palette.dart';
import 'package:opennutritracker/core/styles/app_theme.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';
import 'package:opennutritracker/features/add_meal/presentation/log_tray.dart';
import 'package:opennutritracker/features/add_meal/presentation/widgets/log_tray_widgets.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/daily_kcal_overview.dart';
import 'package:opennutritracker/features/meal_detail/presentation/widgets/meal_info_button.dart';
import 'package:opennutritracker/generated/l10n.dart';

import '../helpers/test_l10n.dart';

// The worst preset in each mode: yellow is 1.40:1 as text on the light
// surface, indigo is 2.03:1 on the dark one.
const _worstLight = Color(0xFFFDD835);
const _worstDark = Color(0xFF3949AB);

Future<void> _pump(WidgetTester tester, AppPalette palette, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(palette),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

Color? _colorOf(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).style?.color;

void main() {
  for (final base in [AppPalette.light, AppPalette.dark]) {
    final mode = base.brightness.name;
    final worst = base.brightness == Brightness.light
        ? _worstLight
        : _worstDark;
    final themed = base.withAccent(worst);

    group('text sites use accentText ($mode)', () {
      testWidgets('the day-total line', (tester) async {
        await _pump(
          tester,
          themed,
          const DailyKcalOverview(
            dayKcalConsumed: 1200,
            dayKcalGoal: 2000,
            currentSelectionKcal: 0,
          ),
        );
        final line = find.text(l10nEn.mealDetailDayTotalLabel('1200', '2000'));
        expect(_colorOf(tester, line), themed.accentText);
        expect(_colorOf(tester, line), isNot(worst));
      });

      testWidgets('the source link under a meal', (tester) async {
        await _pump(
          tester,
          themed,
          const MealInfoButton(url: null, source: MealSourceEntity.off),
        );
        final label = find.text(l10nEn.additionalInfoLabelOFF);
        expect(_colorOf(tester, label), themed.accentText);
        final icon = tester.widget<Icon>(
          find.byIcon(Icons.open_in_new_rounded),
        );
        expect(icon.color, themed.accentText);
      });

      testWidgets('the "To log" tray title', (tester) async {
        await _pump(tester, themed, LogTrayList(tray: LogTray()));
        final title = tester.widget<AutoSizeText>(find.byType(AutoSizeText));
        expect(title.style?.color, themed.accentText);
      });
    });
  }

  group('the default theme looks the same as before', () {
    testWidgets('light: day-total line stays the default green', (t) async {
      await _pump(
        t,
        AppPalette.light,
        const DailyKcalOverview(
          dayKcalConsumed: 1200,
          dayKcalGoal: 2000,
          currentSelectionKcal: 0,
        ),
      );
      final line = find.text(l10nEn.mealDetailDayTotalLabel('1200', '2000'));
      expect(_colorOf(t, line), const Color(0xFF0E7A4D));
    });

    testWidgets('dark: day-total line stays the default green', (t) async {
      await _pump(
        t,
        AppPalette.dark,
        const DailyKcalOverview(
          dayKcalConsumed: 1200,
          dayKcalGoal: 2000,
          currentSelectionKcal: 0,
        ),
      );
      final line = find.text(l10nEn.mealDetailDayTotalLabel('1200', '2000'));
      expect(_colorOf(t, line), const Color(0xFF34D08A));
    });
  });
}
