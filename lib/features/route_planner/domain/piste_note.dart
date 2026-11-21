import 'piste_difficulty.dart';
import 'routed_path.dart';

/// The color a trail map marks a grade with, as a word in the user's language.
typedef PisteColorName = String Function(PisteDifficulty difficulty);

/// What a descent down [pistes] says in its notes: the color alone when every
/// graded stretch shows the same one, else each run of one color after the
/// names of its pistes, in order ("Kandahar: Red · Olympia: Black"). Stretches
/// without a grade are left out; null when none has one.
String? pisteNote(List<PisteStretch> pistes, PisteColorName colorName) {
  final runs = <({String color, List<String> names})>[];
  for (final PisteStretch(:name, :difficulty) in pistes) {
    if (difficulty == null) continue;
    final color = colorName(difficulty);
    if (runs.lastOrNull?.color != color) {
      runs.add((color: color, names: <String>[]));
    }
    final names = runs.last.names;
    if (name != null && !names.contains(name)) names.add(name);
  }
  if (runs.isEmpty) return null;
  if (runs.every((run) => run.color == runs.first.color)) {
    return runs.first.color;
  }
  return [
    for (final run in runs)
      run.names.isEmpty ? run.color : '${run.names.join(', ')}: ${run.color}',
  ].join(' · ');
}
