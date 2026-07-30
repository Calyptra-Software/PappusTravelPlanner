import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';
import 'package:travelplanner/features/transport_search/journey_preview.dart';
import 'package:travelplanner/features/transport_search/journey_view.dart';

/// A leg from [fromName] at [from] to [toName] at [to], given as minutes past
/// 08:00 UTC so a journey reads as a small timetable.
JourneyLeg _leg({
  required TransitMode mode,
  required String fromName,
  required int from,
  required String toName,
  required int to,
  String? line,
  int? fromDelay,
  int? toDelay,
}) {
  DateTime at(int minutes) =>
      DateTime.utc(2026, 7, 27, 8).add(Duration(minutes: minutes));
  return JourneyLeg(
    mode: mode,
    from: LegPoint(
      name: fromName,
      scheduled: at(from),
      actual: fromDelay == null ? null : at(from + fromDelay),
      timeZone: 'Europe/Berlin',
    ),
    to: LegPoint(
      name: toName,
      scheduled: at(to),
      actual: toDelay == null ? null : at(to + toDelay),
      timeZone: 'Europe/Berlin',
    ),
    realTime: fromDelay != null || toDelay != null,
    line: line,
  );
}

JourneyOption _option(List<JourneyLeg> legs) => JourneyOption(
  departure: legs.first.from.scheduled,
  arrival: legs.last.to.scheduled,
  duration: legs.last.to.scheduled.difference(legs.first.from.scheduled),
  transfers: legs.where((l) => !l.mode.isOwnSteam).length - 1,
  legs: legs,
);

/// The rows a routed journey reads as — the search's way into the shared
/// preview.
List<PreviewRow> _preview(JourneyOption option) =>
    journeyPreview(journeyViewFromOption(option));

void main() {
  setUpAll(tzdata.initializeTimeZones);

  test('a direct ride is one leg and no change', () {
    final rows = _preview(
      _option([
        _leg(
          mode: TransitMode.highSpeedRail,
          line: 'ICE 1',
          fromName: 'Hamburg Hbf',
          from: 0,
          toName: 'Berlin Hbf',
          to: 110,
        ),
      ]),
    );

    expect(rows, hasLength(1));
    expect((rows.single as LegRow).leg.line, 'ICE 1');
  });

  test('the walk between two trains becomes the change, not a leg', () {
    final rows = _preview(
      _option([
        _leg(
          mode: TransitMode.highSpeedRail,
          line: 'ICE 1',
          fromName: 'Hamburg Hbf',
          from: 0,
          toName: 'Frankfurt Hbf',
          to: 110,
        ),
        _leg(
          mode: TransitMode.walk,
          fromName: 'Frankfurt Hbf',
          from: 112,
          toName: 'Frankfurt Hbf',
          to: 120,
        ),
        _leg(
          mode: TransitMode.highSpeedRail,
          line: 'ICE 71',
          fromName: 'Frankfurt Hbf',
          from: 133,
          toName: 'Basel SBB',
          to: 300,
        ),
      ]),
    );

    expect(rows.map((r) => r.runtimeType).toList(), [
      LegRow,
      ChangeRow,
      LegRow,
    ]);
    final change = rows[1] as ChangeRow;
    // The whole gap between the two trains — waiting and walking alike.
    expect(change.minutes, 23);
    expect(change.place, 'Frankfurt Hbf');
    expect(change.toPlace, isNull);
    expect(change.ownSteamMinutes, 8);
    expect((change.ownSteamMode as RoutedMode).mode, TransitMode.walk);
    // Nothing is running late, so there is no second figure to report.
    expect(change.actualMinutes, isNull);
  });

  test('a change that walks to another station names both', () {
    final rows = _preview(
      _option([
        _leg(
          mode: TransitMode.regionalRail,
          line: 'RB 81',
          fromName: 'Hamburg Hbf',
          from: 0,
          toName: 'Hamburg Hbf',
          to: 20,
        ),
        _leg(
          mode: TransitMode.walk,
          fromName: 'Hamburg Hbf',
          from: 20,
          toName: 'Hamburg Dammtor',
          to: 35,
        ),
        _leg(
          mode: TransitMode.regionalRail,
          line: 'RE 7',
          fromName: 'Hamburg Dammtor',
          from: 40,
          toName: 'Kiel Hbf',
          to: 120,
        ),
      ]),
    );

    final change = rows[1] as ChangeRow;
    expect(change.place, 'Hamburg Hbf');
    expect(change.toPlace, 'Hamburg Dammtor');
    expect(change.minutes, 20);
    expect(change.ownSteamMinutes, 15);
  });

  test('a delay on the arriving train shortens the change', () {
    final rows = _preview(
      _option([
        _leg(
          mode: TransitMode.highSpeedRail,
          line: 'ICE 1',
          fromName: 'Hamburg Hbf',
          from: 0,
          toName: 'Frankfurt Hbf',
          to: 110,
          toDelay: 18,
        ),
        _leg(
          mode: TransitMode.highSpeedRail,
          line: 'ICE 71',
          fromName: 'Frankfurt Hbf',
          from: 133,
          toName: 'Basel SBB',
          to: 300,
        ),
      ]),
    );

    final change = rows[1] as ChangeRow;
    expect(change.minutes, 23);
    expect(change.actualMinutes, 5);
  });

  test('a change running exactly to plan reports no live figure', () {
    final rows = _preview(
      _option([
        _leg(
          mode: TransitMode.highSpeedRail,
          line: 'ICE 1',
          fromName: 'Hamburg Hbf',
          from: 0,
          toName: 'Frankfurt Hbf',
          to: 110,
          toDelay: 0,
        ),
        _leg(
          mode: TransitMode.highSpeedRail,
          line: 'ICE 71',
          fromName: 'Frankfurt Hbf',
          from: 133,
          toName: 'Basel SBB',
          to: 300,
          fromDelay: 0,
        ),
      ]),
    );

    expect((rows[1] as ChangeRow).actualMinutes, isNull);
  });

  test('walks at either end stay legs of their own', () {
    final rows = _preview(
      _option([
        _leg(
          mode: TransitMode.walk,
          fromName: 'Hotel',
          from: 0,
          toName: 'Hamburg Hbf',
          to: 10,
        ),
        _leg(
          mode: TransitMode.highSpeedRail,
          line: 'ICE 1',
          fromName: 'Hamburg Hbf',
          from: 15,
          toName: 'Berlin Hbf',
          to: 125,
        ),
        _leg(
          mode: TransitMode.walk,
          fromName: 'Berlin Hbf',
          from: 125,
          toName: 'Museum',
          to: 140,
        ),
      ]),
    );

    expect(rows.map((r) => r.runtimeType).toList(), [LegRow, LegRow, LegRow]);
    expect((rows.first as LegRow).leg.to.name, 'Hamburg Hbf');
    expect((rows.last as LegRow).leg.to.name, 'Museum');
  });

  test('an all-walking direct connection is a single leg', () {
    final rows = _preview(
      _option([
        _leg(
          mode: TransitMode.walk,
          fromName: 'Hotel',
          from: 0,
          toName: 'Rathaus',
          to: 28,
        ),
      ]),
    );

    expect(rows, hasLength(1));
    expect(
      ((rows.single as LegRow).leg.mode as RoutedMode).mode,
      TransitMode.walk,
    );
  });

  test('a change with no walk through it is pure waiting', () {
    final rows = _preview(
      _option([
        _leg(
          mode: TransitMode.regionalRail,
          line: 'RE 1',
          fromName: 'A',
          from: 0,
          toName: 'B',
          to: 30,
        ),
        _leg(
          mode: TransitMode.bus,
          line: '112',
          fromName: 'B',
          from: 42,
          toName: 'C',
          to: 70,
        ),
      ]),
    );

    final change = rows[1] as ChangeRow;
    expect(change.minutes, 12);
    expect(change.ownSteamMinutes, isNull);
    expect(change.ownSteamMode, isNull);
  });
}
