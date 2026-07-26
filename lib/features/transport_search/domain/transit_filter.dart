/// Which kinds of public transport a connection search may use.
///
/// Deliberately coarser than [TransitMode] — the vocabulary a *result* speaks.
/// This is the question asked *before* searching ("no flights", "trains only"),
/// and the router's twenty-odd modes offered as twenty-odd checkboxes would be
/// a worse question than the one a traveller is actually asking.
///
/// The categories **partition** the routing service's whole transit vocabulary,
/// so an unticked box always takes something away and a ticked one never
/// smuggles a mode in through a gap — which is why [other] exists rather than
/// the leftovers being quietly dropped: a gondola is the point of some trips.
///
/// Persisted as a bitmask of these indices (see `TransitFilterController`), so —
/// like every other persisted enum here — values may only be appended to the
/// end, never reordered.
enum TransitFilter {
  longDistanceRail,
  regionalRail,
  cityTransit,
  bus,
  ferry,
  air,
  other,
}

/// Every category — an unrestricted search, and what a fresh install does.
const Set<TransitFilter> kAllTransitFilters = {
  TransitFilter.longDistanceRail,
  TransitFilter.regionalRail,
  TransitFilter.cityTransit,
  TransitFilter.bus,
  TransitFilter.ferry,
  TransitFilter.air,
  TransitFilter.other,
};

/// The MOTIS `Mode` tokens a category stands for. Kept beside
/// `transitModeFromMotis` (the reverse direction, in `transit_mode.dart`) so the
/// service's mode vocabulary is spoken in exactly two places in the app.
const Map<TransitFilter, List<String>> _motisModes = {
  TransitFilter.longDistanceRail: [
    'HIGHSPEED_RAIL',
    'LONG_DISTANCE',
    'NIGHT_RAIL',
  ],
  TransitFilter.regionalRail: ['REGIONAL_RAIL', 'SUBURBAN'],
  TransitFilter.cityTransit: ['SUBWAY', 'TRAM'],
  TransitFilter.bus: ['BUS', 'COACH'],
  TransitFilter.ferry: ['FERRY'],
  TransitFilter.air: ['AIRPLANE'],
  TransitFilter.other: [
    'FUNICULAR',
    'AERIAL_LIFT',
    'ODM',
    'RIDE_SHARING',
    'OTHER',
  ],
};

/// The `transitModes` tokens for [filters], in category order.
///
/// **Empty when [filters] covers everything** — the parameter is then left off
/// the request, so the server applies its own `TRANSIT` default, including any
/// mode it has learned since this app was built. A restriction, by contrast, is
/// exact: it can only ever name modes this app knows about, which is the right
/// trade when the user has asked for less.
List<String> motisTransitModes(Set<TransitFilter> filters) {
  if (filters.length >= kAllTransitFilters.length) return const [];
  return [
    for (final filter in TransitFilter.values)
      if (filters.contains(filter)) ..._motisModes[filter]!,
  ];
}
