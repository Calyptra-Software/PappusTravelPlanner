import 'piste_difficulty.dart';
import 'routed_path.dart';

/// The color a trail map marks a grade with, as a word in the user's language.
typedef PisteColorName = String Function(PisteDifficulty difficulty);

/// How many of a descent's pistes its title names; [descentTitle] counts the
/// rest, and the notes name them all ([pisteNote]).
const int kTitledPistes = 2;

/// What a descent down the pistes [names] (joined by ", ", as
/// `PathSegment.name` has them) is titled: the first [kTitledPistes] names,
/// and how many more there are ("Kandahar, Olympia +3").
String? descentTitle(String? names) {
  if (names == null) return null;
  final parts = names.split(', ');
  if (parts.length <= kTitledPistes) return names;
  return '${parts.take(kTitledPistes).join(', ')} '
      '+${parts.length - kTitledPistes}';
}

/// What a descent down [pistes] says in its notes: the color alone when every
/// graded stretch shows the same one, else each run of one color after the
/// names of its pistes, in order ("Kandahar: Red · Olympia: Black").
/// Stretches without a grade are left out; null when none has one.
///
/// [named], for a descent whose title names only some of its pistes
/// ([descentTitle]), names every piste, in order: a run of one color after
/// its names even when it is the only one, a piste without a grade by its
/// name alone.
String? pisteNote(
  List<PisteStretch> pistes,
  PisteColorName colorName, {
  bool named = false,
}) {
  final runs = <({String? color, List<String> names})>[];
  for (final PisteStretch(:name, :difficulty) in pistes) {
    if (difficulty == null && (!named || name == null)) continue;
    final color = difficulty == null ? null : colorName(difficulty);
    if (runs.isEmpty || runs.last.color != color) {
      runs.add((color: color, names: <String>[]));
    }
    final names = runs.last.names;
    if (name != null && !names.contains(name)) names.add(name);
  }
  if (runs.isEmpty) return null;
  if (!named && runs.every((run) => run.color == runs.first.color)) {
    return runs.first.color;
  }
  return [
    for (final run in runs)
      [if (run.names.isNotEmpty) run.names.join(', '), ?run.color].join(': '),
  ].join(' · ');
}
