import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/home_widget/widget_payload.dart';
import 'package:travelplanner/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final now = DateTime(2026, 7, 5, 10);

  setUpAll(() async => initializeDateFormatting());

  Trip trip({
    required int id,
    required String title,
    DateTime? start,
    DateTime? end,
    String destination = '',
  }) {
    return Trip(
      id: id,
      title: title,
      destination: destination,
      startDate: start,
      endDate: end,
      notes: null,
      colorValue: 0xFF00695C,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  ItineraryItem placeItem(
    int id, {
    int? minutes,
    int? endMinutes,
    int? actualMinutes,
    int? actualEndMinutes,
    String location = 'Place',
    String? notes,
  }) {
    return ItineraryItem(
      id: id,
      tripId: 1,
      date: DateTime(2026, 7, 5),
      sortOrder: id,
      kind: ItemKind.place,
      title: null,
      startMinutes: minutes,
      endMinutes: endMinutes,
      actualStartMinutes: actualMinutes,
      actualEndMinutes: actualEndMinutes,
      notes: notes,
      location: location,
      mode: null,
      fromLocation: null,
      toLocation: null,
    );
  }

  group('isTripOngoing', () {
    final t = trip(
      id: 1,
      title: 'T',
      start: DateTime(2026, 7, 9),
      end: DateTime(2026, 7, 11),
    );

    test('is true on the last day even with a time-of-day', () {
      // Raw DateTime.now() carries a time; the end day must still count as ongoing.
      expect(isTripOngoing(t, DateTime(2026, 7, 11, 0, 41)), isTrue);
      expect(isTripOngoing(t, DateTime(2026, 7, 11, 23, 59)), isTrue);
    });

    test('is true on the first day and false the day after the end', () {
      expect(isTripOngoing(t, DateTime(2026, 7, 9, 8)), isTrue);
      expect(isTripOngoing(t, DateTime(2026, 7, 12, 0, 1)), isFalse);
    });
  });

  group('pickFeaturedTrip', () {
    test('prefers an ongoing trip over a sooner-starting upcoming one', () {
      final ongoing = trip(
        id: 1,
        title: 'Ongoing',
        start: DateTime(2026, 7, 4),
        end: DateTime(2026, 7, 8),
      );
      final upcoming = trip(
        id: 2,
        title: 'Upcoming',
        start: DateTime(2026, 7, 6),
      );

      expect(pickFeaturedTrip([upcoming, ongoing], now)!.title, 'Ongoing');
    });

    test('picks the nearest upcoming when none are ongoing', () {
      final soon = trip(id: 1, title: 'Soon', start: DateTime(2026, 7, 7));
      final later = trip(id: 2, title: 'Later', start: DateTime(2026, 7, 20));

      expect(pickFeaturedTrip([later, soon], now)!.title, 'Soon');
    });

    test('returns null when there are no trips', () {
      expect(pickFeaturedTrip(const [], now), isNull);
    });
  });

  group('buildWidgetPayload', () {
    test('empty state when there are no trips', () {
      final p = buildWidgetPayload(const [], const [], now, l10n, 'en');
      expect(p.hasTrip, isFalse);
      expect(p.emptyTitle, isNotEmpty);
    });

    test('upcoming trip shows an "in N days" countdown', () {
      final t = trip(id: 1, title: 'Italy', start: DateTime(2026, 7, 10));
      final p = buildWidgetPayload([t], const [], now, l10n, 'en');
      expect(p.hasTrip, isTrue);
      expect(p.isOngoing, isFalse);
      expect(p.countdown, 'in 5 days');
      expect(p.rows, isEmpty);
    });

    test('trip starting tomorrow shows the tomorrow label', () {
      final t = trip(id: 1, title: 'Italy', start: DateTime(2026, 7, 6));
      final p = buildWidgetPayload([t], const [], now, l10n, 'en');
      expect(p.countdown, 'Starts tomorrow');
    });

    test('ongoing trip shows "Day X of Y" and all today items (uncapped)', () {
      final t = trip(
        id: 1,
        title: 'Italy',
        start: DateTime(2026, 7, 4),
        end: DateTime(2026, 7, 9),
      );
      final items = [
        placeItem(1, minutes: 9 * 60, location: 'Colosseum'),
        placeItem(2, minutes: 12 * 60, location: 'Lunch'),
        placeItem(3, minutes: 15 * 60, location: 'Museum'),
        placeItem(4, minutes: 18 * 60, location: 'Dinner'),
      ];
      final p = buildWidgetPayload([t], items, now, l10n, 'en');

      expect(p.isOngoing, isTrue);
      expect(p.countdown, 'Day 2 of 6');
      // The native widget decides how many rows fit; the payload carries all.
      expect(p.rows.length, 4);
      expect(p.rows.first.time, '09:00');
      expect(p.rows.first.text, 'Colosseum');
      expect(p.rows.last.text, 'Dinner');
    });

    test('surfaces item notes (trimmed) on the row', () {
      final t = trip(
        id: 1,
        title: 'Italy',
        start: DateTime(2026, 7, 4),
        end: DateTime(2026, 7, 9),
      );
      final items = [
        placeItem(
          1,
          minutes: 9 * 60,
          location: 'Colosseum',
          notes: '  Bring water  ',
        ),
        placeItem(2, minutes: 12 * 60, location: 'Lunch'),
      ];
      final p = buildWidgetPayload([t], items, now, l10n, 'en');

      expect(p.rows[0].note, 'Bring water');
      expect(p.rows[1].note, '');
    });

    test('shows a start–end time range when the item has an end time', () {
      final t = trip(
        id: 1,
        title: 'Italy',
        start: DateTime(2026, 7, 4),
        end: DateTime(2026, 7, 9),
      );
      final items = [
        placeItem(1, minutes: 9 * 60 + 2, endMinutes: 9 * 60 + 39),
        placeItem(2, minutes: 12 * 60),
      ];
      final p = buildWidgetPayload([t], items, now, l10n, 'en');

      expect(p.rows[0].time, '09:02 – 09:39');
      expect(p.rows[1].time, '12:00');
    });

    test('a recorded actual time colours its miss onto the planned one', () {
      final t = trip(
        id: 1,
        title: 'Italy',
        start: DateTime(2026, 7, 4),
        end: DateTime(2026, 7, 9),
      );
      final items = [
        placeItem(
          1,
          minutes: 9 * 60,
          endMinutes: 10 * 60 + 30,
          actualMinutes: 9 * 60 + 15,
          actualEndMinutes: 10 * 60 + 25,
        ),
      ];
      final p = buildWidgetPayload([t], items, now, l10n, 'en');

      // The native row parses the markup back into spans: red late, green early.
      expect(
        p.rows.single.time,
        '09:00 <font color="#FF8A80">(+15)</font> – '
        '10:30 <font color="#A5D6A7">(−5)</font>',
      );
    });
  });
}
