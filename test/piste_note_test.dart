import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/features/route_planner/domain/piste_difficulty.dart';
import 'package:travelplanner/features/route_planner/domain/piste_note.dart';
import 'package:travelplanner/features/route_planner/domain/routed_path.dart';
import 'package:travelplanner/features/route_planner/presentation/route_planner_screen.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

String? _note(List<PisteStretch> pistes, {String locale = 'en'}) => pisteNote(
  pistes,
  (difficulty) =>
      pisteColorName(lookupAppLocalizations(Locale(locale)), difficulty),
);

PisteStretch _piste(String? name, PisteDifficulty? difficulty) =>
    PisteStretch(name: name, difficulty: difficulty);

void main() {
  test('one color is the color alone', () {
    expect(
      _note([
        _piste('Kandahar', PisteDifficulty.intermediate),
        _piste('Olympia', PisteDifficulty.intermediate),
      ]),
      'Red',
    );
  });

  test('advanced and expert are both black', () {
    expect(
      _note([
        _piste('Horn', PisteDifficulty.advanced),
        _piste('Kandahar', PisteDifficulty.expert),
      ]),
      'Black',
    );
  });

  test('several colors name their pistes, in order', () {
    expect(
      _note([
        _piste('Skiweg', PisteDifficulty.easy),
        _piste('Umfahrung', PisteDifficulty.easy),
        _piste('Kandahar', PisteDifficulty.advanced),
        _piste(null, PisteDifficulty.easy),
      ]),
      'Skiweg, Umfahrung: Blue · Kandahar: Black · Blue',
    );
  });

  test('a piste without a grade is left out', () {
    expect(
      _note([
        _piste('Kandahar', PisteDifficulty.intermediate),
        _piste('Ziehweg', null),
        _piste('Olympia', PisteDifficulty.intermediate),
      ]),
      'Red',
    );
    expect(_note([_piste('Ziehweg', null)]), isNull);
    expect(_note(const []), isNull);
  });

  test('a piste named twice in one color is named once', () {
    expect(
      _note([
        _piste('Horn', PisteDifficulty.advanced),
        _piste('Horn', PisteDifficulty.intermediate),
        _piste('Kochelberg', PisteDifficulty.intermediate),
        _piste('Horn', PisteDifficulty.intermediate),
      ]),
      'Horn: Black · Horn, Kochelberg: Red',
    );
  });

  test('every grade has a color, in the user\'s language', () {
    expect(
      [
        for (final difficulty in PisteDifficulty.values)
          _note([_piste(null, difficulty)], locale: 'de'),
      ],
      ['Grün', 'Blau', 'Rot', 'Schwarz', 'Schwarz', 'Gelb', 'Extrem'],
    );
  });
}
