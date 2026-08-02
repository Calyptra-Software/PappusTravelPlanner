/// Calendar-date arithmetic, with no dependency on formatting or
/// localization — so the data layer can shift a plan's days without reaching
/// into the UI's date helpers.
///
/// Every date in this app is a *civil* date: a day, not an instant. The
/// distinction matters because a local day is 23 or 25 hours across a
/// daylight-saving change, which is enough to make a [Duration] of days land on
/// the wrong one.
library;

/// Strips the time component so a [DateTime] can be used as a stable day key.
DateTime normalizeDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

/// [date] moved by [days] whole calendar days.
///
/// Not `add(Duration(days: n))`: a local day is 23 or 25 hours across a
/// daylight-saving change, so adding a fixed duration to a midnight can land on
/// 23:00 the day before. Going through the constructor asks for a *calendar*
/// day, which is what every date in this app means.
DateTime addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Whole calendar days from [from] to [to] — negative when [to] is earlier.
///
/// Counted in civil days for the same reason [addDays] adds them that way:
/// `difference().inDays` truncates, so a 23-hour DST day between two midnights
/// answers 0 where the calendar says 1. [DateTime.utc] has no such days, so
/// normalizing both ends into UTC makes the subtraction exact.
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}
