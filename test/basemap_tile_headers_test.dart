import 'package:flutter_test/flutter_test.dart';
import 'package:travelplanner/core/app_info.dart';
import 'package:travelplanner/features/map/widgets/map_overlays.dart';

void main() {
  // The OpenStreetMap tile policy asks an app to name itself, so a native
  // build sends the same User-Agent the router gets.
  test('native tile requests name the app and its version', () {
    expect(basemapTileHeaders('9.9.9+42', web: false), {
      'User-Agent': buildUserAgent('9.9.9+42'),
    });
  });

  // In Firefox a page-set User-Agent turns every tile request into a CORS
  // preflight that tile.openstreetmap.org refuses, which left the web map
  // grey. The browser's own header and the Referer are what the policy takes
  // there.
  test('web tile requests carry no headers of their own', () {
    expect(basemapTileHeaders('9.9.9+42', web: true), isEmpty);
  });
}
