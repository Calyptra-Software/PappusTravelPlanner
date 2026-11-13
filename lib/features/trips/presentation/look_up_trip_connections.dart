import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../transport_search/data/motis_client.dart'
    show TransportSearchFailure, searchFailureOf;
import '../../transport_search/domain/journey.dart';
import '../../transport_search/presentation/connection_search_sheet.dart';
import '../../transport_search/presentation/journey_destination.dart';
import '../../transport_search/presentation/journey_preview_sheet.dart';
import '../application/trip_connections_controller.dart';
import '../planned_journey.dart';

/// Offers each journey in [tripId] a fresh connection for the day it now sits
/// on, one at a time, and puts in whichever the user accepts.
///
/// Asked after a plan has been put onto new dates: a routine stamped out, a
/// trip duplicated or moved.
///
/// The plan is already written, so every exit from here leaves a usable trip:
/// declining an option, finding nothing, or losing the network all end with the
/// plan still in place. What the lookup adds is a real service — and so
/// live times that can be refreshed — for the dates this trip actually runs.
///
/// Each offer has a third answer besides taking it and keeping the plan:
/// **adjusting the search**, which opens the ordinary search form on that run
/// (`ReplaceRun`, exactly as the trip's own journey sheet does) and then carries
/// on with the next journey. The connection found is often the one *before* the
/// train wanted, and "keep the plan" is then no better an answer than "use this"
/// — the copied legs carry no live times either way. A journey for which nothing
/// was found is said so **at that journey**, with the same way into the form:
/// "no train at 07:32 on a Sunday" is answered by asking about a later one, and a
/// count in a snack bar after the round names no journey to ask about.
///
/// **Says nothing when it works.** A connection that was taken is in the trip
/// the user is one tap from opening, so announcing it only queues a second
/// message in front of the one carrying that tap. What does get said is what
/// the trip cannot show: that a journey is still the copied plan because
/// nothing runs, because the service was out of reach, or because it answered
/// that it holds no timetable for the day or does not know an end — each in
/// its own words (`TransportSearchFailure`), since a date a month back used to
/// be reported as no signal.
Future<void> lookUpTripConnections(
  BuildContext context,
  WidgetRef ref,
  int tripId,
) async {
  final l10n = AppLocalizations.of(context);
  final localeName = Localizations.localeOf(context).languageCode;
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(tripConnectionsControllerProvider);
  final labels = (
    track: l10n.platformShort,
    fromTrack: l10n.platformFromShort,
    toTrack: l10n.platformToShort,
    direction: l10n.directionTo,
  );

  final candidates = await controller.lookUpCandidates(tripId);
  if (candidates.isEmpty || !context.mounted) return;

  // The form owns everything from the query on, the swap included, so there
  // is nothing to do with what it answers: either the run was replaced or the
  // plan stands.
  Future<void> adjustSearch(PlannedJourney journey) =>
      showConnectionSearchSheet(
        context,
        destination: ReplaceRun(
          tripId: tripId,
          day: journey.date,
          journey: journey,
        ),
      );

  var failed = 0;
  // The days the router said it holds no timetable for. Asking again about
  // another journey on one of them would only be told the same, so those are
  // skipped — while a journey on a later day of a longer routine, which may
  // well lie inside the window, is still asked about.
  final noTimetable = <DateTime>{};
  for (final journey in candidates) {
    if (noTimetable.contains(journey.date)) continue;
    List<JourneyOption> options;
    try {
      options = await controller.lookUp(journey);
    } catch (error) {
      if (!context.mounted) return;
      // Each failure is said as what it is. They all used to read "couldn't
      // reach the routing service", which sent somebody looking for a signal
      // when the service had answered perfectly clearly that it holds no
      // timetable for last month. The plan stands in every case.
      switch (searchFailureOf(error)) {
        case TransportSearchFailure.unreachable:
          // Out of reach for this journey says the same about the rest, so
          // the round ends here rather than asking again per journey.
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.connectionsOffline)),
          );
          return;
        case TransportSearchFailure.failed:
          // A refusal nobody here understands, an overloaded server among
          // them: asking it again straight away is the last thing to do to
          // somebody else's donated machine.
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.connectionsServiceFailed)),
          );
          return;
        case TransportSearchFailure.outsideTimetable:
          noTimetable.add(journey.date);
          continue;
        case TransportSearchFailure.unknownLocation:
          // About this journey's ends only, so it is said at this journey and
          // the round goes on; the form is where an end is picked again.
          final adjust = await _askToAdjust(
            context,
            title: l10n.connectionsUnknownPlaceTitle,
            body: l10n.connectionsUnknownPlaceBody(_routeOf(journey)),
          );
          if (adjust && context.mounted) await adjustSearch(journey);
          if (!context.mounted) return;
          continue;
      }
    }
    if (!context.mounted) return;

    if (options.isEmpty) {
      final adjust = await _askToAdjust(
        context,
        title: l10n.connectionsNotFoundTitle,
        body: l10n.connectionsNotFoundBody(
          _routeOf(journey),
          _whenOf(context, journey, localeName),
        ),
      );
      if (adjust && context.mounted) await adjustSearch(journey);
      if (!context.mounted) return;
      continue;
    }

    // The same reading as a search result anywhere else — a journey reads the
    // same way whoever asked for it.
    final answer = await showConnectionOfferSheet(
      context,
      option: options.first,
      confirmLabel: l10n.connectionsUseThis,
      cancelLabel: l10n.connectionsKeepPlan,
    );
    if (!context.mounted) return;
    switch (answer) {
      case ConnectionOfferAnswer.use:
        try {
          await controller.useConnection(
            tripId,
            journey,
            options.first,
            labels: labels,
          );
        } catch (_) {
          // Writing this one connection failed. The journey keeps its copied
          // plan, and the *next* journey is still asked about: one failure is
          // not evidence about the others, and letting it out of the loop meant
          // the rest were silently never offered.
          failed++;
        }
      case ConnectionOfferAnswer.adjust:
        await adjustSearch(journey);
      case ConnectionOfferAnswer.keep:
        break;
    }
    if (!context.mounted) return;
  }

  if (noTimetable.isNotEmpty) {
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.connectionsNoTimetable)),
    );
  }
  if (failed > 0) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.connectionsNotTaken)));
  }
}

/// Says what became of a journey's lookup — [title] and [body] — and asks
/// whether to adjust the search. Resolves to true for the form, false for
/// keeping the plan, which is also what dismissing the dialog means, since the
/// plan is already written.
Future<bool> _askToAdjust(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final l10n = AppLocalizations.of(context);
  final adjust = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.connectionsKeepPlan),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(l10n.connectionsAdjustSearch),
        ),
      ],
    ),
  );
  return adjust ?? false;
}

/// "Rahlstedt → Hamburg Hbf", for naming a journey in a sentence.
String _routeOf(PlannedJourney journey) {
  final from = journey.fromLocation;
  final to = journey.toLocation;
  return from != null && to != null
      ? '$from → $to'
      : from ?? to ?? journey.legs.first.title ?? '';
}

/// The day and planned departure of [journey], for naming it in a sentence.
String _whenOf(
  BuildContext context,
  PlannedJourney journey,
  String localeName,
) {
  final minutes = journey.departMinutes;
  return [
    formatFullDate(journey.date, localeName),
    // Read the way the preview and the search form read a time.
    if (minutes != null)
      MaterialLocalizations.of(
        context,
      ).formatTimeOfDay(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60)),
  ].join(', ');
}
