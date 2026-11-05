import 'package:flutter/material.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';

import 'sample_document.dart';

void main() => runApp(const ExampleApp());

/// Parses the bundled synthetic label and lists what was read. No camera, no
/// native code.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final result = NutritionLabelReader().parseDocument(sampleDocument);
    return MaterialApp(
      title: 'Label reader example',
      home: Scaffold(
        appBar: AppBar(title: const Text('Label reader example')),
        body: ResultView(result: result),
      ),
    );
  }
}

/// Shows a parse result as a list.
class ResultView extends StatelessWidget {
  const ResultView({super.key, required this.result});

  final LabelParseResult result;

  @override
  Widget build(BuildContext context) {
    switch (result) {
      case LabelNotRead(:final reason, :final nameMatches, :final valueMatches):
        return Center(
          child: Text(
            'Not read: ${reason.name} '
            '($nameMatches names, $valueMatches values)',
          ),
        );
      case LabelParsed(:final label):
        return ListView(
          children: [
            ListTile(
              title: Text('Basis: ${label.primaryBasis.name}'),
              subtitle: Text(
                label.warnings.isEmpty
                    ? 'No warnings'
                    : label.warnings.map((w) => w.name).join(', '),
              ),
            ),
            for (final nutrient in label.nutrients)
              ListTile(
                title: Text(_name(nutrient.id)),
                subtitle: Text(_describe(nutrient)),
                trailing: Text(
                  nutrient.review == FieldReview.looksRight
                      ? 'Looks right'
                      : 'Check this',
                ),
              ),
          ],
        );
    }
  }
}

String _name(NutrientId id) {
  switch (id) {
    case NutrientId.energyKj:
      return 'Energy (kJ)';
    case NutrientId.energyKcal:
      return 'Energy (kcal)';
    case NutrientId.saturatedFat:
      return 'Saturated fat';
    case NutrientId.transFat:
      return 'Trans fat';
    case NutrientId.vitaminD:
      return 'Vitamin D';
    case NutrientId.vitaminB12:
      return 'Vitamin B12';
    case NutrientId.fat:
      return 'Fat';
    case NutrientId.carbohydrate:
      return 'Carbohydrate';
    case NutrientId.sugars:
      return 'Sugars';
    case NutrientId.fiber:
      return 'Fibre';
    case NutrientId.protein:
      return 'Protein';
    case NutrientId.salt:
      return 'Salt';
    case NutrientId.sodium:
      return 'Sodium';
    case NutrientId.cholesterol:
      return 'Cholesterol';
    case NutrientId.potassium:
      return 'Potassium';
    case NutrientId.calcium:
      return 'Calcium';
    case NutrientId.iron:
      return 'Iron';
    case NutrientId.magnesium:
      return 'Magnesium';
  }
}

String _describe(ParsedNutrient nutrient) {
  final parts = <String>[];
  void add(String basis, ParsedQuantity? q) {
    if (q == null) return;
    final value = q.value;
    final text = value == null
        ? 'no value'
        : '${q.isUpperBound ? '<' : ''}${_trim(value)} ${q.unit?.name ?? ''}';
    parts.add('$basis: ${text.trim()}${q.isDerived ? ' (derived)' : ''}');
  }

  add('per 100', nutrient.per100);
  add('per serving', nutrient.perServing);
  add('unknown basis', nutrient.unknownBasis);
  return parts.join('; ');
}

String _trim(double value) {
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
