import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/app_info.dart';

/// Which build this is, read off the one thing that makes it that build.
///
/// The side-by-side build is the application id plus a suffix, so the answer is
/// derived from the id rather than carried as a switch beside it — a switch
/// could be set when the Gradle property was not, and the app would then be
/// wrong about itself in the field a bug report quotes.
void main() {
  group('isCiBuild', () {
    test('recognises the side-by-side application id', () {
      expect(isCiBuild('dev.calyptra.pappus$kCiApplicationIdSuffix'), isTrue);
    });

    test('leaves the released application id alone', () {
      expect(isCiBuild('dev.calyptra.pappus'), isFalse);
    });

    test('is not fooled by the suffix appearing elsewhere', () {
      expect(isCiBuild('dev.calyptra.pappus.cinema'), isFalse);
      expect(isCiBuild('ci.calyptra.pappus'), isFalse);
    });

    test('says no for the other platforms, which have no such build', () {
      expect(isCiBuild('dev.calyptra.pappus.linux'), isFalse);
      expect(isCiBuild(''), isFalse);
    });
  });
}
