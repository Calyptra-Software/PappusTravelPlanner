import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:travelplanner/features/map/elevation.dart';
import 'package:travelplanner/features/map/widgets/elevation_profile_chart.dart';

void main() {
  LaidProfile profile(List<double> heights) => layProfiles([
    (
      profile: elevationProfile([
        for (var i = 0; i < heights.length; i++) LatLng(47 + i * 0.01, 11),
      ], heights),
      meters: 1000.0 * (heights.length - 1),
    ),
  ]);

  Widget chart(LaidProfile laid, ValueChanged<ProfilePoint?> onScrub) =>
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: ElevationProfileChart(
                profile: laid,
                color: Colors.teal,
                onScrub: onScrub,
              ),
            ),
          ),
        ),
      );

  testWidgets('a cursor on one profile is taken away when another comes', (
    tester,
  ) async {
    final told = <ProfilePoint?>[];
    await tester.pumpWidget(chart(profile([500, 600, 550]), told.add));
    final plot = find.descendant(
      of: find.byType(ElevationProfileChart),
      matching: find.byType(GestureDetector),
    );

    final gesture = await tester.startGesture(tester.getCenter(plot));
    await tester.pump();
    expect(told.last, isNotNull);
    expect(find.byKey(const ValueKey('profile-cursor')), findsOneWidget);

    // The tour changed under the finger: a new profile.
    await tester.pumpWidget(chart(profile([700, 650]), told.add));
    expect(told.last, isNull);
    expect(find.byKey(const ValueKey('profile-cursor')), findsNothing);
    await gesture.up();
  });

  testWidgets('a level profile is drawn half way up, not divided by zero', (
    tester,
  ) async {
    await tester.pumpWidget(chart(profile([650, 650, 650]), (_) {}));

    expect(tester.takeException(), isNull);
    // One height, written as both the top and the bottom of the scale.
    expect(find.text('650 m'), findsNWidgets(2));
  });
}
