import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/sharing/trip_bundle.dart';

void main() {
  /// A fully-populated bundle exercising every table, nullable field, enum, and
  /// the three cost attachment targets (item / group / trip).
  TripBundle sample() => TripBundle(
    schemaVersion: 16,
    trip: BundleTrip(
      title: 'Rome',
      destination: 'Italy',
      startDate: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 7),
      notes: 'Bring sunscreen',
      colorValue: 0xFF00695C,
      createdAt: DateTime(2026, 1, 2, 3, 4, 5),
    ),
    groups: const [
      BundleGroup(localId: 10, label: 'Train to Rome', collapsed: true),
    ],
    items: [
      BundleItem(
        localId: 100,
        date: DateTime(2026, 5, 1),
        kind: ItemKind.place,
        title: 'Colosseum',
        startMinutes: 600,
        endMinutes: 720,
        actualStartMinutes: 615,
        actualEndMinutes: 715,
        location: 'Piazza del Colosseo',
      ),
      BundleItem(
        localId: 101,
        groupLocalId: 10,
        date: DateTime(2026, 5, 1),
        sortOrder: 1,
        kind: ItemKind.transport,
        mode: 'train',
        fromLocation: 'Florence',
        toLocation: 'Rome',
      ),
    ],
    costs: [
      BundleCost(
        itemLocalId: 100,
        amountMinor: 1600,
        currency: 'EUR',
        reason: 'Tickets',
        paidBy: 'Alice',
        paid: true,
        createdAt: DateTime(2026, 5, 1, 9),
        beneficiaries: const ['Alice', 'Bob'],
      ),
      BundleCost(
        groupLocalId: 10,
        amountMinor: 8000,
        currency: 'EUR',
        reason: 'Train',
        createdAt: DateTime(2026, 5, 1, 8),
      ),
      BundleCost(
        amountMinor: -500,
        currency: 'USD',
        reason: 'Refund',
        paidBy: 'Bob',
        createdAt: DateTime(2026, 5, 2),
      ),
    ],
    checklists: [
      BundleChecklist(
        localId: 200,
        title: 'Packing',
        collapsed: true,
        createdAt: DateTime(2026, 4, 1),
        items: [
          BundleChecklistItem(
            label: 'Passport',
            done: true,
            createdAt: DateTime(2026, 4, 1),
          ),
          BundleChecklistItem(
            label: 'Charger',
            sortOrder: 1,
            createdAt: DateTime(2026, 4, 1),
          ),
        ],
      ),
    ],
    collapsedDays: [DateTime(2026, 5, 3)],
    participants: const ['Alice', 'Bob'],
    reasonIcons: const {'Tickets': 7},
  );

  test('round-trips through JSON unchanged', () {
    final original = sample();
    final restored = TripBundle.fromJson(original.toJson());
    // Comparing the re-serialized JSON avoids hand-writing == on every class
    // while still proving every field survives the round trip.
    expect(restored.toJson(), original.toJson());
  });

  test('round-trips through encoded bytes', () {
    final original = sample();
    final restored = TripBundle.decode(original.encode());
    expect(restored.toJson(), original.toJson());
  });

  test('preserves cost attachment targets and negative amounts', () {
    final restored = TripBundle.decode(sample().encode());
    final byReason = {for (final c in restored.costs) c.reason: c};

    expect(byReason['Tickets']!.itemLocalId, 100);
    expect(byReason['Tickets']!.groupLocalId, isNull);
    expect(byReason['Tickets']!.beneficiaries, ['Alice', 'Bob']);

    expect(byReason['Train']!.groupLocalId, 10);
    expect(byReason['Train']!.itemLocalId, isNull);

    // Trip-level cost: neither item nor group; keeps its negative (refund) sign.
    expect(byReason['Refund']!.itemLocalId, isNull);
    expect(byReason['Refund']!.groupLocalId, isNull);
    expect(byReason['Refund']!.amountMinor, -500);
    expect(byReason['Refund']!.currency, 'USD');
  });

  test('preserves defaults and nullable fields', () {
    final restored = TripBundle.decode(sample().encode());
    final place = restored.items.firstWhere((i) => i.kind == ItemKind.place);
    expect(place.mode, isNull);
    expect(place.groupLocalId, isNull);
    expect(place.location, 'Piazza del Colosseo');

    final transport = restored.items.firstWhere(
      (i) => i.kind == ItemKind.transport,
    );
    expect(transport.mode, 'train');
    expect(transport.title, isNull);
    expect(transport.location, isNull);
  });

  test('rejects payloads that are not trip bundles', () {
    expect(
      () => TripBundle.fromJson({'kind': 'something.else'}),
      throwsFormatException,
    );
  });

  test('rejects an unknown enum value from a newer sender', () {
    final json = sample().toJson();
    (json['items'] as List).first['kind'] = 'teleport';
    expect(() => TripBundle.fromJson(json), throwsFormatException);
  });

  group('currencies', () {
    test('a built-in is written under the name the old format used', () {
      final json = sample().toJson();
      final costs = (json['costs'] as List).cast<Map<String, dynamic>>();
      expect(costs.map((c) => c['currency']), ['eur', 'eur', 'usd']);
      // …and reads back as the code.
      expect(TripBundle.fromJson(json).costs.map((c) => c.currency), [
        'EUR',
        'EUR',
        'USD',
      ]);
    });

    test('a currency the old format lacked is written as its code', () {
      expect(bundleCurrencyToken('JPY'), 'JPY');
      expect(bundleCurrencyCode('JPY'), 'JPY');
      expect(bundleNeedsCurrencyFormat(const ['EUR', 'USD']), isFalse);
      expect(bundleNeedsCurrencyFormat(const ['EUR', 'JPY']), isTrue);
    });

    test('a bundle naming no currencies falls back to the old four', () {
      final json = sample().toJson()..remove('currencies');
      final bundle = TripBundle.fromJson(json);
      expect(bundle.currencies.map((c) => c.code), [
        'EUR',
        'USD',
        'GBP',
        'CHF',
      ]);
      // Enough to still print an amount with its symbol.
      expect(bundle.currencyBook.byCode('EUR')?.symbol, '€');
      expect(bundle.currencyBook.base?.code, 'EUR');
    });

    test('the book resolves the currencies the bundle carries', () {
      final bundle = TripBundle.fromJson(
        sample().toJson()
          ..['currencies'] = [
            const BundleCurrency(
              code: 'EUR',
              symbol: '€',
              rateMicros: kRateOne,
              isBase: true,
            ).toJson(),
            const BundleCurrency(
              code: 'USD',
              symbol: r'US$',
              rateMicros: 900000,
            ).toJson(),
          ],
      );
      expect(bundle.currencyBook.toBase(1000, 'USD'), 900);
      expect(bundle.currencyBook.toBase(1000, 'GBP'), isNull);
    });
  });

  group('trip kind', () {
    test('a kind survives the round trip', () {
      final routine = TripBundle(
        schemaVersion: 27,
        tags: const ['commute'],
        trip: BundleTrip(
          title: 'To work',
          destination: 'Office',
          kind: TripKind.routine,
          colorValue: 0xFF00695C,
          createdAt: DateTime(2026, 1, 2),
        ),
      );

      final decoded = TripBundle.decode(routine.encode());
      expect(decoded.trip.kind, TripKind.routine);
      expect(decoded.tags, ['commute']);
    });

    test('a bundle written before v4 reads as an ordinary trip', () {
      final json = {
        'title': 'Rome',
        'destination': 'Italy',
        'startDate': null,
        'endDate': null,
        'notes': null,
        'colorValue': 0xFF00695C,
        'createdAt': '2026-01-02T00:00:00.000',
      };
      final trip = BundleTrip.fromJson(json);
      expect(trip.kind, TripKind.trip);
    });

    test('an unknown kind from a newer sender reads as an ordinary trip', () {
      // The plan is all there; a journey is the shape that shows every entry
      // of it, so this degrades rather than throwing.
      final json = {
        'title': 'Rome',
        'destination': '',
        'kind': 'sabbatical',
        'colorValue': 0xFF00695C,
        'createdAt': '2026-01-02T00:00:00.000',
      };
      expect(BundleTrip.fromJson(json).kind, TripKind.trip);
    });
  });
}
