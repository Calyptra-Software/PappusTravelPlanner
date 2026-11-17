import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

/// The vendored Android plugin rebuilds every position it reads. It has to
/// carry over what the platform said it measured, or every position says it
/// has no height and a recording keeps none (the fifth edit in
/// `third_party/geolocator_android/README.md`).
void main() {
  Map<String, Object> fix({double? altitude}) => {
    'latitude': 47.0,
    'longitude': 11.0,
    'timestamp': 1777636800000,
    'accuracy': 4.0,
    'altitude': ?altitude,
    'is_mocked': false,
  };

  test('a reported height says it is one', () {
    final position = AndroidPosition.fromMap(fix(altitude: 1848.5));

    expect(position.hasAltitude, isTrue);
    expect(position.altitude, 1848.5);
    expect(position.hasAccuracy, isTrue);
  });

  test('no height reported is none, not sea level', () {
    final position = AndroidPosition.fromMap(fix());

    expect(position.hasAltitude, isFalse);
    expect(position.altitude, 0);
  });
}
