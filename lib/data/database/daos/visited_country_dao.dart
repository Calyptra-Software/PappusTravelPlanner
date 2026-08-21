import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'visited_country_dao.g.dart';

/// The countries the user says they have been to, without a trip here to show
/// for it.
///
/// Deliberately the smallest table in the app: a set of codes. Everything else
/// about "where have I been" is derived from the itinerary, and this holds only
/// what cannot be — a statement about a journey that was never filed here.
@DriftAccessor(tables: [VisitedCountries])
class VisitedCountryDao extends DatabaseAccessor<AppDatabase>
    with _$VisitedCountryDaoMixin {
  VisitedCountryDao(super.db);

  Stream<Set<String>> watchMarked() => select(
    visitedCountries,
  ).watch().map((rows) => {for (final row in rows) row.code});

  /// Adds or removes one mark.
  ///
  /// Removing takes away only the *statement*: a country the trips put on the
  /// map stays on it, because deleting a mark is not a claim never to have been
  /// somewhere. That is why the caller offers this on a country's own row and
  /// not as a general "clear" — there is nothing here to clear that the user did
  /// not put here.
  Future<void> setMarked(String code, bool marked) async {
    if (marked) {
      await into(
        visitedCountries,
      ).insertOnConflictUpdate(VisitedCountriesCompanion.insert(code: code));
    } else {
      await (delete(visitedCountries)..where((c) => c.code.equals(code))).go();
    }
  }
}
