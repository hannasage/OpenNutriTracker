import 'package:flutter_test/flutter_test.dart';
import 'package:nutrition_label_reader/nutrition_label_reader.dart';
import 'package:nutrition_label_reader/src/parser/salt_sodium_rules.dart';

const _box = LabelRect(left: 0.1, top: 0.2, width: 0.5, height: 0.02);

ParsedQuantity _g(double? value, {String? raw, bool bound = false}) =>
    ParsedQuantity(
      value: value,
      unit: LabelUnit.g,
      rawText: raw ?? '$value g',
      isUpperBound: bound,
    );

ParsedQuantity _mg(double? value, {String? raw}) => ParsedQuantity(
  value: value,
  unit: LabelUnit.mg,
  rawText: raw ?? '$value mg',
);

ParsedNutrient _n(
  NutrientId id, {
  ParsedQuantity? per100,
  ParsedQuantity? perServing,
  ParsedQuantity? unknownBasis,
  Set<FieldFlag> flags = const {},
}) => ParsedNutrient(
  id: id,
  per100: per100,
  perServing: perServing,
  unknownBasis: unknownBasis,
  flags: flags,
  sourceBox: _box,
);

ParsedNutrient _find(List<ParsedNutrient> list, NutrientId id) =>
    list.firstWhere((n) => n.id == id);

void main() {
  group('salt read, sodium not (R12)', () {
    test('derives sodium in mg and flags it', () {
      final salt = _n(NutrientId.salt, per100: _g(0.5, raw: '0.5 g'));
      final result = applySaltSodiumRules([salt, _n(NutrientId.fat)]);
      expect(result.map((n) => n.id), [
        NutrientId.salt,
        NutrientId.sodium,
        NutrientId.fat,
      ]);
      expect(result.first, salt);
      final sodium = _find(result, NutrientId.sodium);
      expect(sodium.per100!.value, 0.5 * 1000 / 2.5);
      expect(sodium.per100!.value, closeTo(200, 1e-9));
      expect(sodium.per100!.unit, LabelUnit.mg);
      expect(sodium.per100!.isDerived, isTrue);
      expect(sodium.per100!.rawText, '0.5 g');
      expect(sodium.flags, {FieldFlag.derivedFromOtherUnit});
      expect(sodium.review, FieldReview.checkThis);
      expect(sodium.sourceBox, _box);
    });

    test('does not round the derived value', () {
      final result = applySaltSodiumRules([
        _n(NutrientId.salt, per100: _g(0.15)),
      ]);
      expect(_find(result, NutrientId.sodium).per100!.value, 0.15 * 1000 / 2.5);
    });

    test('derives every slot that has a salt value', () {
      final result = applySaltSodiumRules([
        _n(
          NutrientId.salt,
          per100: _g(0.5),
          perServing: _g(0.15),
          unknownBasis: _g(1),
        ),
      ]);
      final sodium = _find(result, NutrientId.sodium);
      expect(sodium.per100!.value, closeTo(200, 1e-9));
      expect(sodium.perServing!.value, closeTo(60, 1e-9));
      expect(sodium.unknownBasis!.value, closeTo(400, 1e-9));
    });
  });

  group('sodium read, salt not (R13)', () {
    test('derives salt in g and flags it', () {
      final result = applySaltSodiumRules([
        _n(NutrientId.sodium, perServing: _mg(160, raw: '160 mg')),
      ]);
      expect(result.map((n) => n.id), [NutrientId.sodium, NutrientId.salt]);
      final salt = _find(result, NutrientId.salt);
      expect(salt.perServing!.value, 160 * 2.5 / 1000);
      expect(salt.perServing!.value, closeTo(0.4, 1e-9));
      expect(salt.perServing!.unit, LabelUnit.g);
      expect(salt.perServing!.isDerived, isTrue);
      expect(salt.perServing!.rawText, '160 mg');
      expect(salt.flags, {FieldFlag.derivedFromOtherUnit});
    });

    test('1 g of salt and 400 mg of sodium are the same amount', () {
      final toSodium = applySaltSodiumRules([
        _n(NutrientId.salt, per100: _g(1)),
      ]);
      expect(_find(toSodium, NutrientId.sodium).per100!.value, 400);
      final toSalt = applySaltSodiumRules([
        _n(NutrientId.sodium, per100: _mg(400)),
      ]);
      expect(_find(toSalt, NutrientId.salt).per100!.value, 1);
    });

    test('fills the empty slot of an existing salt nutrient', () {
      final read = _g(0.5, raw: '0.5 g');
      final result = applySaltSodiumRules([
        _n(NutrientId.salt, per100: read),
        _n(NutrientId.sodium, per100: _mg(200), perServing: _mg(60)),
      ]);
      expect(result, hasLength(2));
      final salt = _find(result, NutrientId.salt);
      expect(salt.per100, read);
      expect(salt.perServing!.isDerived, isTrue);
      expect(salt.perServing!.value, 60 * 2.5 / 1000);
      expect(salt.flags, {FieldFlag.derivedFromOtherUnit});
    });
  });

  group('what a rule does not do', () {
    test('keeps both values when both are read, with no flag', () {
      final list = [
        _n(NutrientId.salt, per100: _g(0.5)),
        _n(NutrientId.sodium, per100: _mg(300)),
      ];
      expect(applySaltSodiumRules(list), list);
    });

    test('adds no entry and no zero when neither is read', () {
      final list = [_n(NutrientId.fat), _n(NutrientId.protein)];
      final result = applySaltSodiumRules(list);
      expect(result, list);
      expect(result.any((n) => n.id == NutrientId.salt), isFalse);
      expect(result.any((n) => n.id == NutrientId.sodium), isFalse);
      expect(applySaltSodiumRules(const []), isEmpty);
    });

    test('does not use a value with no unit', () {
      const noUnit = ParsedQuantity(value: 160, unit: null, rawText: '160');
      final list = [
        _n(
          NutrientId.sodium,
          perServing: noUnit,
          flags: {FieldFlag.unitMissing},
        ),
      ];
      expect(applySaltSodiumRules(list), list);
    });

    test('does not use an unreadable value or an upper bound', () {
      final unreadable = [_n(NutrientId.salt, per100: _g(null, raw: '0..5 g'))];
      expect(applySaltSodiumRules(unreadable), unreadable);
      final bound = [_n(NutrientId.salt, per100: _g(0.5, bound: true))];
      expect(applySaltSodiumRules(bound), bound);
    });

    test('does not fill a slot that was read and rejected', () {
      final list = [
        _n(NutrientId.salt, per100: _g(0.5)),
        _n(NutrientId.sodium, per100: _mg(null, raw: '2O0 mg')),
      ];
      expect(applySaltSodiumRules(list), list);
    });

    test('does not use a derived value as a source', () {
      final derived = ParsedQuantity(
        value: 200,
        unit: LabelUnit.mg,
        rawText: '0.5 g',
        isDerived: true,
      );
      final list = [_n(NutrientId.sodium, per100: derived)];
      expect(applySaltSodiumRules(list), list);
    });

    test('copies only the column doubts of the source', () {
      final result = applySaltSodiumRules([
        _n(
          NutrientId.salt,
          per100: _g(0.5),
          flags: {FieldFlag.columnAmbiguous, FieldFlag.duplicateRow},
        ),
      ]);
      expect(_find(result, NutrientId.sodium).flags, {
        FieldFlag.derivedFromOtherUnit,
        FieldFlag.columnAmbiguous,
      });
    });
  });
}
