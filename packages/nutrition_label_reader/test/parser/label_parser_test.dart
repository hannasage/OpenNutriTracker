import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';

import '../fixtures/eu_one_column.dart';
import '../fixtures/eu_two_column.dart';
import '../fixtures/fixture_builder.dart';
import '../fixtures/kj_only.dart';
import '../fixtures/missing_salt.dart';
import '../fixtures/per_serving_scaled.dart';
import '../fixtures/us_style.dart';

const _parser = LabelParser();

ParsedLabel _parsed(RecognizedDocument document, {LabelParser? parser}) {
  final result = (parser ?? _parser).parse(document);
  expect(result, isA<LabelParsed>(), reason: '$result');
  return (result as LabelParsed).label;
}

LabelNotRead _notRead(RecognizedDocument document, {LabelParser? parser}) {
  final result = (parser ?? _parser).parse(document);
  expect(result, isA<LabelNotRead>(), reason: '$result');
  return result as LabelNotRead;
}

/// id to (per 100 value, per serving value).
Map<NutrientId, (double?, double?)> _values(ParsedLabel label) => {
  for (final n in label.nutrients) n.id: (n.per100?.value, n.perServing?.value),
};

Map<String, RecognizedDocument> _shapes(FixtureGrid grid) => {
  'table': grid.asTable(),
  'separate boxes': grid.asSeparateBoxes(),
  'merged lines': grid.asMergedLines(),
};

/// Everything a parse reports except the order-from-position flag, which only
/// the merged-line shape may add.
Set<FieldFlag> _flagsWithoutOrder(ParsedNutrient n) =>
    n.flags.difference({FieldFlag.columnFromOrderNotPosition});

void _checkShapes(FixtureGrid grid, Map<NutrientId, (double?, double?)> want) {
  Map<String, ParsedLabel> parseAll() => {
    for (final entry in _shapes(grid).entries) entry.key: _parsed(entry.value),
  };
  for (final name in _shapes(grid).keys) {
    test('$name gives the expected values', () {
      expect(_values(parseAll()[name]!), want);
    });
  }
  test('the three shapes agree on values, flags and warnings', () {
    final labels = parseAll();
    final table = labels['table']!;
    for (final label in labels.values) {
      expect(_values(label), _values(table));
      expect(label.primaryBasis, table.primaryBasis);
      expect(label.serving, table.serving);
      expect(label.warnings, table.warnings);
      expect(label.ignoredRows, table.ignoredRows);
      for (final n in label.nutrients) {
        expect(
          _flagsWithoutOrder(n),
          _flagsWithoutOrder(table.nutrient(n.id)!),
        );
        expect(n.per100?.unit, table.nutrient(n.id)!.per100?.unit);
        expect(n.perServing?.unit, table.nutrient(n.id)!.perServing?.unit);
      }
    }
  });
  test('only the merged-line shape reads columns from order', () {
    final labels = parseAll();
    for (final entry in labels.entries) {
      final flagged = entry.value.nutrients.any(
        (n) => n.flags.contains(FieldFlag.columnFromOrderNotPosition),
      );
      expect(flagged, entry.key == 'merged lines', reason: entry.key);
    }
  });
  test('every value read is text that is in the input', () {
    for (final entry in _shapes(grid).entries) {
      final label = _parsed(entry.value);
      for (final n in label.nutrients) {
        for (final q in [n.per100, n.perServing]) {
          if (q == null || q.isDerived) continue;
          expect(
            grid.allText.contains(q.rawText),
            isTrue,
            reason: '${entry.key}: "${q.rawText}"',
          );
        }
      }
    }
  });
  test('the confidence of the observation changes nothing', () {
    expect(
      _parser.parse(grid.asTable(observationConfidence: 0.05)),
      _parser.parse(grid.asTable(observationConfidence: 0.99)),
    );
    expect(
      _parser.parse(grid.asSeparateBoxes(observationConfidence: 0.05)),
      _parser.parse(grid.asSeparateBoxes()),
    );
  });
  test('the order of boxes and cells changes nothing', () {
    final table = grid.asTable();
    final shuffledTable = RecognizedDocument(
      source: table.source,
      imageWidth: table.imageWidth,
      imageHeight: table.imageHeight,
      boxes: [...table.boxes]..shuffle(Random(1)),
      tables: [
        for (final t in table.tables)
          RecognizedTable(box: t.box, cells: [...t.cells]..shuffle(Random(2))),
      ],
    );
    expect(_parser.parse(shuffledTable), _parser.parse(table));
    final boxes = grid.asSeparateBoxes();
    final shuffled = RecognizedDocument(
      source: boxes.source,
      imageWidth: boxes.imageWidth,
      imageHeight: boxes.imageHeight,
      boxes: [...boxes.boxes]..shuffle(Random(3)),
    );
    expect(_parser.parse(shuffled), _parser.parse(boxes));
  });
}

class _Copy extends EnglishLabelVocabulary {
  const _Copy(this.tag);
  final String tag;
  @override
  String get languageTag => tag;
}

class _Tiny implements LabelVocabulary {
  const _Tiny();
  @override
  String get languageTag => 'xx';
  @override
  Map<NutrientId, List<String>> get nutrientNames => const {
    NutrientId.energyKj: ['energie'],
    NutrientId.energyKcal: ['energie'],
    NutrientId.fat: ['fett'],
    NutrientId.carbohydrate: ['kohlenhydrate'],
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
  List<String> get subItemPrefixes => const [];
  @override
  List<String> get ignoredNutrientNames => const [];
}

void main() {
  group('fixture 1: EU two columns, kJ and kcal, salt', () {
    _checkShapes(euTwoColumn, {
      NutrientId.energyKj: (1300, 392),
      NutrientId.energyKcal: (311, 94),
      NutrientId.fat: (3.5, 1.1),
      NutrientId.saturatedFat: (1.2, 0.4),
      NutrientId.carbohydrate: (60, 18),
      NutrientId.sugars: (12, 3.6),
      NutrientId.fiber: (8, 2.4),
      NutrientId.protein: (10, 3),
      NutrientId.salt: (0.5, 0.15),
      NutrientId.sodium: (0.5 * 1000 / 2.5, 0.15 * 1000 / 2.5),
    });

    test('reads basis, serving, units and review', () {
      for (final entry in _shapes(euTwoColumn).entries) {
        final label = _parsed(entry.value);
        expect(label.primaryBasis, LabelBasis.per100g, reason: entry.key);
        expect(label.languageTag, 'en');
        expect(label.serving?.amount, 30, reason: entry.key);
        expect(label.serving?.rawText, '30 g', reason: entry.key);
        expect(label.warnings, isEmpty, reason: entry.key);
        expect(label.ignoredRows, isEmpty, reason: entry.key);
        expect(label.nutrient(NutrientId.energyKj)!.per100!.unit, LabelUnit.kj);
        expect(
          label.nutrient(NutrientId.energyKcal)!.perServing!.unit,
          LabelUnit.kcal,
        );
        expect(label.nutrient(NutrientId.fat)!.per100!.unit, LabelUnit.g);
        expect(label.nutrient(NutrientId.fat)!.per100!.rawText, '3.5 g');
        expect(label.nutrient(NutrientId.fat)!.sourceBox, isNotNull);
      }
    });

    test('table and boxes give a clean review, merged lines check', () {
      Set<FieldReview> readReviews(RecognizedDocument doc) => {
        for (final n in _parsed(doc).nutrients)
          if (n.per100?.isDerived != true) n.review,
      };
      expect(readReviews(euTwoColumn.asTable()), {FieldReview.looksRight});
      expect(readReviews(euTwoColumn.asSeparateBoxes()), {
        FieldReview.looksRight,
      });
      expect(
        _parsed(
          euTwoColumn.asMergedLines(),
        ).nutrients.map((n) => n.review).toSet(),
        {FieldReview.checkThis},
      );
    });
  });

  group('fixture 2: EU one column per 100 g', () {
    _checkShapes(euOneColumn, {
      NutrientId.energyKj: (1300, null),
      NutrientId.energyKcal: (311, null),
      NutrientId.fat: (3.5, null),
      NutrientId.saturatedFat: (1.2, null),
      NutrientId.carbohydrate: (60, null),
      NutrientId.sugars: (12, null),
      NutrientId.fiber: (8, null),
      NutrientId.protein: (10, null),
      NutrientId.salt: (0.5, null),
      NutrientId.sodium: (0.5 * 1000 / 2.5, null),
    });

    test('has no serving and the per 100 g basis', () {
      for (final entry in _shapes(euOneColumn).entries) {
        final label = _parsed(entry.value);
        expect(label.primaryBasis, LabelBasis.per100g, reason: entry.key);
        expect(label.serving, isNull, reason: entry.key);
        expect(label.warnings, isEmpty, reason: entry.key);
      }
    });
  });

  group('fixture 3: US style, per serving, percent column', () {
    _checkShapes(usStyle, {
      NutrientId.energyKcal: (null, 230),
      NutrientId.fat: (8 * 100 / 55, 8),
      NutrientId.saturatedFat: (1 * 100 / 55, 1),
      NutrientId.transFat: (0, 0),
      NutrientId.cholesterol: (0, 0),
      NutrientId.sodium: (160 * 100 / 55, 160),
      NutrientId.carbohydrate: (37 * 100 / 55, 37),
      NutrientId.fiber: (4 * 100 / 55, 4),
      NutrientId.sugars: (12 * 100 / 55, 12),
      NutrientId.protein: (3 * 100 / 55, 3),
      NutrientId.salt: (160 * 2.5 / 1000 * 100 / 55, 160 * 2.5 / 1000),
    });

    test('keeps the serving basis, units and the ignored percent column', () {
      for (final entry in _shapes(usStyle).entries) {
        final label = _parsed(entry.value);
        expect(label.primaryBasis, LabelBasis.perServing, reason: entry.key);
        expect(label.warnings, {LabelWarning.percentColumnIgnored});
        expect(label.serving?.amount, 55, reason: entry.key);
        expect(label.serving?.rawText, '2/3 cup (55 g)', reason: entry.key);
        expect(
          label.nutrient(NutrientId.sodium)!.perServing!.unit,
          LabelUnit.mg,
        );
        final fat = label.nutrient(NutrientId.fat)!;
        expect(fat.per100!.isDerived, isTrue);
        expect(fat.flags, contains(FieldFlag.scaledFromServing));
      }
    });

    test('does not assume the unit of Calories', () {
      for (final entry in _shapes(usStyle).entries) {
        final calories = _parsed(entry.value).nutrient(NutrientId.energyKcal)!;
        expect(calories.perServing!.value, 230, reason: entry.key);
        expect(calories.perServing!.unit, isNull, reason: entry.key);
        expect(calories.per100, isNull, reason: entry.key);
        expect(calories.flags, contains(FieldFlag.unitMissing));
        expect(calories.review, FieldReview.checkThis);
      }
    });
  });

  group('fixture 8: per serving only, 30 g', () {
    _checkShapes(perServingScaled, {
      NutrientId.energyKj: (392 * 100 / 30, 392),
      NutrientId.energyKcal: (94 * 100 / 30, 94),
      NutrientId.fat: (1.1 * 100 / 30, 1.1),
      NutrientId.carbohydrate: (18 * 100 / 30, 18),
      NutrientId.protein: (3 * 100 / 30, 3),
    });

    test('scales to per 100 with a flag and keeps the serving value', () {
      for (final entry in _shapes(perServingScaled).entries) {
        final label = _parsed(entry.value);
        expect(label.primaryBasis, LabelBasis.perServing, reason: entry.key);
        expect(label.serving!.amount, 30, reason: entry.key);
        expect(label.warnings, isEmpty, reason: entry.key);
        for (final n in label.nutrients) {
          expect(n.per100!.isDerived, isTrue, reason: '${n.id}');
          expect(n.perServing!.isDerived, isFalse);
          expect(n.flags, contains(FieldFlag.scaledFromServing));
          expect(n.review, FieldReview.checkThis);
        }
      }
    });
  });

  group('fixture 9: per serving only, 1 cup', () {
    _checkShapes(perServingCup, {
      NutrientId.energyKj: (null, 392),
      NutrientId.energyKcal: (null, 94),
      NutrientId.fat: (null, 1.1),
      NutrientId.carbohydrate: (null, 18),
      NutrientId.protein: (null, 3),
    });

    test('has no per 100 value and warns about the serving size', () {
      for (final entry in _shapes(perServingCup).entries) {
        final label = _parsed(entry.value);
        expect(label.warnings, {LabelWarning.servingSizeMissing});
        expect(label.serving!.rawText, '1 cup', reason: entry.key);
        expect(label.serving!.amount, isNull);
        expect(label.warnings.contains(LabelWarning.basisUnknown), isFalse);
        for (final n in label.nutrients) {
          expect(n.per100, isNull, reason: '${n.id}');
          expect(n.flags.contains(FieldFlag.scaledFromServing), isFalse);
        }
      }
    });

    test('a label with no serving row warns the same way', () {
      const grid = FixtureGrid([
        ['', 'Per serving'],
        ['Energy', '392 kJ / 94 kcal'],
        ['Fat', '1.1 g'],
        ['Carbohydrate', '18 g'],
        ['Protein', '3 g'],
      ]);
      final label = _parsed(grid.asSeparateBoxes());
      expect(label.serving, isNull);
      expect(label.warnings, {LabelWarning.servingSizeMissing});
    });
  });

  group('scaling leaves a two column label alone', () {
    test('fixture 1 has no scaled value and no warning', () {
      final label = _parsed(euTwoColumn.asTable());
      for (final n in label.nutrients) {
        expect(n.flags.contains(FieldFlag.scaledFromServing), isFalse);
      }
      expect(label.warnings, isEmpty);
    });
  });

  group('fixture 6: kJ only', () {
    _checkShapes(kjOnly, {
      NutrientId.energyKj: (1300, null),
      NutrientId.energyKcal: (1300 / 4.184, null),
      NutrientId.fat: (3.5, null),
      NutrientId.carbohydrate: (60, null),
      NutrientId.protein: (10, null),
      NutrientId.salt: (0.5, null),
      NutrientId.sodium: (0.5 * 1000 / 2.5, null),
    });

    test('derives kcal and says so', () {
      for (final entry in _shapes(kjOnly).entries) {
        final label = _parsed(entry.value);
        final kcal = label.nutrient(NutrientId.energyKcal)!;
        expect(kcal.per100!.isDerived, isTrue, reason: entry.key);
        expect(kcal.flags, contains(FieldFlag.derivedFromOtherUnit));
        expect(kcal.review, FieldReview.checkThis);
        expect(label.nutrient(NutrientId.energyKj)!.per100!.isDerived, isFalse);
      }
    });
  });

  group('fixture 7: no salt and no sodium', () {
    _checkShapes(missingSalt, {
      NutrientId.energyKj: (1300, null),
      NutrientId.energyKcal: (311, null),
      NutrientId.fat: (3.5, null),
      NutrientId.carbohydrate: (60, null),
      NutrientId.protein: (10, null),
    });

    test('has no salt entry and no sodium entry, and no zero', () {
      for (final entry in _shapes(missingSalt).entries) {
        final label = _parsed(entry.value);
        expect(label.nutrient(NutrientId.salt), isNull, reason: entry.key);
        expect(label.nutrient(NutrientId.sodium), isNull, reason: entry.key);
      }
    });
  });

  group('salt and sodium rows', () {
    test('salt read gives derived sodium in mg', () {
      for (final entry in _shapes(euOneColumn).entries) {
        final label = _parsed(entry.value);
        final sodium = label.nutrient(NutrientId.sodium)!;
        expect(sodium.per100!.unit, LabelUnit.mg, reason: entry.key);
        expect(sodium.per100!.isDerived, isTrue, reason: entry.key);
        expect(sodium.flags, contains(FieldFlag.derivedFromOtherUnit));
        expect(label.nutrient(NutrientId.salt)!.per100!.isDerived, isFalse);
      }
    });

    test('sodium read gives derived salt in g', () {
      for (final entry in _shapes(usStyle).entries) {
        final label = _parsed(entry.value);
        final salt = label.nutrient(NutrientId.salt)!;
        expect(salt.perServing!.unit, LabelUnit.g, reason: entry.key);
        expect(salt.perServing!.isDerived, isTrue, reason: entry.key);
        expect(salt.flags, contains(FieldFlag.derivedFromOtherUnit));
        expect(
          label.nutrient(NutrientId.sodium)!.perServing!.isDerived,
          isFalse,
        );
      }
    });

    test('both read keeps both values', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '3.5 g'],
        ['Salt', '0.5 g'],
        ['Sodium', '190 mg'],
        ['Protein', '10 g'],
      ]);
      final label = _parsed(grid.asSeparateBoxes());
      expect(label.nutrient(NutrientId.salt)!.per100!.value, 0.5);
      expect(label.nutrient(NutrientId.sodium)!.per100!.value, 190);
      expect(label.nutrient(NutrientId.salt)!.flags, isEmpty);
      expect(label.nutrient(NutrientId.sodium)!.flags, isEmpty);
    });
  });

  group('energy rows', () {
    FixtureGrid energy(List<List<String>> rows) => FixtureGrid([
      ['', 'Per 100 g'],
      ...rows,
      ['Fat', '3.5 g'],
      ['Carbohydrate', '60 g'],
      ['Protein', '10 g'],
    ]);

    test('kcal first and kJ second give the same values', () {
      for (final text in ['1046 kJ / 250 kcal', '250 kcal / 1046 kJ']) {
        final label = _parsed(
          energy([
            ['Energy', text],
          ]).asSeparateBoxes(),
        );
        expect(label.nutrient(NutrientId.energyKj)!.per100!.value, 1046);
        expect(label.nutrient(NutrientId.energyKcal)!.per100!.value, 250);
        expect(label.nutrient(NutrientId.energyKj)!.flags, isEmpty);
        expect(label.nutrient(NutrientId.energyKcal)!.flags, isEmpty);
      }
    });

    test('energy split across two rows is joined', () {
      final grid = energy([
        ['Energy', '1046 kJ'],
        ['', '250 kcal'],
      ]);
      for (final entry in _shapes(grid).entries) {
        final label = _parsed(entry.value);
        expect(
          label.nutrient(NutrientId.energyKj)!.per100!.value,
          1046,
          reason: entry.key,
        );
        expect(
          label.nutrient(NutrientId.energyKcal)!.per100!.value,
          250,
          reason: entry.key,
        );
        expect(
          label.nutrient(NutrientId.energyKcal)!.per100!.isDerived,
          isFalse,
        );
        expect(label.ignoredRows, isEmpty, reason: entry.key);
      }
    });

    test('a value-only row after a non-energy row is not energy', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '3.5 g'],
        ['', '250 kcal'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
      ]);
      final label = _parsed(grid.asSeparateBoxes());
      expect(label.ignoredRows, ['250 kcal']);
      expect(label.nutrient(NutrientId.energyKcal)!.flags, isEmpty);
    });

    test('kJ and kcal that disagree are flagged and kept', () {
      final label = _parsed(
        energy([
          ['Energy', '1046 kJ / 200 kcal'],
        ]).asSeparateBoxes(),
      );
      for (final id in [NutrientId.energyKj, NutrientId.energyKcal]) {
        final n = label.nutrient(id)!;
        expect(n.flags, contains(FieldFlag.energyUnitsDisagree), reason: '$id');
        expect(n.per100!.isDerived, isFalse);
      }
      expect(label.nutrient(NutrientId.energyKcal)!.per100!.value, 200);
    });

    test('a US Calories value with no unit is not converted', () {
      final label = _parsed(usStyle.asSeparateBoxes());
      expect(label.nutrient(NutrientId.energyKj), isNull);
    });
  });

  group('failures', () {
    test('no boxes is noText', () {
      const doc = RecognizedDocument(
        source: RecognitionSource.androidMlKit,
        imageWidth: 10,
        imageHeight: 10,
        boxes: [],
      );
      expect(
        _parser.parse(doc),
        const LabelNotRead(
          reason: LabelFailureReason.noText,
          nameMatches: 0,
          valueMatches: 0,
        ),
      );
    });

    test('a menu is noNutritionPanel', () {
      const menu = FixtureGrid([
        ['Test menu'],
        ['Soup of the day', '\$4.50'],
        ['House salad', '\$6'],
        ['Grilled cheese', '\$7.25'],
        ['Iced tea', '\$2'],
      ]);
      for (final doc in [menu.asTable(), menu.asSeparateBoxes()]) {
        final r = _notRead(doc);
        expect(r.reason, LabelFailureReason.noNutritionPanel);
        expect(r.nameMatches, 0);
        expect(r.valueMatches, 0);
      }
    });

    test('names with no numbers is noNutritionPanel', () {
      const names = FixtureGrid([
        ['Energy'],
        ['Fat'],
        ['Carbohydrate'],
        ['Protein'],
        ['Salt'],
      ]);
      final r = _notRead(names.asSeparateBoxes());
      expect(r.reason, LabelFailureReason.noNutritionPanel);
      expect(r.nameMatches, 5);
      expect(r.valueMatches, 0);
    });

    test('too few names is noNutritionPanel', () {
      const few = FixtureGrid([
        ['Energy', '1046 kJ'],
        ['Fat', '3 g'],
        ['Protein', '10 g'],
      ]);
      final r = _notRead(few.asSeparateBoxes());
      expect(r.reason, LabelFailureReason.noNutritionPanel);
      expect(r.nameMatches, 3);
    });

    test('names and numbers with no energy is noEnergyRow', () {
      const noEnergy = FixtureGrid([
        ['', 'Per 100 g'],
        ['Fat', '3.5 g'],
        ['Carbohydrate', '60 g'],
        ['Fibre', '8 g'],
        ['Protein', '10 g'],
        ['Salt', '0.5 g'],
      ]);
      for (final doc in [noEnergy.asTable(), noEnergy.asSeparateBoxes()]) {
        final r = _notRead(doc);
        expect(r.reason, LabelFailureReason.noEnergyRow);
        expect(r.nameMatches, 5);
        expect(r.valueMatches, 5);
      }
    });

    test('names found and every value rejected is noReadableValues', () {
      const bad = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1O46 kJ'],
        ['Fat', '3.5.2 g'],
        ['Carbohydrate', '6O g'],
        ['Protein', '1O g'],
        ['Salt', '0..5 g'],
      ]);
      final r = _notRead(bad.asSeparateBoxes());
      expect(r.reason, LabelFailureReason.noReadableValues);
      expect(r.nameMatches, 5);
      expect(r.valueMatches, 5);
    });

    test('Chinese text with the English vocabulary is unsupportedLanguage', () {
      const chinese = FixtureGrid([
        ['营养成分表'],
        ['蛋白质', '10 g'],
        ['脂肪', '3.5 g'],
        ['碳水化合物', '60 g'],
        ['能量', '1046 kJ'],
        ['钠', '120 mg'],
      ]);
      for (final doc in [chinese.asTable(), chinese.asSeparateBoxes()]) {
        final r = _notRead(doc);
        expect(r.reason, LabelFailureReason.unsupportedLanguage);
        expect(r.nameMatches, 0);
        expect(r.valueMatches, 5);
      }
    });

    test('no vocabulary at all is unsupportedLanguage', () {
      final r = _notRead(
        euTwoColumn.asTable(),
        parser: const LabelParser(vocabularies: []),
      );
      expect(r.reason, LabelFailureReason.unsupportedLanguage);
    });

    test('a two column label with no header is noReadableValues', () {
      const noHeader = FixtureGrid([
        ['Energy', '1046 kJ / 250 kcal', '314 kJ / 75 kcal'],
        ['Fat', '3.5 g', '1.1 g'],
        ['Carbohydrate', '60 g', '18 g'],
        ['Protein', '10 g', '3 g'],
      ]);
      final r = _notRead(noHeader.asSeparateBoxes());
      expect(r.reason, LabelFailureReason.noReadableValues);
    });
  });

  group('columns and basis', () {
    test('a table with too few matched rows falls back to the boxes', () {
      final good = euTwoColumn.asSeparateBoxes();
      final doc = RecognizedDocument(
        source: RecognitionSource.iosDocuments,
        imageWidth: good.imageWidth,
        imageHeight: good.imageHeight,
        boxes: good.boxes,
        tables: [
          const RecognizedTable(
            box: LabelRect(left: 0, top: 0, width: 1, height: 0.1),
            cells: [
              RecognizedCell(
                text: 'Test cereal',
                box: LabelRect(left: 0, top: 0, width: 0.2, height: 0.02),
                row: 0,
                column: 0,
              ),
            ],
          ),
        ],
      );
      final label = _parsed(doc);
      expect(label.warnings, {LabelWarning.tableFallbackToBoxes});
      expect(label.nutrient(NutrientId.protein)!.per100!.value, 10);
    });

    test('a good table gives no fallback warning', () {
      expect(_parsed(euTwoColumn.asTable()).warnings, isEmpty);
    });

    test('no header and one column keeps the values, basis unknown', () {
      const grid = FixtureGrid([
        ['Test cereal'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '3.5 g'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
      ]);
      for (final doc in [grid.asTable(), grid.asSeparateBoxes()]) {
        final label = _parsed(doc);
        expect(label.warnings, {LabelWarning.basisUnknown});
        expect(label.primaryBasis, LabelBasis.unknown);
        final fat = label.nutrient(NutrientId.fat)!;
        expect(fat.unknownBasis!.value, 3.5);
        expect(fat.per100, isNull);
        expect(fat.perServing, isNull);
        for (final n in label.nutrients) {
          expect(
            n.flags,
            contains(FieldFlag.columnAmbiguous),
            reason: '${n.id}',
          );
          expect(n.review, FieldReview.checkThis);
          expect(n.per100, isNull);
          expect(n.perServing, isNull);
          expect(n.unknownBasis, isNotNull);
        }
      }
    });

    test(
      'a header row with a percent column only leaves the basis unknown',
      () {
        const grid = FixtureGrid([
          ['', '', '% Daily Value*'],
          ['Calories', '230'],
          ['Total Fat', '8 g', '10%'],
          ['Total Carbohydrate', '37 g', '13%'],
          ['Protein', '3 g'],
        ]);
        final label = _parsed(grid.asSeparateBoxes());
        expect(label.primaryBasis, LabelBasis.unknown);
        expect(label.warnings, {
          LabelWarning.percentColumnIgnored,
          LabelWarning.basisUnknown,
        });
        expect(label.nutrient(NutrientId.fat)!.unknownBasis!.value, 8);
      },
    );

    test('an as prepared column is ignored with a warning', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g', 'As prepared'],
        ['Energy', '1046 kJ / 250 kcal', '500 kJ / 120 kcal'],
        ['Fat', '3.5 g', '1.5 g'],
        ['Carbohydrate', '60 g', '30 g'],
        ['Protein', '10 g', '5 g'],
      ]);
      final label = _parsed(grid.asSeparateBoxes());
      expect(label.warnings, {LabelWarning.preparedColumnIgnored});
      expect(label.nutrient(NutrientId.fat)!.per100!.value, 3.5);
      expect(label.nutrient(NutrientId.fat)!.perServing, isNull);
      expect(label.primaryBasis, LabelBasis.per100g);
    });

    test('a per 100 ml header sets the ml basis', () {
      const grid = FixtureGrid([
        ['', 'Per 100 ml'],
        ['Energy', '180 kJ / 43 kcal'],
        ['Fat', '0 g'],
        ['Carbohydrate', '10 g'],
        ['Protein', '0.5 g'],
      ]);
      final label = _parsed(grid.asSeparateBoxes());
      expect(label.primaryBasis, LabelBasis.per100ml);
      expect(label.nutrient(NutrientId.carbohydrate)!.per100!.value, 10);
    });

    test('a percent token is never read as a value', () {
      final label = _parsed(usStyle.asSeparateBoxes());
      for (final n in label.nutrients) {
        for (final q in [n.per100, n.perServing]) {
          expect(q?.rawText.contains('%') ?? false, isFalse);
        }
      }
    });
  });

  group('implausible values', () {
    FixtureGrid per100(List<List<String>> rows) => FixtureGrid([
      ['', 'Per 100 g'],
      ['Energy', '1300 kJ / 311 kcal'],
      ...rows,
    ]);

    test('a clean label has no plausibility flag', () {
      final label = _parsed(euTwoColumn.asTable());
      for (final n in label.nutrients) {
        expect(n.flags.contains(FieldFlag.valueOutOfRange), isFalse);
        expect(n.flags.contains(FieldFlag.macroSumExceeds100), isFalse);
        expect(n.flags.contains(FieldFlag.subItemExceedsParent), isFalse);
        expect(n.flags.contains(FieldFlag.energyDoesNotMatchMacros), isFalse);
      }
    });

    test('saturates above fat is flagged on saturates', () {
      final label = _parsed(
        per100([
          ['Fat', '3.5 g'],
          ['of which saturates', '4.5 g'],
          ['Carbohydrate', '60 g'],
          ['Protein', '10 g'],
        ]).asSeparateBoxes(),
      );
      expect(label.nutrient(NutrientId.saturatedFat)!.flags, {
        FieldFlag.subItemExceedsParent,
      });
      expect(label.nutrient(NutrientId.fat)!.flags, isEmpty);
    });

    test('a value above 100 g and a macro sum above 100 are flagged', () {
      final label = _parsed(
        per100([
          ['Fat', '3.5 g'],
          ['Carbohydrate', '60 g'],
          ['Protein', '150 g'],
        ]).asSeparateBoxes(),
      );
      expect(label.nutrient(NutrientId.protein)!.flags, {
        FieldFlag.valueOutOfRange,
        FieldFlag.macroSumExceeds100,
      });
      expect(label.nutrient(NutrientId.protein)!.per100!.value, 150);
      expect(label.nutrient(NutrientId.fat)!.flags, {
        FieldFlag.macroSumExceeds100,
      });
    });

    test('energy that does not match the macros is flagged', () {
      final label = _parsed(
        FixtureGrid([
          ['', 'Per 100 g'],
          ['Energy', '400 kJ / 96 kcal'],
          ['Fat', '3.5 g'],
          ['Carbohydrate', '60 g'],
          ['Protein', '10 g'],
        ]).asSeparateBoxes(),
      );
      for (final id in [NutrientId.energyKj, NutrientId.energyKcal]) {
        expect(label.nutrient(id)!.flags, {FieldFlag.energyDoesNotMatchMacros});
      }
    });
  });

  group('rows', () {
    test('a repeated nutrient keeps the first row and flags it', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '3.5 g'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
        ['Protein', '99 g'],
      ]);
      final protein = _parsed(
        grid.asSeparateBoxes(),
      ).nutrient(NutrientId.protein)!;
      expect(protein.per100!.value, 10);
      expect(protein.flags, {FieldFlag.duplicateRow});
    });

    test('a second full panel is ignored, the first wins', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1300 kJ / 311 kcal'],
        ['Fat', '3.5 g'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
        ['', 'Per 100 g'],
        ['Energy', '1200 kJ / 287 kcal'],
        ['Fat', '9 g'],
        ['Carbohydrate', '50 g'],
        ['Protein', '8 g'],
      ]);
      for (final entry in _shapes(grid).entries) {
        final label = _parsed(entry.value);
        expect(
          label.warnings,
          contains(LabelWarning.duplicatePanelIgnored),
          reason: entry.key,
        );
        expect(label.nutrient(NutrientId.fat)!.per100!.value, 3.5);
        expect(label.nutrient(NutrientId.energyKj)!.per100!.value, 1300);
        for (final n in label.nutrients) {
          expect(
            n.flags.contains(FieldFlag.duplicateRow),
            isFalse,
            reason: '${entry.key} ${n.id}',
          );
        }
      }
    });

    test('a second panel in another language is listed as ignored rows', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1300 kJ / 311 kcal'],
        ['Fat', '3.5 g'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
        ['Fett', '3.5 g'],
        ['Kohlenhydrate', '60 g'],
      ]);
      final label = _parsed(grid.asSeparateBoxes());
      expect(label.ignoredRows, ['Fett 3.5 g', 'Kohlenhydrate 60 g']);
      expect(label.warnings, isEmpty);
    });

    test('ignored names and unknown rows are listed, not mapped', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '3.5 g'],
        ['Carbohydrate', '60 g'],
        ['Added sugars', '2 g'],
        ['Mystery ingredient', '5 g'],
        ['Protein', '10 g'],
      ]);
      final label = _parsed(grid.asSeparateBoxes());
      expect(label.ignoredRows, ['Added sugars 2 g', 'Mystery ingredient 5 g']);
      expect(label.nutrients.map((n) => n.id), [
        NutrientId.energyKj,
        NutrientId.energyKcal,
        NutrientId.fat,
        NutrientId.carbohydrate,
        NutrientId.protein,
      ]);
    });

    test('a missing nutrient is absent, not zero', () {
      final label = _parsed(euOneColumn.asTable());
      expect(label.nutrient(NutrientId.transFat), isNull);
      expect(label.nutrient(NutrientId.cholesterol), isNull);
    });

    test('an upper bound keeps the value and flags it', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '<0.5 g'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
      ]);
      final fat = _parsed(grid.asSeparateBoxes()).nutrient(NutrientId.fat)!;
      expect(fat.per100!.value, 0.5);
      expect(fat.per100!.isUpperBound, isTrue);
      expect(fat.flags, {FieldFlag.upperBound});
    });

    test('trace has no value and no flag', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', 'trace'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
      ]);
      final fat = _parsed(grid.asSeparateBoxes()).nutrient(NutrientId.fat)!;
      expect(fat.per100!.value, isNull);
      expect(fat.flags, isEmpty);
    });

    test('comma decimals are read', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '3,5 g'],
        ['Carbohydrate', '60 g'],
        ['Protein', '0,5 g'],
      ]);
      final label = _parsed(grid.asSeparateBoxes());
      expect(label.nutrient(NutrientId.fat)!.per100!.value, 3.5);
      expect(label.nutrient(NutrientId.protein)!.per100!.value, 0.5);
    });

    test('mg is converted to the canonical unit with no flag', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '3500 mg'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
        ['Calcium', '120 mg'],
      ]);
      final label = _parsed(grid.asSeparateBoxes());
      expect(label.nutrient(NutrientId.fat)!.per100!.value, 3.5);
      expect(label.nutrient(NutrientId.fat)!.flags, isEmpty);
      expect(label.nutrient(NutrientId.calcium)!.per100!.value, 120);
    });

    test(
      'a nutrient with the wrong unit class has no value and is flagged',
      () {
        const grid = FixtureGrid([
          ['', 'Per 100 g'],
          ['Fat', '3.5 kcal'],
          ['Energy', '1046 kJ / 250 kcal'],
          ['Carbohydrate', '60 g'],
          ['Protein', '10 g'],
        ]);
        final fat = _parsed(grid.asSeparateBoxes()).nutrient(NutrientId.fat)!;
        expect(fat.per100!.value, isNull);
        expect(fat.flags, {FieldFlag.unitUnexpected});
      },
    );

    test('Energy with no unit is not assigned to kJ or kcal', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1046'],
        ['Fat', '3.5 g'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
      ]);
      final r = _notRead(grid.asSeparateBoxes());
      expect(r.reason, LabelFailureReason.noEnergyRow);
    });
  });

  group('plausibility wired into the lexer', () {
    FixtureGrid energy(String kj) => FixtureGrid([
      ['', 'Per 100 g'],
      ['Energy', kj],
      ['Fat', '3.5 g'],
      ['Carbohydrate', '60 g'],
      ['Protein', '10 g'],
    ]);

    test('1,234 kJ stays ambiguous with the default config', () {
      final label = _parsed(energy('1,234 kJ / 295 kcal').asSeparateBoxes());
      final kj = label.nutrient(NutrientId.energyKj)!;
      expect(kj.per100!.value, isNull);
      expect(kj.flags, {FieldFlag.ambiguousNumber});
      expect(label.nutrient(NutrientId.energyKcal)!.per100!.value, 295);
    });

    test('1,234 kJ is 1234 when the config sets an energy floor', () {
      final label = _parsed(
        energy('1,234 kJ / 295 kcal').asSeparateBoxes(),
        parser: const LabelParser(config: ParserConfig(minEnergyKjPer100: 100)),
      );
      final kj = label.nutrient(NutrientId.energyKj)!;
      expect(kj.per100!.value, 1234);
      expect(kj.flags, isEmpty);
    });

    test('1,234 g of fat per 100 g can only be 1.234', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '1,234 g'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
      ]);
      final fat = _parsed(grid.asSeparateBoxes()).nutrient(NutrientId.fat)!;
      expect(fat.per100!.value, 1.234);
      expect(fat.flags, isEmpty);
    });

    test('1,234 g per serving stays ambiguous', () {
      const grid = FixtureGrid([
        ['', 'Per serving'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '1,234 g'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
      ]);
      final fat = _parsed(grid.asSeparateBoxes()).nutrient(NutrientId.fat)!;
      expect(fat.perServing!.value, isNull);
      expect(fat.flags, {FieldFlag.ambiguousNumber});
    });

    test('1.046 kJ reads 1046 when the config sets an energy floor', () {
      final doc = energy('1.046 kJ / 250 kcal').asSeparateBoxes();
      final plain = _parsed(doc).nutrient(NutrientId.energyKj)!;
      expect(plain.per100!.value, isNull);
      expect(plain.flags, {FieldFlag.ambiguousNumber});
      final floor = _parsed(
        doc,
        parser: const LabelParser(config: ParserConfig(minEnergyKjPer100: 100)),
      ).nutrient(NutrientId.energyKj)!;
      expect(floor.per100!.value, 1046);
      expect(floor.flags, isEmpty);
    });

    test('1.046 g of fat per 100 g can only be 1.046', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '1.046 g'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
      ]);
      final fat = _parsed(grid.asSeparateBoxes()).nutrient(NutrientId.fat)!;
      expect(fat.per100!.value, 1.046);
    });

    test('1.046 g of fat per serving stays ambiguous', () {
      const grid = FixtureGrid([
        ['', 'Per serving'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '1.046 g'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
      ]);
      final fat = _parsed(grid.asSeparateBoxes()).nutrient(NutrientId.fat)!;
      expect(fat.perServing!.value, isNull);
      expect(fat.flags, {FieldFlag.ambiguousNumber});
    });

    test('0.125 g per serving stays ambiguous without a floor', () {
      const grid = FixtureGrid([
        ['', 'Per serving'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '3 g'],
        ['Carbohydrate', '60 g'],
        ['Protein', '0.125 g'],
      ]);
      final protein = _parsed(
        grid.asSeparateBoxes(),
      ).nutrient(NutrientId.protein)!;
      expect(protein.perServing!.value, isNull);
      expect(protein.flags, {FieldFlag.ambiguousNumber});
    });

    test('a cell with two quantities for one nutrient is ambiguous', () {
      const grid = FixtureGrid([
        ['', 'Per 100 g'],
        ['Energy', '1046 kJ / 250 kcal'],
        ['Fat', '3 g / 4 g'],
        ['Carbohydrate', '60 g'],
        ['Protein', '10 g'],
      ]);
      final fat = _parsed(grid.asSeparateBoxes()).nutrient(NutrientId.fat)!;
      expect(fat.per100!.value, isNull);
      expect(fat.flags, {FieldFlag.ambiguousNumber});
    });
  });

  group('vocabularies', () {
    test('the vocabulary with the most names wins', () {
      const german = FixtureGrid([
        ['Energie', '1046 kJ / 250 kcal'],
        ['Fett', '3.5 g'],
        ['Kohlenhydrate', '60 g'],
        ['Eiweiss', '10 g'],
      ]);
      final label = _parsed(
        german.asSeparateBoxes(),
        parser: const LabelParser(
          vocabularies: [englishLabelVocabulary, _Tiny()],
        ),
      );
      expect(label.languageTag, 'xx');
      expect(label.warnings.contains(LabelWarning.languageAmbiguous), isFalse);
    });

    test('a tie within one name takes the first and warns', () {
      final label = _parsed(
        euOneColumn.asSeparateBoxes(),
        parser: const LabelParser(
          vocabularies: [englishLabelVocabulary, _Copy('en2')],
        ),
      );
      expect(label.languageTag, 'en');
      expect(label.warnings, {LabelWarning.languageAmbiguous});
    });

    test('a vocabulary far behind does not warn', () {
      final label = _parsed(
        euOneColumn.asSeparateBoxes(),
        parser: const LabelParser(
          vocabularies: [englishLabelVocabulary, _Tiny()],
        ),
      );
      expect(label.languageTag, 'en');
      expect(label.warnings, isEmpty);
    });
  });

  group('never throws', () {
    test('random documents give a result', () {
      final random = Random(11);
      const pieces = [
        'Energy',
        'Fat',
        'Protein',
        'Salt',
        'Carbohydrate',
        'of which',
        '5 g',
        '1,234',
        '<',
        '-',
        '%',
        'kJ',
        '/',
        'µg',
        '9',
        'trace',
        'Per 100 g',
        'As prepared',
        '% Daily Value',
        'Serving size',
        'Servings per container',
        '',
        ' ',
        '٣',
        '\u{1F600}',
        '1O',
        '3.5.2',
        '.',
        ',',
        '1.234,5',
        '2/3 cup (55 g)',
        'n/a',
        '<<',
        '--',
      ];
      double coordinate() {
        switch (random.nextInt(12)) {
          case 0:
            return double.nan;
          case 1:
            return double.infinity;
          case 2:
            return -random.nextDouble();
          case 3:
            return 0;
          default:
            return random.nextDouble();
        }
      }

      String text() => List.generate(
        random.nextInt(5),
        (_) => pieces[random.nextInt(pieces.length)],
      ).join(random.nextBool() ? ' ' : '');
      LabelRect rect() => LabelRect(
        left: coordinate(),
        top: coordinate(),
        width: coordinate(),
        height: coordinate(),
      );

      for (var i = 0; i < 300; i++) {
        final doc = RecognizedDocument(
          source: RecognitionSource.values[random.nextInt(3)],
          imageWidth: 100,
          imageHeight: 100,
          boxes: [
            for (var b = 0; b < random.nextInt(30); b++)
              RecognizedTextBox(text: text(), box: rect()),
          ],
          tables: [
            for (var t = 0; t < random.nextInt(3); t++)
              RecognizedTable(
                box: rect(),
                cells: [
                  for (var c = 0; c < random.nextInt(12); c++)
                    RecognizedCell(
                      text: text(),
                      box: rect(),
                      row: random.nextInt(6) - 1,
                      column: random.nextInt(5) - 1,
                    ),
                ],
              ),
          ],
        );
        expect(_parser.parse(doc), isA<LabelParseResult>());
      }
    });
  });
}
