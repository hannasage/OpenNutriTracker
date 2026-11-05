# nutrition_label_reader

Reads a nutrition facts panel from recognized text.

Status: work in progress. This version has Dart code only. Native Swift and
Kotlin code is not in this version. The package has no `flutter: plugin:`
block yet.

## How it reads a label

- The device recognizes the text. A fixed, rule-based parser then reads the
  numbers from that text.
- A language model never reads a label. A model never gives a nutrition
  number.
- The parser is pure, synchronous Dart. It does not repair digits from
  letters. It does not pick a side of an ambiguous comma or dot number when
  both readings fit. It does not assume a missing unit. It does not fill a
  missing nutrient. It does not throw on any input the tests give it.
- A value a rule made, such as sodium from salt, is marked `isDerived`. The
  nutrient also gets a flag. A user interface should show only the two
  `FieldReview` states: `looksRight` and `checkThis`.
- A label with no header has the basis `unknown`. Its values sit in the
  `unknownBasis` slot and every nutrient is flagged `columnAmbiguous`.

## Three recognition sources

The Dart model has three sources. The sources are a contract for the native
code, which does not exist yet.

- `iosDocuments`: tables and text boxes. For iOS 26 and later.
- `iosVisionText`: text boxes only. For older iOS.
- `androidMlKit`: text boxes only. For Android.

Every rectangle is in normalized image space: x and y from 0 to 1, origin at
the top-left, y downward, with the image orientation already applied. The
Pigeon schema is `pigeons/label_reader_api.dart`. The generated file is
`lib/src/platform/messages.g.dart`. Regenerate it with:

```sh
dart run pigeon --input pigeons/label_reader_api.dart
dart format lib/src/platform/messages.g.dart
```

## No photo is kept

This package never writes an image. Native code must delete any temp file it
makes. It must not keep the photo.

## Use

```dart
final reader = NutritionLabelReader();
final result = await reader.readImageFile(path);
switch (result) {
  case LabelParsed(:final label):
    // label.nutrients, label.primaryBasis, label.warnings, label.serving
  case LabelNotRead(:final reason):
    // reason says why. A label that was not read is not an exception.
}
```

`LabelReaderException` means the device could not produce text. To parse text
you already have, call `parseDocument`. It needs no platform.

In a test, set `NutritionLabelReaderPlatform.instance` to a
`FakeLabelReaderPlatform` from `package:nutrition_label_reader/testing.dart`.

## Vocabulary and languages

Vocabulary strings are parser data. They live in Dart, not in the app's
`intl_en.arb`. A reviewer who applies the ARB rule should not flag them.

The English words are a starting set from general knowledge of label wording.
They are not verified against real labels.

To add a language:

1. Implement `LabelVocabulary` in `lib/src/vocabulary/<tag>.dart`. Write
   every phrase in lowercase with single spaces.
2. Add fixtures under `test/fixtures/<tag>/`.
3. Pass the vocabulary in the `vocabularies` list of `LabelParser`.
4. Ask a native speaker to review the words.

A vocabulary adds words only. The number and unit rules stay shared. Digit
sets other than 0 to 9 are not read.

## Fixtures are synthetic

Every fixture is hand-written, OCR-style data. None is from a real product or a
real recognition run. Each fixture file says so in its first lines.

## Tuning values are unverified

The tolerances and ceilings in `ParserConfig` are starting points. None is
checked against real labels. Examples are the minimum names and values for a
panel, the energy unit tolerance, the per 100 ceilings, the energy floor, and
the macro sum slack. No accuracy figure exists yet. No real label photo set
exists yet.

Two constants repeat values the app uses, because the package must not import
app code:

- 4.184 kJ per kcal. The app uses the same value at
  `lib/core/utils/calc/unit_calc.dart:10`.
- 4, 4 and 9 kcal per gram of carbohydrate, protein and fat. The app uses the
  same factors at
  `lib/features/add_meal/domain/entity/meal_nutriments_entity.dart:404-425`.

The salt and sodium factor is 2.5 (salt = sodium x 2.5). Source: Regulation
(EU) No 1169/2011, Annex I, point 11. Read on 2026-11-05 in the original
Official Journal text at
https://eur-lex.europa.eu/legal-content/EN/TXT/HTML/?uri=CELEX:32011R1169. A
consolidated version was not checked. The rounding guidance for the number is
non-binding and is not used.

## Tests

```sh
flutter test
flutter analyze
```

Run them inside this folder. The app's `just test` runs only the app's
`test/` folder, so it does not run these tests. The app's `just format` does
not cover this folder. Run `dart format` on files here by hand.

## License

GPL-3.0, same as the app. See `LICENSE`.
