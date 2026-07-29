import 'domain/journey.dart';
import 'domain/transit_mode.dart';

/// Reads a routed [JourneyOption] as the rows a traveller wants before
/// committing to it: *what do I board, and where and how long do I change?*
///
/// Pure, so it tests without a network or a database — the same arrangement the
/// itinerary's `day_blocks.dart` uses for a day.
///
/// The routing service reports a journey as a flat list of legs, in which a
/// change is only implied: two vehicle legs, usually with a walking leg between
/// them. That is the wrong shape to read from. A walk from platform 14 to
/// platform 7 is not a leg of the journey — it is *the change* — so
/// [journeyPreview] folds it, together with the waiting time either side of it,
/// into one [ChangeRow] that names the place and says how long there is. A walk
/// at either **end** of the journey is a leg again: it goes somewhere the
/// traveller would not otherwise be, and an all-walking option (the direct
/// connection) is nothing but such legs.
sealed class PreviewRow {
  const PreviewRow();
}

/// One leg to be travelled: a boarded service, or a walk/ride at either end of
/// the journey.
class LegRow extends PreviewRow {
  const LegRow(this.leg);

  final JourneyLeg leg;
}

/// The gap between two boarded services: where to get off, where to get on
/// again, and how long there is between the two.
class ChangeRow extends PreviewRow {
  const ChangeRow({
    required this.place,
    required this.minutes,
    this.toPlace,
    this.actualMinutes,
    this.ownSteamMinutes,
    this.ownSteamMode,
  });

  /// Where the arriving service sets the traveller down.
  final String place;

  /// Where the next service is boarded, when that is a **different** stop —
  /// null when the change happens within one station, which is the normal case.
  final String? toPlace;

  /// The change as *planned*: scheduled arrival to scheduled departure.
  final int minutes;

  /// The change as it currently stands once real-time times are taken into
  /// account, and only when that differs from [minutes] — null otherwise, so
  /// the UI has nothing to say about a change nothing has happened to. This is
  /// the number a delay actually threatens: a planned 23-minute change behind a
  /// train running 18 late is a 5-minute one.
  final int? actualMinutes;

  /// How much of the change is spent getting from one service to the other
  /// under one's own steam, when the router routed such a leg through it (null
  /// when the change is pure waiting).
  final int? ownSteamMinutes;

  /// How that stretch is covered (walking, normally). Null exactly when
  /// [ownSteamMinutes] is.
  final TransitMode? ownSteamMode;
}

/// Splits [option] into the rows described on [PreviewRow].
List<PreviewRow> journeyPreview(JourneyOption option) {
  final legs = option.legs;
  // Past this index there is no service left to change onto, so an own-steam
  // leg beyond it is the journey's final stretch rather than a transfer.
  final lastService = legs.lastIndexWhere((leg) => !leg.mode.isOwnSteam);

  final rows = <PreviewRow>[];
  var boarded = -1; // index of the last service already emitted
  for (var i = 0; i < legs.length; i++) {
    final leg = legs[i];
    if (leg.mode.isOwnSteam) {
      // Between two services this stretch belongs to the change, which the
      // service on the far side of it will emit.
      if (boarded >= 0 && i < lastService) continue;
      rows.add(LegRow(leg));
      continue;
    }
    if (boarded >= 0) {
      rows.add(_change(legs[boarded], leg, legs.sublist(boarded + 1, i)));
    }
    rows.add(LegRow(leg));
    boarded = i;
  }
  return rows;
}

/// The change between the service [from] arrives on and the one [to] leaves on,
/// with whatever own-steam legs [between] them the router put in.
ChangeRow _change(JourneyLeg from, JourneyLeg to, List<JourneyLeg> between) {
  // Both ends are UTC instants, so the gap needs no timezone to be right — even
  // when the change straddles one.
  final planned = to.from.scheduled.difference(from.to.scheduled).inMinutes;
  final live = from.to.actual == null && to.from.actual == null
      ? null
      : to.from.effective.difference(from.to.effective).inMinutes;
  final ownSteam = between.fold<int>(
    0,
    (sum, leg) =>
        sum + leg.to.scheduled.difference(leg.from.scheduled).inMinutes,
  );
  return ChangeRow(
    place: from.to.name,
    toPlace: to.from.name == from.to.name ? null : to.from.name,
    minutes: planned,
    actualMinutes: live == planned ? null : live,
    ownSteamMinutes: ownSteam == 0 ? null : ownSteam,
    ownSteamMode: ownSteam == 0 ? null : between.first.mode,
  );
}
