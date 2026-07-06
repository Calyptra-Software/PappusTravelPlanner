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

  ItineraryItem placeItem(int id, {int? minutes, String location = 'Place'}) {
    return ItineraryItem(
      id: id,
      tripId: 1,
      date: DateTime(2026, 7, 5),
      sortOrder: id,
      kind: ItemKind.place,
      title: null,
      startMinutes: minutes,
      endMinutes: null,
      notes: null,
      location: location,
      mode: null,
      fromLocation: null,
      toLocation: null,
    );
  }

  group('pickFeaturedTrip', () {
    test('prefers an ongoing trip over a sooner-starting upcoming one', () {
      final ongoing = trip(
          id: 1,
          title: 'Ongoing',
          start: DateTime(2026, 7, 4),
          end: DateTime(2026, 7, 8));
      final upcoming =
          trip(id: 2, title: 'Upcoming', start: DateTime(2026, 7, 6));

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

    test('ongoing trip shows "Day X of Y" and today items (capped at 3)', () {
      final t = trip(
          id: 1,
          title: 'Italy',
          start: DateTime(2026, 7, 4),
          end: DateTime(2026, 7, 9));
      final items = [
        placeItem(1, minutes: 9 * 60, location: 'Colosseum'),
        placeItem(2, minutes: 12 * 60, location: 'Lunch'),
        placeItem(3, minutes: 15 * 60, location: 'Museum'),
        placeItem(4, minutes: 18 * 60, location: 'Dinner'),
      ];
      final p = buildWidgetPayload([t], items, now, l10n, 'en');

      expect(p.isOngoing, isTrue);
      expect(p.countdown, 'Day 2 of 6');
      expect(p.rows.length, 3);
      expect(p.rows.first.time, '09:00');
      expect(p.rows.first.text, 'Colosseum');
      expect(p.moreCount, 1);
    });
  });
}
