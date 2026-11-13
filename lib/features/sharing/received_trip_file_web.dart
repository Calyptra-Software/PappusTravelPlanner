import 'dart:typed_data';

/// The web is never opened with a trip file, so there is nothing to take.
Future<Uint8List> takeReceivedTrip(String path) async =>
    throw UnsupportedError('A browser does not receive trip files.');
