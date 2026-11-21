import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/itinerary/run_span.dart';

void main() {
  ItineraryItem entry(int id, {int? start, int? end, int endDayOffset = 0}) =>
      ItineraryItem(
        id: id,
        tripId: 1,
        date: DateTime(2026, 3, 14),
        sortOrder: id,
        kind: ItemKind.transport,
        startMinutes: start,
        endMinutes: end,
        endDayOffset: endDayOffset,
        chordDisplay: TrackDisplay.auto,
      );

  test('runs from the first start to the last end', () {
    expect(
      runSpan([entry(1, start: 480, end: 525), entry(2, start: 540, end: 760)]),
      (start: 480, end: 760, endDayOffset: 0),
    );
  });

  test('passes over members without a time', () {
    expect(runSpan([entry(1), entry(2, start: 600), entry(3, end: 700)]), (
      start: 600,
      end: 700,
      endDayOffset: 0,
    ));
  });

  test('an end past midnight keeps its day', () {
    expect(
      runSpan([
        entry(1, start: 1320, end: 1400),
        entry(2, start: 1410, end: 420, endDayOffset: 1),
      ]),
      (start: 1320, end: 420, endDayOffset: 1),
    );
  });

  test('one timed moment is a start without an end', () {
    expect(runSpan([entry(1, start: 600), entry(2)]), (
      start: 600,
      end: null,
      endDayOffset: 0,
    ));
  });

  test('a run without times has no span', () {
    expect(runSpan([entry(1), entry(2)]), isNull);
  });
}
