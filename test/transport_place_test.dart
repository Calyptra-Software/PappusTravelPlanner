import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/features/transport_search/domain/transport_place.dart';

/// How a picked place is addressed in a journey query. Only a stop has an id
/// the router accepts; an address or point of interest carries the geocoder's
/// own identifier, which the routing endpoint rejects with a 404 — so those
/// travel as coordinates instead.
void main() {
  test('a stop is addressed by its id', () {
    const stop = TransportPlace(
      id: 'de-DELFI_de:02000:10950',
      name: 'Hamburg Hbf',
      kind: PlaceKind.stop,
      lat: 53.5527,
      lon: 10.0069,
    );

    expect(stop.queryId, 'de-DELFI_de:02000:10950');
  });

  test('an address or place is addressed by coordinate', () {
    const poi = TransportPlace(
      id: 'way/[142944431]',
      name: 'Hamburg Rathaus',
      kind: PlaceKind.place,
      lat: 53.5499,
      lon: 9.9927,
    );
    const address = TransportPlace(
      id: 'way/[1]',
      name: 'Rathausmarkt 1',
      kind: PlaceKind.address,
      lat: 53.55,
      lon: 9.99,
    );

    expect(poi.queryId, '53.5499,9.9927');
    expect(address.queryId, '53.55,9.99');
  });

  test('without coordinates there is nothing better than the id', () {
    const bare = TransportPlace(
      id: 'way/[2]',
      name: 'Somewhere',
      kind: PlaceKind.other,
    );

    expect(bare.queryId, 'way/[2]');
  });
}
