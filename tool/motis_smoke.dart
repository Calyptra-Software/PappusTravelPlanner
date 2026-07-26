// Throwaway smoke test for the connection-search client: hits the *live*
// Transitous instance, geocodes two stations, plans a journey between them, and
// prints the parsed result. Pure Dart (no Flutter) — run with:
//
//   dart run tool/motis_smoke.dart "Hamburg Hbf" "Wien Hbf"
//
// Defaults to Hamburg -> Wien (an overnight route) when no args are given.
// A third argument restricts the means of transport, by [TransitFilter] name:
//
//   dart run tool/motis_smoke.dart "Hamburg Hbf" "Wien Hbf" bus,ferry
//
// Needs network access; not part of the test suite.
// ignore_for_file: avoid_print
import 'package:travelplanner/features/transport_search/data/motis_client.dart';
import 'package:travelplanner/features/transport_search/domain/journey_options.dart';
import 'package:travelplanner/features/transport_search/domain/transit_filter.dart';

Future<void> main(List<String> args) async {
  final fromQuery = args.isNotEmpty ? args[0] : 'Hamburg Hbf';
  final toQuery = args.length > 1 ? args[1] : 'Wien Hbf';
  final modes = args.length > 2
      ? {
          for (final name in args[2].split(','))
            TransitFilter.values.byName(name.trim()),
        }
      : kAllTransitFilters;
  final search = MotisTransportSearch();

  try {
    final from = (await search.searchPlaces(fromQuery)).first;
    final to = (await search.searchPlaces(toQuery)).first;
    print('From: ${from.name} (${from.area}) [${from.timeZone}]');
    print('To:   ${to.name} (${to.area}) [${to.timeZone}]\n');

    // Evening tomorrow, to make overnight options likely.
    final when = DateTime.now()
        .toUtc()
        .add(const Duration(days: 1))
        .copyWith(hour: 14, minute: 0);
    print('SENT time = ${when.toUtc().toIso8601String()}');
    print('SENT transitModes = ${motisTransitModes(modes)}\n');
    final results = await search.journeys(
      fromId: from.id,
      toId: to.id,
      time: when,
      options: JourneySearchOptions(modes: modes),
    );

    print('${results.options.length} option(s) in this window:');
    print('  earlier: ${results.earlierCursor}');
    print('  later:   ${results.laterCursor}\n');
    for (final (i, o) in results.options.indexed) {
      final overnight = o.arrival.toLocal().day != o.departure.toLocal().day;
      print(
        '#${i + 1}  ${_hm(o.departure)} -> ${_hm(o.arrival)}  '
        '${o.duration.inHours}h${o.duration.inMinutes % 60}m  '
        '${o.transfers} change(s)${overnight ? '  [overnight]' : ''}',
      );
      for (final leg in o.legs) {
        print(
          '     ${leg.mode.name.padRight(16)} '
          '${leg.line ?? '(walk)'}  '
          '${_hm(leg.from.scheduled)} ${leg.from.name} '
          '-> ${_hm(leg.to.scheduled)} ${leg.to.name}',
        );
      }
      print('');
    }
  } finally {
    search.close();
  }
}

// Prints the raw UTC date+time (wall-clock conversion via the stop's tz is
// Phase 3). The date matters: an option after a 16:00 request often departs the
// next morning, which HH:MM alone would make look "earlier".
String _hm(DateTime t) =>
    '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}Z';
