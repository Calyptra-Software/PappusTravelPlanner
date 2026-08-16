# Changelog

Notable changes per release. Dates are release dates; the git tags carry the
exact commits.

## 1.6.0 — 2026-08-16

The map.

- **A map of a trip** — places as pins, transport legs as lines, in the trip's
  own accent colour, with the entry that is under way marked as the timeline
  marks it. Tapping a marker opens what the row says: name, times, delays, note,
  coordinates.
- **A map of every trip**, as a third way to read the overview beside the list
  and the calendar. It inherits the filter, so "only my walks" needs no second
  filter UI. A tap where routes overlap lists all the trips under it.
- **Places carry coordinates** (schema v28), picked by tapping the map. The
  connection search can be pointed at the map too, for an address the geocoder
  does not know.
- **GPX import** (schema v29): the line an entry actually followed is drawn
  instead of the straight one between its ends. It travels with every copy of
  the entry, and rides along in a `.tpt` bundle.
- **An imported connection brings its route**, so a train draws along its line
  rather than across the country. Those are dashed — computed, not recorded —
  and a GPX you import yourself takes precedence.
- A night train no longer reads as finished the minute it departs.

## 1.5.0 — 2026-08-09

Renamed to **Pappus Travel Planner**, with new icons and a new repository home.
Added a code of conduct, a security policy, and the `docs/` pages. A connection
can be looked up with no trip behind it.

## 1.4.0 — 2026-08-06

A journey's replacement is bundled per day, the trip's dates widen to cover what
was written, and checklists come along. A routine's journeys and legs can be
re-routed. A run drags as one block of its day.

## 1.3.0 — 2026-08-05

A whole group can be moved and deleted from its own label. A hand-entered run
can be looked up in the timetable.

## 1.2.0 — 2026-08-04

A journey can be looked up again from the sheet that reads it. An imported leg
keeps its stopovers and endpoint ids when edited. Added the about page.

## 1.1.0 — 2026-08-03

First tagged release.
