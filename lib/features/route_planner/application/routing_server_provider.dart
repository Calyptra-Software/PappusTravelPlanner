import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/server_setting.dart';

export '../../../core/settings/server_setting.dart';
import '../data/brouter_client.dart';
import '../data/ski/overpass_client.dart';
import '../data/terrain_tiles.dart';

/// The BRouter server the route planner asks, remembered across launches.
///
/// [kBrouterBaseUrl] unless the user set another in settings: their own
/// server, so that no request goes to brouter.de, or another public one when
/// that one is slow. A setting of the device like the map style, so it stays
/// out of the database and out of a `.tpt`.
final routingServerProvider = NotifierProvider<ServerSettingController, Uri>(
  () => ServerSettingController(
    key: 'route_planner_server',
    fallback: kBrouterBaseUrl,
    defaultPath: kBrouterPath,
  ),
);

/// The Overpass server the ski router loads pistes and lifts from,
/// remembered across launches: [kOverpassUrl] unless the user set another,
/// for the reasons [routingServerProvider] gives.
final overpassServerProvider = NotifierProvider<ServerSettingController, Uri>(
  () => ServerSettingController(
    key: 'ski_overpass_server',
    fallback: kOverpassUrl,
    defaultPath: kOverpassPath,
  ),
);

/// The server ski runs take their heights from, remembered across launches:
/// [kTerrainTilesUrl] unless the user set another (a mirror, or their own copy
/// of the tiles), for the reasons [routingServerProvider] gives.
final terrainServerProvider = NotifierProvider<ServerSettingController, Uri>(
  () => ServerSettingController(
    key: 'ski_terrain_server',
    fallback: kTerrainTilesUrl,
    defaultPath: '',
  ),
);

/// The path a bare BRouter server answers routing requests under.
const String kBrouterPath = '/brouter';

/// The path a bare Overpass server answers queries under.
const String kOverpassPath = '/api/interpreter';

/// [parseServer] for a BRouter server.
Uri? parseRoutingServer(String text) =>
    parseServer(text, defaultPath: kBrouterPath);
