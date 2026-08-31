/// Where a widget tap means to go — pure, so the one piece of this feature with
/// a decision in it can be tested without a platform channel behind it.
///
/// The whole widget links to the trip (`pappus://trip?id=N`); a tapped item row
/// adds `&item=M` to open that entry. `-1` is the native side's "nothing here"
/// — an `AppWidgetProvider` fills its `RemoteViews` before it knows what the
/// app has, so an absent id arrives as a number rather than as a missing
/// parameter, and a widget showing no trip must not open trip minus one.
///
/// Returns null when there is nothing to do at all, which is a different answer
/// from `/`: a launch with no uri behind it is an ordinary cold start, and
/// sending that to the overview would throw away wherever the app was going.
String? widgetLaunchLocation(Uri? uri) {
  if (uri == null) return null;
  final id = uri.queryParameters['id'];
  if (uri.host != 'trip' || id == null || id == '-1') return '/';
  final item = uri.queryParameters['item'];
  if (item != null && item.isNotEmpty && item != '-1') {
    return '/trip/$id?item=$item';
  }
  return '/trip/$id';
}
