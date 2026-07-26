import 'transit_filter.dart';

/// Walking speeds the search offers, in km/h. [kNormalWalkingSpeedKmh] is what
/// an untouched search uses — near enough the routing service's own default
/// (measured at ~4.3 km/h) while sitting on the slider's own grid, so "normal"
/// is a position a user can drag back to.
const double kMinWalkingSpeedKmh = 2.0;
const double kNormalWalkingSpeedKmh = 4.5;
const double kMaxWalkingSpeedKmh = 7.0;
const double kWalkingSpeedStepKmh = 0.5;

/// The longest change the search will let someone ask for. Beyond half an hour
/// the answer is "leave later", which the date/time field already says better.
const int kMaxMinTransferMinutes = 30;

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
    this.maxTransfers,
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

  /// The most interchanges to accept; `0` is "direct only", null no limit.
  final int? maxTransfers;

  /// Whether this asks for nothing beyond the service's own defaults.
  bool get isDefault =>
      modes.length >= kAllTransitFilters.length &&
      minTransferMinutes == 0 &&
      walkingSpeedKmh == kNormalWalkingSpeedKmh &&
      maxTransfers == null;

  /// The [modes] as the bitmask they are persisted as — also what makes a set
  /// (which compares by identity) usable in [==].
  int get modeMask =>
      modes.fold(0, (mask, filter) => mask | (1 << filter.index));

  JourneySearchOptions copyWith({
    Set<TransitFilter>? modes,
    int? minTransferMinutes,
    double? walkingSpeedKmh,
    int? maxTransfers,
    bool clearMaxTransfers = false,
  }) => JourneySearchOptions(
    modes: modes ?? this.modes,
    minTransferMinutes: minTransferMinutes ?? this.minTransferMinutes,
    walkingSpeedKmh: walkingSpeedKmh ?? this.walkingSpeedKmh,
    maxTransfers: clearMaxTransfers ? null : maxTransfers ?? this.maxTransfers,
  );

  @override
  bool operator ==(Object other) =>
      other is JourneySearchOptions &&
      other.modeMask == modeMask &&
      other.minTransferMinutes == minTransferMinutes &&
      other.walkingSpeedKmh == walkingSpeedKmh &&
      other.maxTransfers == maxTransfers;

  @override
  int get hashCode =>
      Object.hash(modeMask, minTransferMinutes, walkingSpeedKmh, maxTransfers);
}
