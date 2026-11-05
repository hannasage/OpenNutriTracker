// UNVERIFIED. This is a starting set written from general knowledge of label
// wording. It is not from the repo, from a source, or from a real label. It
// must be checked against real labels before any accuracy claim. A native
// English reviewer has not read it.

import '../model/parsed_label.dart';
import 'label_vocabulary.dart';

/// The English vocabulary.
const englishLabelVocabulary = EnglishLabelVocabulary();

class EnglishLabelVocabulary implements LabelVocabulary {
  const EnglishLabelVocabulary();

  @override
  String get languageTag => 'en';

  @override
  Map<NutrientId, List<String>> get nutrientNames => const {
    NutrientId.energyKj: ['energy', 'energy value', 'kj'],
    NutrientId.energyKcal: ['calories', 'kcal'],
    NutrientId.fat: ['fat', 'total fat'],
    NutrientId.saturatedFat: [
      'saturates',
      'saturated fat',
      'saturated fatty acids',
    ],
    NutrientId.transFat: ['trans fat', 'trans'],
    NutrientId.carbohydrate: [
      'carbohydrate',
      'carbohydrates',
      'total carbohydrate',
    ],
    NutrientId.sugars: ['sugars', 'sugar', 'total sugars'],
    NutrientId.fiber: ['fibre', 'fiber', 'dietary fibre', 'dietary fiber'],
    NutrientId.protein: ['protein'],
    NutrientId.salt: ['salt'],
    NutrientId.sodium: ['sodium'],
    NutrientId.cholesterol: ['cholesterol'],
    NutrientId.potassium: ['potassium'],
    NutrientId.calcium: ['calcium'],
    NutrientId.iron: ['iron'],
    NutrientId.magnesium: ['magnesium'],
    NutrientId.vitaminD: ['vitamin d'],
    NutrientId.vitaminB12: ['vitamin b12'],
  };

  @override
  List<String> get per100Phrases => const [
    'per 100 g',
    'per 100g',
    '100 g',
    '100g',
    'per 100 ml',
    'per 100ml',
    '100 ml',
    '100ml',
  ];

  @override
  List<String> get perServingPhrases => const [
    'per serving',
    'per portion',
    'serving',
    'amount per serving',
  ];

  @override
  List<String> get servingSizePhrases => const [
    'serving size',
    'portion size',
    'servings per container',
  ];

  @override
  List<String> get percentColumnPhrases => const [
    '% daily value',
    '% dv',
    '%ri',
    '% ri',
    'reference intake',
    '% reference intake',
  ];

  @override
  List<String> get preparedPhrases => const ['as prepared', 'prepared'];

  @override
  List<String> get subItemPrefixes => const ['of which', '-'];

  @override
  List<String> get ignoredNutrientNames => const [
    'added sugars',
    'monounsaturates',
    'polyunsaturates',
    'polyols',
    'starch',
    'includes',
    'unsaturated fat',
  ];
}
