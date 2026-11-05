import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader_example/main.dart';
import 'package:nutrition_label_reader_example/sample_document.dart';

void main() {
  test('the bundled synthetic label parses', () {
    expect(sampleDocument.validate, returnsNormally);
    final result = NutritionLabelReader().parseDocument(sampleDocument);
    expect(result, isA<LabelParsed>());
    final label = (result as LabelParsed).label;
    expect(label.nutrient(NutrientId.protein)!.per100!.value, 10);
    expect(label.nutrient(NutrientId.fat)!.per100!.value, 3.5);
    expect(label.primaryBasis, LabelBasis.per100g);
  });

  testWidgets('the screen lists the nutrients it read', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Protein'), findsOneWidget);
    expect(find.textContaining('10 g'), findsWidgets);
    expect(find.textContaining('Looks right'), findsWidgets);
    expect(find.text('Test cereal'), findsNothing);
  });

  testWidgets('a derived value says so', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    // Sodium is derived from salt, so it is marked. It is at the end of the
    // list, so scroll to it.
    await tester.scrollUntilVisible(find.textContaining('(derived)'), 200);
    expect(find.textContaining('(derived)'), findsOneWidget);
    expect(find.text('Check this'), findsOneWidget);
  });

  testWidgets('a label that was not read shows the reason', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResultView(
          result: LabelNotRead(
            reason: LabelFailureReason.noText,
            nameMatches: 0,
            valueMatches: 0,
          ),
        ),
      ),
    );
    expect(find.textContaining('noText'), findsOneWidget);
  });
}
