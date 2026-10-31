import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/transport_search/presentation/search_seed.dart';
import 'package:travelplanner/features/trips/planned_journey.dart';

/// What the connection search opens holding: an end the router can be asked
/// about as it stands, or only a name for the place picker to start from.
void main() {
  group('a leg as the form holds it', () {
    test('an end with only a name is a hint, never a place', () {
      // The app does not turn a name into an address: which Rahlstedt was
      // meant is for the user to pick from the geocoder's answers.
      final seed = SearchSeed.ofLeg(
        fromName: 'Rahlstedt',
        toName: 'Hamburg Hbf',
      );

      expect(seed.from, isNull);
      expect(seed.fromHint, 'Rahlstedt');
      expect(seed.to, isNull);
      expect(seed.toHint, 'Hamburg Hbf');
    });

    test('an end with a position is searched from it, under its name', () {
      final seed = SearchSeed.ofLeg(
        fromName: 'Office',
        fromLat: 53.6,
        fromLon: 10.15,
      );

      expect(seed.from?.queryId, '53.6,10.15');
      expect(seed.from?.name, 'Office');
      expect(seed.fromHint, isNull);
    });

    test('an id still describing an end wins over its position', () {
      final seed = SearchSeed.ofLeg(
        toName: 'Hamburg Hbf',
        toPlaceId: 'de-DELFI_de:02000:10951:1:6',
        toLat: 53.55,
        toLon: 10.0,
      );

      expect(seed.to?.queryId, 'de-DELFI_de:02000:10951:1:6');
      expect(seed.toHint, isNull);
    });

    test('an end with nothing at all leaves the field empty', () {
      final seed = SearchSeed.ofLeg(departMinutes: 452);

      expect(seed.from, isNull);
      expect(seed.fromHint, isNull);
      expect(seed.to, isNull);
      expect(seed.toHint, isNull);
      expect(seed.departMinutes, 452);
    });
  });

  group('a stored run', () {
    ItineraryItem leg({String? fromPlaceId, int? start}) => ItineraryItem(
      id: 1,
      tripId: 1,
      date: DateTime(2026, 8, 3),
      sortOrder: 0,
      kind: ItemKind.transport,
      startMinutes: start,
      endDayOffset: 0,
      chordDisplay: TrackDisplay.auto,
      fromLocation: 'Rahlstedt',
      toLocation: 'Hamburg Hbf',
      fromPlaceId: fromPlaceId,
    );

    test('opens on its ends, a name standing in for an unaddressed one', () {
      final seed = SearchSeed.ofJourney(
        PlannedJourney(
          groupId: null,
          legs: [leg(fromPlaceId: 'stop-1', start: 452)],
        ),
      );

      expect(seed.from?.queryId, 'stop-1');
      expect(seed.from?.name, 'Rahlstedt');
      expect(seed.to, isNull);
      expect(seed.toHint, 'Hamburg Hbf');
      expect(seed.departMinutes, 452);
    });

    test('a better departure overrides the planned one', () {
      final seed = SearchSeed.ofJourney(
        PlannedJourney(groupId: null, legs: [leg(start: 452)]),
        departMinutes: 470,
      );

      expect(seed.departMinutes, 470);
    });
  });
}
