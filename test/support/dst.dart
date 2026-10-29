/// Whether the local zone changes its clocks on Central Europe's 2026 dates:
/// forward on 29 March, back on 25 October, so those local days are 23 and 25
/// hours long.
///
/// The daylight-saving tests are written against exactly those two days, and
/// in a zone without them — UTC, which is where CI used to run, or New York,
/// whose clocks change on other Sundays — they pass whether the code is right
/// or not. Measured in the zone itself rather than read off its name, so any
/// zone following the EU's rules counts.
final bool localZoneHasEuropeanDst =
    DateTime(2026, 3, 30).difference(DateTime(2026, 3, 29)).inHours == 23 &&
    DateTime(2026, 10, 26).difference(DateTime(2026, 10, 25)).inHours == 25;

/// The `skip:` for a test that checks something only across those two days:
/// skipped, and saying why, where it would otherwise pass without testing
/// anything.
final Object? skipWithoutEuropeanDst = localZoneHasEuropeanDst
    ? null
    : 'needs a zone with Central European daylight saving, '
          'e.g. TZ=Europe/Berlin';
