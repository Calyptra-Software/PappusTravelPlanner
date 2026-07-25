import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/sharing/trip_bundle.dart';
import 'package:travelplanner/features/sharing/trip_ics.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  /// A fixed export instant, so DTSTAMP doesn't make the output vary run to run.
  final exportedAt = DateTime.utc(2026, 7, 20, 8, 30, 15);

  TripBundle bundleWith({
    DateTime? startDate,
    DateTime? endDate,
    String title = 'Rome',
    String destination = 'Italy',
    String? notes,
    List<BundleItem> items = const [],
    List<BundleCost> costs = const [],
    List<BundleAlternativeSet> alternativeSets = const [],
  }) => TripBundle(
    schemaVersion: 22,
    trip: BundleTrip(
      title: title,
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      notes: notes,
      colorValue: 0xFF00695C,
      createdAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
    ),
    items: items,
    costs: costs,
    alternativeSets: alternativeSets,
  );

  BundleItem place(
    int id, {
    required DateTime date,
    String? title,
    String? location,
    int? startMinutes,
    int? endMinutes,
    String? notes,
    int sortOrder = 0,
    int? alternativeLocalId,
  }) => BundleItem(
    localId: id,
    date: date,
    sortOrder: sortOrder,
    kind: ItemKind.place,
    title: title,
    location: location,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
    notes: notes,
    alternativeLocalId: alternativeLocalId,
  );

  String export(TripBundle bundle) => buildTripIcs(
    bundle: bundle,
    l10n: l10n,
    localeName: 'en',
    exportedAt: exportedAt,
  );

  /// Unfolds the document back into logical lines, undoing the 75-octet folding,
  /// so assertions can talk about content lines rather than physical ones.
  List<String> logicalLines(String ics) =>
      ics.replaceAll('\r\n ', '').split('\r\n')..removeWhere((l) => l.isEmpty);

  group('document shape', () {
    test('wraps the events in a VCALENDAR with CRLF line endings', () {
      final ics = export(
        bundleWith(
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 3),
        ),
      );

      expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
      expect(ics, endsWith('END:VCALENDAR\r\n'));
      expect(logicalLines(ics), contains('VERSION:2.0'));
      expect(logicalLines(ics), contains('X-WR-CALNAME:Rome'));
      // Every line break is a CRLF: no bare LF anywhere.
      expect(ics.replaceAll('\r\n', ''), isNot(contains('\n')));
    });

    test('every event carries the required UID and DTSTAMP', () {
      final ics = export(
        bundleWith(
          startDate: DateTime(2026, 8, 1),
          items: [place(1, date: DateTime(2026, 8, 1), title: 'Colosseum')],
        ),
      );
      final lines = logicalLines(ics);

      expect(lines.where((l) => l == 'BEGIN:VEVENT').length, 2);
      expect(lines.where((l) => l.startsWith('UID:')).length, 2);
      expect(lines.where((l) => l == 'DTSTAMP:20260720T083015Z').length, 2);
    });

    test('UIDs are namespaced by the trip, not bare row ids', () {
      final lines = logicalLines(
        export(bundleWith(items: [place(7, date: DateTime(2026, 8, 1))])),
      );
      final uid = lines.firstWhere((l) => l.startsWith('UID:item-7'));

      // The row id alone would collide across copies of the portable database.
      expect(uid, isNot('UID:item-7@travelplanner'));
      expect(uid, endsWith('@travelplanner'));
    });
  });

  group('times', () {
    test('a timed entry becomes a floating DATE-TIME event', () {
      final lines = logicalLines(
        export(
          bundleWith(
            items: [
              place(
                1,
                date: DateTime(2026, 8, 2),
                title: 'Colosseum',
                startMinutes: 9 * 60 + 30,
                endMinutes: 11 * 60,
              ),
            ],
          ),
        ),
      );

      // No Z and no TZID: the same wall clock wherever it is read.
      expect(lines, contains('DTSTART:20260802T093000'));
      expect(lines, contains('DTEND:20260802T110000'));
      expect(lines, contains('TRANSP:OPAQUE'));
    });

    test(
      'an untimed entry becomes an all-day event with an exclusive DTEND',
      () {
        final lines = logicalLines(
          export(
            bundleWith(
              items: [place(1, date: DateTime(2026, 8, 2), title: 'Wander')],
            ),
          ),
        );

        expect(lines, contains('DTSTART;VALUE=DATE:20260802'));
        expect(lines, contains('DTEND;VALUE=DATE:20260803'));
        expect(lines, contains('TRANSP:TRANSPARENT'));
      },
    );

    test('an all-day DTEND rolls over a month boundary', () {
      final lines = logicalLines(
        export(
          bundleWith(
            items: [place(1, date: DateTime(2026, 8, 31), title: 'Last day')],
          ),
        ),
      );

      expect(lines, contains('DTEND;VALUE=DATE:20260901'));
    });

    test('an end at or before its start is dropped rather than written', () {
      for (final end in [9 * 60, 8 * 60]) {
        final lines = logicalLines(
          export(
            bundleWith(
              items: [
                place(
                  1,
                  date: DateTime(2026, 8, 2),
                  title: 'Odd',
                  startMinutes: 9 * 60,
                  endMinutes: end,
                ),
              ],
            ),
          ),
        );

        // RFC 5545 requires DTEND to be strictly later than DTSTART.
        expect(lines, contains('DTSTART:20260802T090000'));
        expect(lines.any((l) => l.startsWith('DTEND')), isFalse);
      }
    });

    test('the trip banner spans its dates inclusively', () {
      final lines = logicalLines(
        export(
          bundleWith(
            startDate: DateTime(2026, 8, 1),
            endDate: DateTime(2026, 8, 5),
          ),
        ),
      );

      expect(lines, contains('DTSTART;VALUE=DATE:20260801'));
      expect(lines, contains('DTEND;VALUE=DATE:20260806'));
      expect(lines, contains('SUMMARY:Rome'));
      expect(lines, contains('LOCATION:Italy'));
    });

    test('a trip without dates gets no banner', () {
      final lines = logicalLines(
        export(bundleWith(items: [place(1, date: DateTime(2026, 8, 1))])),
      );

      expect(lines.where((l) => l == 'BEGIN:VEVENT').length, 1);
    });
  });

  group('content', () {
    test('a transport leg reads as mode: from → to', () {
      final lines = logicalLines(
        export(
          bundleWith(
            items: [
              BundleItem(
                localId: 1,
                date: DateTime(2026, 8, 1),
                kind: ItemKind.transport,
                mode: 'train',
                fromLocation: 'Munich',
                toLocation: 'Rome',
                startMinutes: 7 * 60,
              ),
            ],
          ),
        ),
      );

      expect(lines, contains('SUMMARY:Train: Munich → Rome'));
      // A leg's location is where it departs from.
      expect(lines, contains('LOCATION:Munich'));
    });

    test('a place falls back to its location, then to a placeholder', () {
      final lines = logicalLines(
        export(
          bundleWith(
            items: [
              place(1, date: DateTime(2026, 8, 1), location: 'Trastevere'),
              place(2, date: DateTime(2026, 8, 1)),
            ],
          ),
        ),
      );

      expect(lines, contains('SUMMARY:Trastevere'));
      expect(lines, contains('SUMMARY:${l10n.untitledEntry}'));
    });

    test('notes and the entry\'s own costs land in the description', () {
      final lines = logicalLines(
        export(
          bundleWith(
            items: [
              place(
                1,
                date: DateTime(2026, 8, 1),
                title: 'Museum',
                notes: 'Book ahead',
              ),
              place(2, date: DateTime(2026, 8, 1), title: 'Lunch'),
            ],
            costs: [
              BundleCost(
                itemLocalId: 1,
                amountMinor: 1850,
                currency: Currency.eur,
                reason: 'Tickets',
                createdAt: DateTime.utc(2026, 7, 1),
              ),
            ],
          ),
        ),
      );

      final description = lines.firstWhere((l) => l.startsWith('DESCRIPTION:'));
      expect(description, contains('Book ahead'));
      expect(description, contains('Tickets'));
      expect(description, contains('18'));
      // The cost belongs to item 1 only; item 2 gets no description at all.
      expect(lines.where((l) => l.startsWith('DESCRIPTION:')).length, 1);
    });
  });

  group('alternatives', () {
    test('only the chosen option is exported', () {
      final lines = logicalLines(
        export(
          bundleWith(
            alternativeSets: [
              BundleAlternativeSet(
                localId: 10,
                date: DateTime(2026, 8, 1),
                alternatives: const [
                  BundleAlternative(localId: 100, chosen: true),
                  BundleAlternative(localId: 101),
                ],
              ),
            ],
            items: [
              place(
                1,
                date: DateTime(2026, 8, 1),
                title: 'Museum',
                alternativeLocalId: 100,
              ),
              place(
                2,
                date: DateTime(2026, 8, 1),
                title: 'Beach',
                alternativeLocalId: 101,
              ),
              place(3, date: DateTime(2026, 8, 1), title: 'Dinner'),
            ],
          ),
        ),
      );

      expect(lines, contains('SUMMARY:Museum'));
      expect(lines, contains('SUMMARY:Dinner'));
      // The road not taken is not on the calendar.
      expect(lines, isNot(contains('SUMMARY:Beach')));
    });
  });

  group('escaping and folding', () {
    test('escapes the TEXT specials', () {
      final lines = logicalLines(
        export(
          bundleWith(
            items: [
              place(
                1,
                date: DateTime(2026, 8, 1),
                title: r'Bar, Grill; back\slash',
                notes: 'line one\nline two',
              ),
            ],
          ),
        ),
      );

      expect(lines, contains(r'SUMMARY:Bar\, Grill\; back\\slash'));
      expect(lines, contains(r'DESCRIPTION:line one\nline two'));
    });

    test('folds long lines to 75 octets without splitting a UTF-8 sequence', () {
      // Multi-byte throughout, so a naive character-count fold would overrun the
      // octet limit and a naive byte-slice fold would cut a rune in half.
      final ics = export(
        bundleWith(
          items: [
            place(1, date: DateTime(2026, 8, 1), title: 'Königsallee ☕ ' * 12),
          ],
        ),
      );

      for (final line in ics.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      // Every continuation line is marked by a single leading space, and the
      // text survives unfolding intact.
      final summary = logicalLines(
        ics,
      ).firstWhere((l) => l.startsWith('SUMMARY:'));
      expect(summary, contains('Königsallee ☕'));
      expect(utf8.encode(summary).length, greaterThan(75));
    });
  });
}
