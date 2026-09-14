import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/database/database_location_io.dart';

/// Which file a build opens when nobody has chosen one.
///
/// On a desktop the documents directory is the user's, shared by every build,
/// so the side-by-side CI build must not open the released app's database
/// there. On a phone the directory already belongs to the application id.
void main() {
  test('the released build keeps its name everywhere', () {
    for (final shared in [true, false]) {
      expect(
        defaultDatabaseFileName(ciBuild: false, sharedDirectory: shared),
        kDatabaseFileName,
      );
    }
  });

  test('the CI build takes a name of its own in a shared directory', () {
    expect(
      defaultDatabaseFileName(ciBuild: true, sharedDirectory: true),
      kCiDatabaseFileName,
    );
    expect(kCiDatabaseFileName, isNot(kDatabaseFileName));
  });

  test('the CI build keeps the name where the directory is its own', () {
    // Renaming it on Android would only hide a tester's existing data.
    expect(
      defaultDatabaseFileName(ciBuild: true, sharedDirectory: false),
      kDatabaseFileName,
    );
  });
}
