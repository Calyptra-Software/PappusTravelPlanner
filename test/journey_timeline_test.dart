import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/features/transport_search/presentation/journey_timeline.dart';

/// The line down a leg's card: its dots and the vehicle placed between them.
/// What the journey screen makes of it is tested there; this is the layout.
void main() {
  /// Three rows 30 high: a stop, a row without a dot, and a stop.
  Widget timeline({TimelineSpot? vehicle, Color color = Colors.blue}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            child: JourneyTimeline(
              color: color,
              outsideColor: Colors.grey,
              surface: Colors.white,
              vehicle: vehicle,
              children: [
                const TimelineRow(
                  dot: TimelineDot.end,
                  child: SizedBox(key: Key('a'), height: 30),
                ),
                const TimelineRow(child: SizedBox(key: Key('b'), height: 30)),
                const TimelineRow(
                  dot: TimelineDot.skipped,
                  outside: true,
                  child: SizedBox(key: Key('c'), height: 30),
                ),
                if (vehicle != null)
                  const TimelineVehicle(
                    child: SizedBox(key: Key('v'), width: 10, height: 10),
                  ),
              ],
            ),
          ),
        ),
      );

  testWidgets('lays the rows out beside the line, one under the other', (
    tester,
  ) async {
    await tester.pumpWidget(timeline());

    expect(
      tester.getTopLeft(find.byKey(const Key('a'))),
      Offset.zero + const Offset(kTimelineGutter, 0),
    );
    expect(tester.getTopLeft(find.byKey(const Key('c'))).dy, 60);
    expect(tester.getSize(find.byType(JourneyTimeline)), const Size(200, 90));
  });

  testWidgets('puts the vehicle between two dots by its fraction', (
    tester,
  ) async {
    // The dots sit 11 below their rows' tops: at 11 and 71.
    await tester.pumpWidget(timeline(vehicle: const TimelineSpot(0, 1, 0.5)));
    expect(tester.getCenter(find.byKey(const Key('v'))).dy, 41);

    await tester.pumpWidget(timeline(vehicle: const TimelineSpot.at(1)));
    expect(tester.getCenter(find.byKey(const Key('v'))).dy, 71);
  });

  testWidgets('keeps a vehicle out of sight at a dot it does not have', (
    tester,
  ) async {
    await tester.pumpWidget(timeline(vehicle: const TimelineSpot(0, 5, 0.5)));
    expect(tester.getCenter(find.byKey(const Key('v'))).dx, lessThan(0));
  });

  testWidgets('answers for its size without being laid out', (tester) async {
    await tester.pumpWidget(timeline(color: Colors.red));
    final box = tester.renderObject<RenderJourneyTimeline>(
      find.byType(JourneyTimeline),
    );

    expect(box.getMinIntrinsicWidth(100), kTimelineGutter);
    expect(box.getMaxIntrinsicWidth(100), kTimelineGutter);
    expect(box.getMinIntrinsicHeight(200), 90);
    expect(box.getMaxIntrinsicHeight(200), 90);
    expect(
      box.getDryLayout(const BoxConstraints(maxWidth: 200)),
      const Size(200, 90),
    );
  });

  test('a spot is its dots and its fraction', () {
    expect(const TimelineSpot.at(2), const TimelineSpot(2, 2));
    expect(
      const TimelineSpot(0, 1, 0.5).hashCode,
      const TimelineSpot(0, 1, 0.5).hashCode,
    );
    expect(const TimelineSpot(0, 1, 0.5), isNot(const TimelineSpot(0, 1)));
  });
}
