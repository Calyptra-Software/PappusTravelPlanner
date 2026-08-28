import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/format/distance_format.dart';

/// How a line's length is written where it has to tell two lines apart.
void main() {
  test('below a kilometre it is whole metres', () {
    expect(formatDistance(0), '0 m');
    expect(formatDistance(819.6), '820 m');
    expect(formatDistance(999.4), '999 m');
  });

  test('a short line keeps the decimal that distinguishes it', () {
    // The walk and the bus that followed it differ by a few hundred metres.
    expect(formatDistance(1000), '1 km');
    expect(formatDistance(4249), '4.2 km');
    expect(formatDistance(4260), '4.3 km');
  });

  test('a trailing .0 is dropped rather than printed', () {
    expect(formatDistance(2000), '2 km');
    expect(formatDistance(2049), '2 km');
  });

  test('past ten kilometres the decimal says nothing, so it goes', () {
    expect(formatDistance(10000), '10 km');
    expect(formatDistance(128400), '128 km');
  });
}
