import 'package:cupertino_ui/cupertino_ui.dart'
    show GlobalCupertinoLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/data/database/tables.dart';
import 'package:travelplanner/data/database/track_points.dart';
import 'package:travelplanner/features/map/track_summary.dart';
import 'package:travelplanner/features/map/widgets/elevation_profile_chart.dart';
import 'package:travelplanner/features/map/widgets/track_row.dart';
import 'package:travelplanner/l10n/app_localizations.dart';

/// What one stored line's row says about it.
void main() {
  TrackSummary summary(TrackSource source, {List<double>? heights}) =>
      summarizeTracks([
        Track(
          id: 1,
          itemId: 7,
          source: source,
          name: null,
          points: encodeTrackPoints(const [
            LatLng(47, 11),
            LatLng(47.01, 11),
            LatLng(47.02, 11),
          ]),
          elevations: heights == null ? null : encodeTrackElevations(heights),
          display: TrackDisplay.auto,
          sortOrder: 0,
        ),
      ]).single;

  Future<void> pump(WidgetTester tester, TrackSummary track) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: TrackRow(track: track)),
        ),
      );

  testWidgets('a line drawn by hand says so, with its own icon', (
    tester,
  ) async {
    await pump(tester, summary(TrackSource.drawn));

    expect(find.textContaining('Drawn by hand'), findsOneWidget);
    expect(find.byIcon(Icons.gesture), findsOneWidget);
  });

  testWidgets('a line with heights shows its climb and its profile', (
    tester,
  ) async {
    await pump(tester, summary(TrackSource.routed, heights: [500, 620, 560]));

    expect(find.textContaining('↑ 120 m ↓ 60 m'), findsOneWidget);
    expect(find.byType(ElevationProfileChart), findsOneWidget);
  });

  testWidgets('a line without heights shows neither', (tester) async {
    await pump(tester, summary(TrackSource.recorded));

    expect(find.textContaining('↑'), findsNothing);
    expect(find.byType(ElevationProfileChart), findsNothing);
  });
}
