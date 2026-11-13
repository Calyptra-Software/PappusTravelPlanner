import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/features/sharing/received_trip_file.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('received_trip'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('returns the copy\'s bytes and deletes it', () async {
    final copy = File('${dir.path}/trip.tpt')
      ..writeAsBytesSync(Uint8List.fromList([1, 2, 3]));

    expect(await takeReceivedTrip(copy.path), [1, 2, 3]);
    expect(copy.existsSync(), isFalse);
  });

  test('a missing copy fails the read', () async {
    await expectLater(
      takeReceivedTrip('${dir.path}/gone.tpt'),
      throwsA(isA<FileSystemException>()),
    );
  });
}
