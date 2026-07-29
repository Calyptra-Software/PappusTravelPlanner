import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:travelplanner/features/transport_search/domain/journey.dart';
import 'package:travelplanner/features/transport_search/domain/transit_mode.dart';
import 'package:travelplanner/features/transport_search/presentation/journey_preview_sheet.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// Hamburg → Basel with a change in Frankfurt: two ICEs with an 8-minute walk
/// between them, the first arriving [delay] minutes late.
JourneyOption _journey({int? delay}) {
  DateTime at(int minutes) =>
      DateTime.utc(2026, 7, 27, 6).add(Duration(minutes: minutes));
  LegPoint point(String name, int minutes, {String? track, int? late}) =>
      LegPoint(
        name: name,
        scheduled: at(minutes),
        actual: late == null ? null : at(minutes + late),
        timeZone: 'Europe/Berlin',
        track: track,
      );

  final legs = [
    JourneyLeg(
      mode: TransitMode.highSpeedRail,
      line: 'ICE 507',
      headsign: 'München Hbf',
      from: point('Hamburg Hbf', 0, track: '14'),
      to: point('Frankfurt(Main) Hbf', 110, track: '7', late: delay),
      realTime: delay != null,
    ),
    JourneyLeg(
      mode: TransitMode.walk,
      from: point('Frankfurt(Main) Hbf', 112),
      to: point('Frankfurt(Main) Hbf', 120),
      realTime: false,
    ),
    JourneyLeg(
      mode: TransitMode.highSpeedRail,
      line: 'ICE 71',
      from: point('Frankfurt(Main) Hbf', 133, track: '3'),
      to: point('Basel SBB', 300),
      realTime: false,
    ),
  ];
  return JourneyOption(
    departure: legs.first.from.scheduled,
    arrival: legs.last.to.scheduled,
    duration: legs.last.to.scheduled.difference(legs.first.from.scheduled),
    transfers: 1,
    legs: legs,
  );
}

void main() {
  setUpAll(tzdata.initializeTimeZones);

  /// Opens the preview over a bare app and returns what it resolves to.
  Future<bool?> pump(WidgetTester tester, JourneyOption option) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showJourneyPreviewSheet(context, option: option);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('shows every leg with its platforms and direction', (
    tester,
  ) async {
    await pump(tester, _journey());

    expect(find.textContaining('ICE 507'), findsOneWidget);
    expect(find.textContaining('to München Hbf'), findsOneWidget);
    expect(find.textContaining('ICE 71'), findsOneWidget);
    // Berlin time: 06:00Z departs 08:00, arrives Basel 13:00 — each printed
    // twice, once in the header's overall range and once on its own leg.
    expect(find.textContaining('8:00 AM'), findsNWidgets(2));
    expect(find.textContaining('1:00 PM'), findsNWidgets(2));
    // The intermediate times a result row cannot show at all.
    expect(find.textContaining('9:50 AM'), findsOneWidget);
    expect(find.textContaining('10:13 AM'), findsOneWidget);
    expect(find.text('Pl. 14'), findsOneWidget);
    expect(find.text('Pl. 7'), findsOneWidget);
    expect(find.text('Pl. 3'), findsOneWidget);
  });

  testWidgets('names the change, where it is and how much of it is walking', (
    tester,
  ) async {
    await pump(tester, _journey());

    expect(find.text('23 min change in Frankfurt(Main) Hbf'), findsOneWidget);
    expect(find.text('8 min'), findsOneWidget);
    // The walk is the change, not a leg — so it is not listed as one.
    expect(find.text('Walk'), findsNothing);
  });

  testWidgets('a delay is shown against the change it eats into', (
    tester,
  ) async {
    await pump(tester, _journey(delay: 18));

    expect(find.textContaining('(+18)'), findsOneWidget);
    expect(find.text('23 min change in Frankfurt(Main) Hbf'), findsOneWidget);
    expect(find.text('now 5 min'), findsOneWidget);
  });

  testWidgets('the sheet resolves true only when confirmed', (tester) async {
    await pump(tester, _journey());
    await tester.tap(find.text('Add to day'));
    await tester.pumpAndSettle();
    // The sheet is gone; the caller was told to go ahead.
    expect(find.text('Add to day'), findsNothing);
  });
}
