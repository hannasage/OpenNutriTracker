import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader/src/parser/text_normalizer.dart';
import 'package:nutrition_label_reader/src/vocabulary/label_matcher.dart';

void main() {
  const vocab = englishLabelVocabulary;
  const matcher = LabelMatcher(vocab);

  group('englishLabelVocabulary data', () {
    test('has the English tag', () {
      expect(vocab.languageTag, 'en');
    });

    test('gives every nutrient at least one name', () {
      for (final id in NutrientId.values) {
        expect(vocab.nutrientNames[id], isNotEmpty, reason: '$id');
      }
    });

    test('keeps every phrase folded, so matching is exact', () {
      final lists = <String, List<String>>{
        for (final entry in vocab.nutrientNames.entries)
          'names ${entry.key}': entry.value,
        'per100': vocab.per100Phrases,
        'perServing': vocab.perServingPhrases,
        'servingSize': vocab.servingSizePhrases,
        'percent': vocab.percentColumnPhrases,
        'prepared': vocab.preparedPhrases,
        'ignored': vocab.ignoredNutrientNames,
      };
      lists.forEach((name, phrases) {
        for (final phrase in phrases) {
          expect(phrase, foldForMatching(phrase), reason: '$name: $phrase');
          expect(phrase, isNotEmpty, reason: name);
        }
      });
    });

    test('maps no phrase to two ids', () {
      final seen = <String, NutrientId>{};
      for (final entry in vocab.nutrientNames.entries) {
        for (final phrase in entry.value) {
          expect(
            seen.containsKey(phrase),
            isFalse,
            reason: '"$phrase" is listed for ${seen[phrase]} and ${entry.key}',
          );
          seen[phrase] = entry.key;
        }
      }
    });

    test('keeps ignored names out of the nutrient names', () {
      final names = {for (final list in vocab.nutrientNames.values) ...list};
      for (final phrase in vocab.ignoredNutrientNames) {
        expect(names.contains(phrase), isFalse, reason: phrase);
      }
    });

    test('lists the blueprint starting phrases', () {
      expect(vocab.perServingPhrases, contains('amount per serving'));
      expect(vocab.servingSizePhrases, contains('servings per container'));
      expect(vocab.percentColumnPhrases, contains('% daily value'));
      expect(vocab.preparedPhrases, contains('as prepared'));
      expect(vocab.subItemPrefixes, contains('of which'));
      expect(vocab.ignoredNutrientNames, contains('added sugars'));
    });
  });

  group('LabelMatcher', () {
    NutrientId? idOf(String text) => matcher.match(text)?.id;

    test('matches whole phrases, ignoring case and spacing', () {
      expect(idOf('Protein'), NutrientId.protein);
      expect(idOf('  TOTAL   FAT '), NutrientId.fat);
      expect(idOf('Total Carbohydrate'), NutrientId.carbohydrate);
      expect(idOf('Dietary Fiber'), NutrientId.fiber);
      expect(idOf('Dietary fibre'), NutrientId.fiber);
      expect(idOf('Saturates'), NutrientId.saturatedFat);
      expect(idOf('Saturated fatty acids'), NutrientId.saturatedFat);
      expect(idOf('Trans'), NutrientId.transFat);
      expect(idOf('Sodium'), NutrientId.sodium);
      expect(idOf('Salt'), NutrientId.salt);
      expect(idOf('Vitamin D'), NutrientId.vitaminD);
      expect(idOf('Vitamin B12'), NutrientId.vitaminB12);
    });

    test('matches energy words to the energy family', () {
      for (final text in ['Energy', 'Energy value', 'Calories', 'kJ', 'kcal']) {
        final m = matcher.match(text);
        expect(m, isNotNull, reason: text);
        expect(m!.isEnergy, isTrue, reason: text);
      }
      expect(matcher.match('Protein')!.isEnergy, isFalse);
    });

    test('matches the phrase up to the first quantity', () {
      expect(idOf('Protein 5 g'), NutrientId.protein);
      expect(idOf('Protein 5g'), NutrientId.protein);
      expect(idOf('Protein <0.5 g'), NutrientId.protein);
      expect(idOf('Total Fat 3,5 g 10 g'), NutrientId.fat);
      expect(idOf('Vitamin B12 2,4 µg'), NutrientId.vitaminB12);
      expect(idOf('Vitamin D 5 µg'), NutrientId.vitaminD);
      expect(idOf('Energy 1046kJ'), NutrientId.energyKj);
    });

    test('drops bullets, dashes and a trailing colon', () {
      expect(idOf('- Sugars'), NutrientId.sugars);
      expect(idOf('• Sugars'), NutrientId.sugars);
      expect(idOf('* Sugars 4 g'), NutrientId.sugars);
      expect(idOf('Protein:'), NutrientId.protein);
    });

    test('knows sub-items', () {
      final of = matcher.match('of which sugars');
      expect(of!.id, NutrientId.sugars);
      expect(of.isSubItem, isTrue);
      final dash = matcher.match('- sugars 4 g');
      expect(dash!.isSubItem, isTrue);
      expect(matcher.match('Sugars')!.isSubItem, isFalse);
      expect(
        matcher.match('of which saturates 1 g')!.id,
        NutrientId.saturatedFat,
      );
    });

    test('flags ignored names and gives no id', () {
      for (final text in [
        'Added sugars',
        'of which added sugars 2 g',
        'Monounsaturates',
        'Polyunsaturates',
        'Polyols',
        'Starch',
        'Includes 3 g added sugars',
        'Unsaturated fat',
      ]) {
        final m = matcher.match(text);
        expect(m, isNotNull, reason: text);
        expect(m!.isIgnored, isTrue, reason: text);
        expect(m.id, isNull, reason: text);
      }
    });

    test('returns null for unknown, empty or fuzzy text', () {
      for (final text in [
        '',
        '   ',
        'Protien',
        'Proteins and more',
        'Test cereal',
        '5 g',
        '-',
        '12',
      ]) {
        expect(matcher.match(text), isNull, reason: text);
      }
    });

    test('does not change digits into letters or the reverse', () {
      expect(matcher.match('Vitamin 812'), isNull);
      expect(matcher.match('Pr0tein'), isNull);
    });

    test('finds any phrase from a list inside text', () {
      expect(matcher.containsPhrase('Per 100 g', vocab.per100Phrases), isTrue);
      expect(
        matcher.containsPhrase('Nutrition per 100ml', vocab.per100Phrases),
        isTrue,
      );
      expect(matcher.containsPhrase('Protein', vocab.per100Phrases), isFalse);
      expect(matcher.containsPhrase('', vocab.per100Phrases), isFalse);
    });
  });

  test('the abstract interface can be implemented outside the package', () {
    final LabelVocabulary other = _TinyVocabulary();
    expect(
      const LabelMatcher(_TinyVocabulary()).match('Eiweiss')?.id,
      NutrientId.protein,
    );
    expect(other.languageTag, 'xx');
  });
}

class _TinyVocabulary implements LabelVocabulary {
  const _TinyVocabulary();
  @override
  String get languageTag => 'xx';
  @override
  Map<NutrientId, List<String>> get nutrientNames => const {
    NutrientId.protein: ['eiweiss'],
  };
  @override
  List<String> get per100Phrases => const [];
  @override
  List<String> get perServingPhrases => const [];
  @override
  List<String> get servingSizePhrases => const [];
  @override
  List<String> get percentColumnPhrases => const [];
  @override
  List<String> get preparedPhrases => const [];
  @override
  List<String> get subItemPrefixes => const ['davon'];
  @override
  List<String> get ignoredNutrientNames => const [];
}
