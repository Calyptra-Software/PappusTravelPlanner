import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/features/transport_search/data/journey_mapper.dart';

/// A routine has no dates, but a timetable only exists on real ones. So a
/// connection is searched on a real date and laid back onto the plan — and what
/// must survive is the *shape*, not the date it was found on.
///
/// Regression: without this, legs imported into a routine kept the search date,
/// which the plan then read as tens of thousands of days past its anchor — a
/// one-day commute stamped out a trip ending in 2083.
void main() {
  final anchor = DateTime(1970, 1, 1);

  test('a leg on the search day lands on the plan day', () {
    expect(
      rebasedLegDay(
        DateTime(2026, 8, 3),
        foundOn: DateTime(2026, 8, 3),
        planDay: anchor,
      ),
      anchor,
    );
  });

  test('an overnight leg stays overnight, a day further into the plan', () {
    expect(
      rebasedLegDay(
        DateTime(2026, 8, 4),
        foundOn: DateTime(2026, 8, 3),
        planDay: anchor,
      ),
      DateTime(1970, 1, 2),
    );
  });

  test('it rebases onto any day of the plan, not only day one', () {
    expect(
      rebasedLegDay(
        DateTime(2026, 8, 4),
        foundOn: DateTime(2026, 8, 3),
        planDay: DateTime(1970, 1, 3),
      ),
      DateTime(1970, 1, 4),
    );
  });

  test('the time of day is dropped: a plan day is a day', () {
    expect(
      rebasedLegDay(
        DateTime(2026, 8, 3, 23, 40),
        foundOn: DateTime(2026, 8, 3, 7, 42),
        planDay: anchor,
      ),
      anchor,
    );
  });

  test('a search across a spring-forward keeps its overnight offset', () {
    // 2026-03-29 is 23 hours long in central Europe; a Duration of days would
    // collapse the night train onto its departure day.
    expect(
      rebasedLegDay(
        DateTime(2026, 3, 29),
        foundOn: DateTime(2026, 3, 28),
        planDay: anchor,
      ),
      DateTime(1970, 1, 2),
    );
  });
}
