# Testing notes

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for a test that hangs, leaks a timer, or passes only in one time zone.

Drift's `.watch()` streams **do not resolve under `flutter_test`'s fake-async** clock, so
widget tests hang if they depend on the real DB stream. Override the feature provider with a
plain `Stream.value(...)` instead (see `pumpOverview` in `test/trip_flow_test.dart`). For
DAO/logic tests, construct `AppDatabase.forTesting(NativeDatabase.memory())` against an
in-memory database.

The same hazard has a second face, which is worth knowing because it fails *after* the
assertions pass: cancelling a drift stream schedules a zero-duration timer
(`StreamQueryStore.markAsClosed`), and a test whose tree is disposed at the end leaves it
pending — reported as "A Timer is still pending even after the widget tree was disposed".
Any widget that watches a DB-backed provider therefore has to be stubbed out in every test
that pumps it, even one that never looks at what it draws. `test/support/attachment_overrides.dart`
is that stub for the attachment providers; a new provider watched from the timeline or the
item form needs the same treatment, and the symptom of forgetting is six unrelated files
timing out.

A third face, for a flow that hops to an isolate: `compute` runs on a **real** one, which
the fake clock does not drive, so `pumpAndSettle` returns long before the work is done and
awaiting the flow's future from the fake zone deadlocks — its continuations need a pump,
and the pump is what you are waiting to be allowed to do. `test/attachment_flow_test.dart`
holds the future the tap started and awaits it *with the tap* inside one `tester.runAsync`,
which is deterministic where sleeping "long enough" is not. The production side of the same
seam: `addAttachments` takes an injectable `pickFiles`, and its `endOfFrame` await — there
so the browser can paint the "reading" message before `compute` blocks its one thread — is
guarded by `kIsWeb`, because awaiting a frame from inside a callback is exactly what
deadlocks a widget test and there is nothing to gain from it where the work is off-thread.

**Date arithmetic is only tested where a day can be 23 hours long.** `flutter test` runs
in the machine's zone, and in UTC a `Duration` of days is always right, so the month
calendar once showed 25 October twice with every test green. CI therefore runs the suite
under `TZ=Europe/Berlin`, and a test that checks something only across a daylight-saving
change passes `skip: skipWithoutEuropeanDst` (`test/support/dst.dart`): elsewhere it says it
was skipped instead of passing without testing anything. Run such a file locally with
`TZ=Europe/Berlin flutter test …` if the machine is set to another zone.

Three smaller traps, each found by a test that had to be written twice:

- **A stubbed stream has to replay its last value.** A `StreamController.broadcast` gives a
  late subscriber nothing, and the widgets here subscribe late by construction: a checklist's
  entries are first watched on the build *after* its checklist arrives, so a value pushed
  before that build is simply lost and the card draws as empty. The override therefore yields
  a snapshot before forwarding the controller
  (`test/trip_checklists_section_test.dart`) — everything real, only the delivery stubbed.
- **`ref.read` of a provider nothing watches reads `AsyncLoading`.** `_toAnotherTrip` in
  `trip_checklists_section.dart` reads `tripListProvider` in a callback, which works in the
  app only because the overview screen underneath keeps it alive — the trap
  `TransportSearchController._modes` documents, arriving from the other side. A harness that
  pumps the section alone gets no trips and the "no other trip" message instead of the
  picker, so the test watches it too, standing in for the screen beneath. It has to be
  overridden even where no picker is opened, or that watch opens a real `watchTrips()` and
  the timer above comes back.
- **A long screen must hold what its sections read, or scrolling disposes them.**
  `SettingsScreen` watches `reasonRowsProvider`, `currenciesProvider`,
  `currencyCostCountsProvider`, `transportModesProvider`, `peopleRowsProvider` and
  `databaseStorageProvider` itself (`_keepSectionsAlive`), though it draws none of them: a
  `ListView` unmounts a child it has scrolled far enough past, which drops the last listener
  on an `autoDispose` stream and disposes it. Coming back, the section rebuilds from
  `AsyncLoading`, draws its "nothing here" row, and grows to its real height a frame later.
  Below the viewport nobody sees that; **above** it, the scroll offset is a number, so
  content over it getting taller means the same number points further up the list — a jump
  of half a screen, only ever felt scrolling *upwards*, and always in the same place. That
  is the same fact `trip_checklists_section.dart` records from the other side (its picker
  works "only because the overview screen underneath keeps it alive") and
  `TransportSearchController._modes` records from the third: a provider is alive because
  something is watching it, and *what* is watching must outlive the scrolling. Held by the
  screen rather than by keep-alives, since the screen is the thing that outlives it.
  `settings_sections_alive_test.dart` asserts the subscription rather than the pixels.
- **A provider holding a timer must be disposed inside the test body.** The binding checks
  for pending timers *before* tear-downs run, so `addTearDown(container.dispose)` reports
  `nowProvider`'s next tick as a leak (`test/clock_test.dart`). Close the subscription,
  dispose, and pump — which is also the only way to test that it stops ticking at all: the
  assertion is the absence of a report.
