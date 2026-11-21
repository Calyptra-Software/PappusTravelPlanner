/// How hard a piste is, as OpenStreetMap grades it (`piste:difficulty`), from
/// the gentlest to the steepest.
///
/// The grades are OSM's, not a country's colors: `easy` is a blue run in the
/// Alps and a green one in North America. Stored by [name] where it is stored
/// at all (a leg's route plan), never by index, so the order is free to follow
/// the slope.
enum PisteDifficulty {
  novice,
  easy,
  intermediate,
  advanced,
  expert,

  /// Off-piste routes: marked, maybe, but neither groomed nor patrolled.
  freeride,
  extreme;

  /// Reads an OSM `piste:difficulty` value, or a [name] written by this app;
  /// null for anything else, including a missing tag.
  static PisteDifficulty? byName(String? name) {
    for (final difficulty in values) {
      if (difficulty.name == name) return difficulty;
    }
    return null;
  }

  /// The hardest grade a ski section takes unless told otherwise: every piste,
  /// but no off-piste route, which no planner should send anyone down
  /// unasked.
  static const PisteDifficulty standard = expert;
}
