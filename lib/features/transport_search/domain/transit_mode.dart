/// A provider-agnostic mode of transport for a routed leg.
///
/// This is the vocabulary the connection-search *domain* speaks, deliberately
/// kept apart from both the routing service's own strings (a backend detail —
/// see [transitModeFromMotis]) and the app's user-managed [TransportModes]
/// table (a leg imported into the itinerary is mapped onto a mode row later, in
/// the Phase-3 mapper). Values are granular on purpose — night vs. high-speed
/// vs. regional rail are distinct — so that later mapping (and a future
/// user-defined override) has the resolution to work with.
enum TransitMode {
  walk,
  bike,
  car,
  bus,
  coach,
  tram,
  subway,
  suburban,
  monorail,
  rail,
  highSpeedRail,
  longDistanceRail,
  nightRail,
  regionalRail,
  regionalFastRail,
  ferry,
  funicular,
  gondola,
  aerialLift,

  /// Anything the routing service reported that we do not model (or did not
  /// recognise). Kept rather than dropped so a leg still imports.
  other,
}

extension TransitModeKind on TransitMode {
  /// Whether this leg is covered under the traveller's own steam — on foot, by
  /// bike, by car — rather than by boarding a scheduled service.
  ///
  /// It is the distinction a **change** is defined against: the walk from one
  /// platform to the next is part of the change, not a leg of the journey, so
  /// the preview folds it into the change and counts changes between the
  /// services either side of it.
  bool get isOwnSteam =>
      this == TransitMode.walk ||
      this == TransitMode.bike ||
      this == TransitMode.car;
}

/// Maps a MOTIS `Mode` string (as seen on a leg) onto a [TransitMode].
///
/// The live MOTIS/Transitous instances return the *rich* rail vocabulary
/// (`HIGHSPEED_RAIL`, `NIGHT_RAIL`, `SUBURBAN`, …), not the coarser set in the
/// published OpenAPI summary, so those are matched here. An unrecognised value
/// falls back to [TransitMode.other] instead of throwing — the mode catalogue
/// can grow on their side without breaking a running app.
TransitMode transitModeFromMotis(String raw) {
  switch (raw.toUpperCase()) {
    case 'WALK':
    case 'FOOT':
      return TransitMode.walk;
    case 'BIKE':
    case 'BIKE_SHARING':
    case 'SCOOTER_STANDING':
      return TransitMode.bike;
    case 'CAR':
    case 'HGV':
      return TransitMode.car;
    case 'BUS':
      return TransitMode.bus;
    case 'COACH':
      return TransitMode.coach;
    case 'TRAM':
      return TransitMode.tram;
    case 'SUBWAY':
    case 'METRO':
      return TransitMode.subway;
    case 'SUBURBAN':
      return TransitMode.suburban;
    case 'MONORAIL':
      return TransitMode.monorail;
    case 'RAIL':
      return TransitMode.rail;
    case 'HIGHSPEED_RAIL':
      return TransitMode.highSpeedRail;
    case 'LONG_DISTANCE':
      return TransitMode.longDistanceRail;
    case 'NIGHT_RAIL':
      return TransitMode.nightRail;
    case 'REGIONAL_RAIL':
      return TransitMode.regionalRail;
    case 'REGIONAL_FAST_RAIL':
      return TransitMode.regionalFastRail;
    case 'FERRY':
      return TransitMode.ferry;
    case 'FUNICULAR':
      return TransitMode.funicular;
    case 'GONDOLA':
      return TransitMode.gondola;
    case 'AERIAL_LIFT':
      return TransitMode.aerialLift;
    default:
      return TransitMode.other;
  }
}
