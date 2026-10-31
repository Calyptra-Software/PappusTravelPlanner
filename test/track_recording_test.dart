import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:travelplanner/data/database/app_database.dart';
import 'package:travelplanner/features/map/map_features.dart' show lineLength;
import 'package:travelplanner/features/map/track_recording.dart';

/// Which readings the recorder keeps, and what the kept ones become.
void main() {
  final t0 = DateTime.utc(2026, 5, 1, 12);

  // 0.0001° of latitude is about 11.1 m.
  FixReading reading(double north, {double accuracy = 4, int seconds = 0}) =>
      FixReading(
        position: LatLng(53.5 + north, 9.9),
        accuracyMeters: accuracy,
        at: t0.add(Duration(seconds: seconds)),
      );

  group('acceptFix', () {
    test('the first fix of a stretch only has to be sure enough', () {
      expect(acceptFix(null, reading(0)), isTrue);
      expect(acceptFix(null, reading(0, accuracy: 50)), isTrue);
      expect(acceptFix(null, reading(0, accuracy: 51)), isFalse);
    });

    test('a radius with no finite figure counts as none', () {
      expect(acceptFix(null, reading(0, accuracy: double.nan)), isFalse);
      expect(acceptFix(null, reading(0, accuracy: double.infinity)), isFalse);
    });

    test('a fix no later than the last one is not kept', () {
      final last = reading(0, seconds: 10);
      expect(acceptFix(last, reading(0.001, seconds: 10)), isFalse);
      expect(acceptFix(last, reading(0.001, seconds: 9)), isFalse);
      expect(acceptFix(last, reading(0.001, seconds: 11)), isTrue);
    });

    test('a sharp fix has to move at least the floor', () {
      final last = reading(0);
      // About 3 m, and the receiver claims 4: the floor decides.
      expect(acceptFix(last, reading(0.000027, seconds: 1)), isFalse);
      // About 11 m.
      expect(acceptFix(last, reading(0.0001, seconds: 1)), isTrue);
    });

    test('a vague fix has to move further than its own radius', () {
      final last = reading(0);
      // About 11 m, inside a 20 m radius: the fix wandering, not a step.
      expect(
        acceptFix(last, reading(0.0001, accuracy: 20, seconds: 1)),
        isFalse,
      );
      // About 22 m.
      expect(
        acceptFix(last, reading(0.0002, accuracy: 20, seconds: 1)),
        isTrue,
      );
    });

    test('a vague fix is not kept however far it moved', () {
      expect(
        acceptFix(reading(0), reading(0.01, accuracy: 80, seconds: 1)),
        isFalse,
      );
    });
  });

  group('recordedLines', () {
    var nextId = 0;
    RecordingFix stored(int segment, double north, int seconds) => RecordingFix(
      id: ++nextId,
      recordingId: 1,
      segment: segment,
      lat: 53.5 + north,
      lon: 9.9,
      recordedAt: t0.add(Duration(seconds: seconds)).millisecondsSinceEpoch,
    );

    test('one line per segment, its times parallel and in UTC', () {
      final lines = recordedLines([
        stored(0, 0, 0),
        stored(0, 0.001, 10),
        stored(1, 0.010, 600),
        stored(1, 0.011, 610),
        stored(1, 0.012, 620),
      ]);

      expect(lines, hasLength(2), reason: 'a pause is never joined');
      expect(lines[0].points, [
        const LatLng(53.5, 9.9),
        const LatLng(53.501, 9.9),
      ]);
      expect(lines[1].points, hasLength(3));
      expect(lines[1].times, hasLength(3));
      expect(lines[0].times.first, t0);
      expect(lines[0].times.first.isUtc, isTrue);
      expect(lines[1].times.last, t0.add(const Duration(seconds: 620)));
    });

    test('a segment of one fix is not a line', () {
      final lines = recordedLines([
        stored(0, 0, 0),
        stored(1, 0.010, 600),
        stored(1, 0.011, 610),
        stored(2, 0.020, 1200),
      ]);
      expect(lines, hasLength(1));
      expect(lines.single.points.first, const LatLng(53.51, 9.9));
    });

    test('a fix no later than the one before is dropped, not the line', () {
      final lines = recordedLines([
        stored(0, 0, 0),
        stored(0, 0.001, 10),
        stored(0, 0.002, 5),
        stored(0, 0.003, 20),
      ]);
      expect(lines.single.points, [
        const LatLng(53.5, 9.9),
        const LatLng(53.501, 9.9),
        const LatLng(53.503, 9.9),
      ]);
      final times = lines.single.times;
      for (var i = 1; i < times.length; i++) {
        expect(times[i].isAfter(times[i - 1]), isTrue);
      }
    });

    test('nothing recorded is no line', () {
      expect(recordedLines(const []), isEmpty);
    });
  });

  test('the distance never runs across the gap between two lines', () {
    final a = [const LatLng(53.5, 9.9), const LatLng(53.501, 9.9)];
    final b = [const LatLng(53.6, 9.9), const LatLng(53.601, 9.9)];
    final lines = <RecordedLine>[
      (points: a, times: [t0, t0]),
      (points: b, times: [t0, t0]),
    ];
    expect(
      recordedDistanceMeters(lines),
      closeTo(lineLength(a) + lineLength(b), 1e-9),
    );
    expect(recordedDistanceMeters(lines), lessThan(300));
  });
}
