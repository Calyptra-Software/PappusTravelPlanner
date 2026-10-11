import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/features/map/track_import_plan.dart';
import 'package:travelplanner/features/map/track_times.dart';

/// What a recording's timestamps say about the entries it is divided among.
void main() {
  const offset = Duration(hours: 2);

  ItineraryItem leg(
    int id, {
    DateTime? date,
    int? start,
    int? end,
    int endDayOffset = 0,
    int? actualStart,
    int? actualEnd,
  }) => ItineraryItem(
    id: id,
    tripId: 1,
    date: date ?? DateTime(2026, 5, 1),
    sortOrder: id,
    kind: ItemKind.transport,
    startMinutes: start,
    endMinutes: end,
    endDayOffset: endDayOffset,
    actualStartMinutes: actualStart,
    actualEndMinutes: actualEnd,
    chordDisplay: TrackDisplay.auto,
  );

  /// A point [step] places north of the start, each about 111 m apart — so
  /// two different steps are always outside the stationary radius.
  LatLng at(int step) => LatLng(53.5 + step * 0.001, 9.9);
  DateTime utc(int minute, [int second = 0]) =>
      DateTime.utc(2026, 5, 1, 6, minute, second);

  // Standing at the start for two minutes, walking, standing at the handover
  // for two minutes, walking on.
  final points = [
    at(0), at(0), at(0), // 06:00–06:02 waiting to leave
    at(1), at(2), // walking
    at(3), at(3), at(3), // 06:05–06:07 the change
    at(4), at(5), // walking on
  ];
  final times = [for (var i = 0; i < points.length; i++) utc(i)];

  group('wall clock', () {
    test('the instant read at the offset, as fields', () {
      final wall = wallClock(DateTime.utc(2026, 5, 1, 22, 30), offset);
      expect(
        (wall.year, wall.month, wall.day, wall.hour, wall.minute),
        (2026, 5, 2, 0, 30),
      );
    });

    test('the days a recording touches', () {
      final days = recordingDays(
        DateTime.utc(2026, 5, 1, 21),
        DateTime.utc(2026, 5, 1, 23),
        offset,
      )!;
      expect(days.from, DateTime(2026, 5, 1));
      expect(days.to, DateTime(2026, 5, 2));
    });
  });

  group('another day', () {
    final may1 = (from: DateTime(2026, 5, 1), to: DateTime(2026, 5, 1));

    test('a recording on the entries\' day is not warned about', () {
      expect(recordingOnOtherDays(may1, [leg(1)]), isFalse);
    });

    test('one from another day is', () {
      expect(
        recordingOnOtherDays(may1, [leg(1, date: DateTime(2026, 6, 14))]),
        isTrue,
      );
    });

    test('the morning a night train arrives is one of its days', () {
      final morning = (from: DateTime(2026, 5, 2), to: DateTime(2026, 5, 2));
      expect(
        recordingOnOtherDays(morning, [leg(1, start: 1300, endDayOffset: 1)]),
        isFalse,
      );
    });
  });

  group('leg instants', () {
    test('standing still belongs to neither leg', () {
      final instants = legInstants(points, times, [6]);

      // Left the start when the walk began, not when the recording did.
      expect(instants[0].departed, utc(2));
      // Arrived at the change when it first got there…
      expect(instants[0].arrived, utc(5));
      // …and the next leg left when the change was over.
      expect(instants[1].departed, utc(7));
      expect(instants[1].arrived, utc(9));
    });

    test('a stretch that never moves is read at its raw ends', () {
      // The two searches would cross and arrive before leaving.
      final still = [at(0), at(0), at(0)];
      final instants = legInstants(still, [utc(0), utc(1), utc(2)], const []);
      expect(instants.single.departed, utc(0));
      expect(instants.single.arrived, utc(2));
    });

    test('a point without a time gives no time', () {
      final instants = legInstants([at(0), at(1)], [null, utc(1)], const []);
      expect(instants.single.departed, isNull);
      expect(instants.single.arrived, utc(1));
    });
  });

  group('proposals', () {
    List<ActualTimeProposal> propose(
      List<ItineraryItem> legs, [
      List<int> cuts = const [6],
    ]) => actualTimeProposals(legs, legInstants(points, times, cuts), offset);

    test('empty ends are offered, ticked', () {
      final proposals = propose([leg(1), leg(2)]);
      expect(
        [for (final p in proposals) (p.item.id, p.end, p.minutes)],
        [
          (1, TrackEnd.from, 8 * 60 + 2),
          (1, TrackEnd.to, 8 * 60 + 5),
          (2, TrackEnd.from, 8 * 60 + 7),
          (2, TrackEnd.to, 8 * 60 + 9),
        ],
      );
      expect(proposals.every((p) => p.selectedByDefault), isTrue);
    });

    test('an entered time that differs is offered, unticked', () {
      final proposals = propose([leg(1, actualStart: 7 * 60 + 50), leg(2)]);
      final first = proposals.first;
      expect(first.end, TrackEnd.from);
      expect(first.existing, 7 * 60 + 50);
      expect(first.selectedByDefault, isFalse);
    });

    test('an entered time that agrees is not asked about', () {
      final proposals = propose([leg(1, actualStart: 8 * 60 + 1), leg(2)]);
      expect(
        proposals.where((p) => p.item.id == 1 && p.end == TrackEnd.from),
        isEmpty,
      );
    });

    test('a recording from another day writes nothing', () {
      // Stored as a time of day, it would read as that time on the wrong day.
      final proposals = propose([leg(1, date: DateTime(2026, 5, 2)), leg(2)]);
      expect(proposals.where((p) => p.item.id == 1), isEmpty);
      expect(proposals.where((p) => p.item.id == 2), hasLength(2));
    });

    test('a departure past midnight is read against its plan', () {
      // Planned 23:55, left at 00:02 the next morning: seven minutes late.
      final proposals = actualTimeProposals(
        [leg(1, start: 23 * 60 + 55)],
        [(departed: DateTime.utc(2026, 5, 1, 22, 2), arrived: null)],
        offset,
      );
      expect(proposals.single.minutes, 2);
    });

    test('an arrival before an entered departure is not offered', () {
      final proposals = propose([leg(1, actualStart: 9 * 60), leg(2)]);
      expect(
        proposals.where((p) => p.item.id == 1 && p.end == TrackEnd.to),
        isEmpty,
      );
    });

    test('seconds round to the nearer minute', () {
      final proposals = actualTimeProposals(
        [leg(1)],
        [(departed: utc(2, 30), arrived: utc(5, 29))],
        offset,
      );
      expect([for (final p in proposals) p.minutes], [8 * 60 + 3, 8 * 60 + 5]);
    });
  });
}
