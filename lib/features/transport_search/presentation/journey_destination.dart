import '../../trips/planned_journey.dart';

/// Where a connection taken from the search sheet ends up — or that it ends up
/// nowhere at all.
///
/// The search form is the same question in every case ("what runs from here to
/// there, when?"); what differs is only what happens to the answer. Modelling
/// that as a type rather than as four optional parameters is what makes the
/// impossible combinations unsayable: a run cannot be both added to an option
/// and replace an existing one, and a lookup cannot name a trip it has none of.
/// Before this the same rule lived as an `assert` that only fired at runtime,
/// and the destination-less case could not be expressed at all.
sealed class JourneyDestination {
  const JourneyDestination();
}

/// No trip behind the search: the results are read and nothing is written.
///
/// The quick "when is the next train?" — asked from the overview, before there
/// is any plan to hang the answer on, and often when there never will be one.
/// The preview therefore offers no way to commit: a journey here is *read*, and
/// the app's rule that a tap browses while a button commits is kept by there
/// being no button rather than by there being a harmless one.
final class JourneyLookup extends JourneyDestination {
  const JourneyLookup();
}

/// A destination inside a trip: the found legs are written to [tripId], on
/// [day].
sealed class TripJourneyDestination extends JourneyDestination {
  const TripJourneyDestination({
    required this.tripId,
    required this.day,
    this.intoRoutine = false,
  });

  final int tripId;

  /// The day the legs belong to. For a routine this is a day of the *plan* (day
  /// one is `kRoutineAnchorDay`), which no timetable can answer for — see
  /// [intoRoutine].
  final DateTime day;

  /// Whether the legs are going into a routine.
  ///
  /// A routine has no dates, but a timetable only exists on real ones: you
  /// cannot ask what runs on day one of a plan. So the search is made on a real
  /// date — today by default, changeable, since a Sunday timetable is not a
  /// Tuesday one — and what it finds is laid back onto [day], keeping the shape
  /// of the journey (an overnight leg still lands on the next day of the plan)
  /// while carrying none of that date's own identity.
  final bool intoRoutine;
}

/// The found run is **added**: to [day] itself, or to one option of a decision
/// on it.
final class AddToDay extends TripJourneyDestination {
  const AddToDay({
    required super.tripId,
    required super.day,
    super.intoRoutine,
    this.alternativeId,
  });

  /// The option of a decision the run is planned in, or null for the day
  /// itself. A search reached from an option's *Add transport* has to land where
  /// that button plans everything else it offers — an imported connection is not
  /// a different kind of entry from a hand-written leg.
  final int? alternativeId;
}

/// The found run **replaces** [journey], a run the trip already holds: its legs
/// make way for the new ones, which keep the group and so the shared ticket.
///
/// The query is still the user's to change — another day, an hour later, a via
/// stop, different modes — which is the whole reason this is the search sheet
/// and not a single silent request: "the 07:32 was cancelled" and "I'll go in
/// after lunch instead" are the same act.
///
/// Composes with [TripJourneyDestination.intoRoutine]: re-routing a *routine's*
/// run searches a real date and lays the answer back onto the plan day, which is
/// the same trade the import makes there. The form then opens on today, as it
/// does for an import, while the time still comes from the run — a commute
/// leaves at the minute the plan says whichever day it is asked about.
final class ReplaceRun extends TripJourneyDestination {
  const ReplaceRun({
    required super.tripId,
    required super.day,
    required this.journey,
    super.intoRoutine,
    this.departFromMinutes,
  });

  final PlannedJourney journey;

  /// The minute to open the time field on, when the run being replaced is not
  /// the best answer to "from when?" — one leg of a journey whose previous leg
  /// came in late, where the traveller is standing on the platform at the time
  /// they really arrived rather than the one the plan hoped for
  /// (`departureSeedMinutes`).
  final int? departFromMinutes;
}
