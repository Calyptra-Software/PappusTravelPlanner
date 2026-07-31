import 'transit_filter.dart';

/// Walking speeds the search offers, in km/h. [kNormalWalkingSpeedKmh] is what
/// an untouched search uses — near enough the routing service's own default
/// (measured at ~4.3 km/h) while sitting on the slider's own grid, so "normal"
/// is a position a user can drag back to.
const double kMinWalkingSpeedKmh = 2.0;
const double kNormalWalkingSpeedKmh = 4.5;
const double kMaxWalkingSpeedKmh = 10.0;
const double kWalkingSpeedStepKmh = 0.5;

/// The longest change the search will let someone ask for. Beyond half an hour
/// the answer is "leave later", which the date/time field already says better.
const int kMaxMinTransferMinutes = 30;

/// How long the traveller is willing to spend getting to the first stop, away
/// from the last, and making the whole journey without public transport at all.
///
/// `null` in [JourneySearchOptions] means **automatic**: the service's own
/// 15/15/30 minutes, stretched for someone who walks slowly so that a slow
/// walker is not simply told there are no connections. A value chosen here is
/// used exactly as chosen — a budget someone picked is not silently multiplied.
/// Beyond an hour the answers stop changing, so the lists end there.
const List<int?> kPrePostTransitMinuteOptions = [
  null,
  5,
  10,
  15,
  20,
  30,
  45,
  60,
];
const List<int?> kDirectMinuteOptions = [null, 15, 30, 45, 60, 90, 120];

/// Cycling speeds the search offers, in km/h — roughly the range the routing
/// service's own client uses (2.7–7.0 m/s).
const double kMinCyclingSpeedKmh = 10.0;
const double kNormalCyclingSpeedKmh = 15.0;
const double kMaxCyclingSpeedKmh = 25.0;
const double kCyclingSpeedStepKmh = 0.5;

/// How a journey search should be run, apart from *where* and *when*.
///
/// A value type, and the one place every routing preference lands, so adding
/// another never again means threading a parameter through the interface, the
/// provider family and the client. It stays deliberately provider-agnostic: it
/// says what the traveller wants in their own terms, and the expansion into
/// MOTIS query parameters — including everything derived from
/// [walkingSpeedKmh] — lives in the client.
///
/// Equality is by value: this is the `journeyResultsProvider` family key, so a
/// rebuild that produced an equal-but-not-identical instance would otherwise
/// re-run the search and throw away the loaded windows.
class JourneySearchOptions {
  const JourneySearchOptions({
    this.modes = kAllTransitFilters,
    this.minTransferMinutes = 0,
    this.walkingSpeedKmh = kNormalWalkingSpeedKmh,
    this.wheelchair = false,
    this.maxTransfers,
    this.byBike = false,
    this.bikeOnBoard = false,
    this.cyclingSpeedKmh = kNormalCyclingSpeedKmh,
    this.maxPreTransitMinutes,
    this.maxPostTransitMinutes,
    this.maxDirectMinutes,
  });

  /// The kinds of transport the search may use. Everything, by default.
  final Set<TransitFilter> modes;

  /// The shortest change to plan: no connection will be offered with less than
  /// this between arriving and departing again. `0` accepts whatever the
  /// timetable says is possible, which is the service's own default and can be
  /// a three-minute sprint across a terminus.
  final int minTransferMinutes;

  /// How fast the traveller walks. Drives the street legs *and* — since the
  /// service scales the two separately — the footpaths inside a station; see
  /// the client for that mapping.
  final double walkingSpeedKmh;

  /// Whether the journey has to be step-free: footpaths — to the first stop,
  /// between services, from the last — routed for a wheelchair, and only
  /// services the timetable marks as carrying wheelchairs.
  ///
  /// Both halves of that are one setting because the service makes them one:
  /// see the client, where it is the pedestrian profile that also filters the
  /// vehicles.
  final bool wheelchair;

  /// The most interchanges to accept; `0` is "direct only", null no limit.
  final int? maxTransfers;

  /// Whether the traveller has a bike with them: it may then make the whole
  /// journey, or carry them to the first stop.
  final bool byBike;

  /// Whether the bike comes *on board*, which both restricts the search to
  /// services that carry bikes and means the bike is still there at the far
  /// end. Meaningless without [byBike].
  final bool bikeOnBoard;

  /// How fast the traveller cycles. Only asked about when [byBike].
  final double cyclingSpeedKmh;

  /// Minutes allowed for reaching the first stop and for leaving the last one —
  /// null for automatic (see [kPrePostTransitMinuteOptions]). Both only bite
  /// when that end of the journey is a *coordinate*: from a station there is no
  /// first mile to route.
  final int? maxPreTransitMinutes;
  final int? maxPostTransitMinutes;

  /// Minutes allowed for making the whole journey without public transport —
  /// on foot, or by bike when [byBike]. This is what decides whether the
  /// results offer to simply walk (or ride) it.
  final int? maxDirectMinutes;

  /// Whether this asks for nothing beyond the service's own defaults.
  bool get isDefault =>
      modes.length >= kAllTransitFilters.length &&
      minTransferMinutes == 0 &&
      walkingSpeedKmh == kNormalWalkingSpeedKmh &&
      !wheelchair &&
      maxTransfers == null &&
      !byBike &&
      !bikeOnBoard &&
      cyclingSpeedKmh == kNormalCyclingSpeedKmh &&
      maxPreTransitMinutes == null &&
      maxPostTransitMinutes == null &&
      maxDirectMinutes == null;

  /// The [modes] as the bitmask they are persisted as — also what makes a set
  /// (which compares by identity) usable in [==].
  int get modeMask =>
      modes.fold(0, (mask, filter) => mask | (1 << filter.index));

  JourneySearchOptions copyWith({
    Set<TransitFilter>? modes,
    int? minTransferMinutes,
    double? walkingSpeedKmh,
    bool? wheelchair,
    int? maxTransfers,
    bool clearMaxTransfers = false,
    bool? byBike,
    bool? bikeOnBoard,
    double? cyclingSpeedKmh,
    int? maxPreTransitMinutes,
    int? maxPostTransitMinutes,
    int? maxDirectMinutes,
    bool clearBudgets = false,
  }) => JourneySearchOptions(
    modes: modes ?? this.modes,
    minTransferMinutes: minTransferMinutes ?? this.minTransferMinutes,
    walkingSpeedKmh: walkingSpeedKmh ?? this.walkingSpeedKmh,
    wheelchair: wheelchair ?? this.wheelchair,
    maxTransfers: clearMaxTransfers ? null : maxTransfers ?? this.maxTransfers,
    byBike: byBike ?? this.byBike,
    // Leaving the bike behind takes it off the train with it.
    bikeOnBoard: (byBike ?? this.byBike)
        ? bikeOnBoard ?? this.bikeOnBoard
        : false,
    cyclingSpeedKmh: cyclingSpeedKmh ?? this.cyclingSpeedKmh,
    // Each budget is nullable *and* null means something ("automatic"), so
    // clearing one has to be asked for rather than implied by a null argument.
    maxPreTransitMinutes: clearBudgets
        ? null
        : maxPreTransitMinutes ?? this.maxPreTransitMinutes,
    maxPostTransitMinutes: clearBudgets
        ? null
        : maxPostTransitMinutes ?? this.maxPostTransitMinutes,
    maxDirectMinutes: clearBudgets
        ? null
        : maxDirectMinutes ?? this.maxDirectMinutes,
  );

  @override
  bool operator ==(Object other) =>
      other is JourneySearchOptions &&
      other.modeMask == modeMask &&
      other.minTransferMinutes == minTransferMinutes &&
      other.walkingSpeedKmh == walkingSpeedKmh &&
      other.wheelchair == wheelchair &&
      other.maxTransfers == maxTransfers &&
      other.byBike == byBike &&
      other.bikeOnBoard == bikeOnBoard &&
      other.cyclingSpeedKmh == cyclingSpeedKmh &&
      other.maxPreTransitMinutes == maxPreTransitMinutes &&
      other.maxPostTransitMinutes == maxPostTransitMinutes &&
      other.maxDirectMinutes == maxDirectMinutes;

  @override
  int get hashCode => Object.hash(
    modeMask,
    minTransferMinutes,
    walkingSpeedKmh,
    wheelchair,
    maxTransfers,
    byBike,
    bikeOnBoard,
    cyclingSpeedKmh,
    maxPreTransitMinutes,
    maxPostTransitMinutes,
    maxDirectMinutes,
  );
}
