import 'transit_filter.dart';

/// How a journey search should be run, apart from *where* and *when*.
///
/// A value type, and the seam every further routing preference lands on — a
/// transfer buffer, a walking speed — so adding one never again means threading
/// a parameter through the interface, the provider family and the client. It
/// stays deliberately provider-agnostic: it says what the traveller wants, and
/// the MOTIS-specific expansion into query parameters lives in the client.
///
/// Equality is by value (a [Set] compares by identity, which would otherwise
/// make every rebuild a fresh cache key for `journeysProvider` and re-run the
/// search); [hashCode] is the same bitmask the preference is persisted as.
class JourneySearchOptions {
  const JourneySearchOptions({this.modes = kAllTransitFilters});

  /// The kinds of transport the search may use. Everything, by default.
  final Set<TransitFilter> modes;

  /// Whether the search is unrestricted — nothing to say on the wire.
  bool get isUnrestricted => modes.length >= kAllTransitFilters.length;

  int get _mask => modes.fold(0, (mask, filter) => mask | (1 << filter.index));

  @override
  bool operator ==(Object other) =>
      other is JourneySearchOptions && other._mask == _mask;

  @override
  int get hashCode => _mask;
}
