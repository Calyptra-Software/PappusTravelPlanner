# Itinerary: items, groups, decisions, times

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for the timeline, groups and decisions, drag/move/copy, "you are here", planned/actual times, overnight entries, transport modes.

- **Single `ItineraryItems` table** holds both places and transport legs, discriminated by
  `ItemKind`; kind-specific columns are nullable. This lets a day read as one ordered timeline
  (place → transport → place). Items are ordered by `date` → `sortOrder` → `startMinutes`.
- **Item groups** (`ItemGroups`, with `ItineraryItems.groupId`) bundle adjacent items — e.g.
  a train journey of several legs sharing one ticket — so a single cost covers them all. A
  `Cost` attaches to exactly one of an item (`itemId`), a group (`groupId`), or the trip
  (`tripId`); the stats engine only sees one row per cost, so grouping never affects the maths.
  `groupId` on items is `setNull` on group delete (dissolving a group keeps its items); a
  group's costs are re-pointed onto its first member before the group is deleted so the expense
  survives. Grouping ops live in `GroupDao`.
- **Alternatives** (`AlternativeSets` / `Alternatives`, with `ItineraryItems.alternativeId`) are
  a second, orthogonal axis of bundling: a set is one decision on one day ("what do we do on
  Saturday afternoon?"), holding two or more branches — competing versions of that stretch of
  the day — of which exactly one is `chosen`. There is deliberately no "actually happened" flag
  beside it: the chosen branch is what the trip counts, so settling a decision after the fact is
  just choosing what you did (v18 dropped the `decided` column that tried to say more).
  A group means "these share a ticket", a branch means
  "these are one option"; a group never straddles two branches (`GroupDao.groupItems` throws).
  An item is either *loose* (`alternativeId` null — the ordinary case) or in exactly one branch.
  A set occupies **one slot** in its day: `AlternativeSets.date`/`sortOrder` share an ordering
  space with the day's loose items, while a branch item's `sortOrder` orders it within its
  branch. Deleting a branch **deletes its items** (cascade — unlike dissolving a group, which
  frees them), and a set left with one branch is flattened back into the day. Ops live in
  `AlternativeDao`.
- The timeline renders a day as a list of **blocks** (`features/itinerary/day_blocks.dart`,
  pure): an `ItemBlock` (a loose item), a `GroupBlock` (a whole run), or a `DecisionBlock` (a
  whole set). A decision draws as
  an `AlternativeCard` — a `PageView` **swiped** between options, which only *browses*;
  choosing is the explicit button, so looking at an option never moves the trip's money. The
  indicator row under it carries every option's price (the comparison a pager otherwise hides).
  Dragging in a day reorders blocks (writing `ItineraryItems.sortOrder` *and*
  `AlternativeSets.sortOrder`); dragging inside a card reorders that option's blocks, and
  dragging inside a run reorders that run's members. An option is built from the same
  `buildItemBlocks` a day's loose entries are, so a run reads and drags the same way in either.
- **A run is one slot, and a slot is not one sort order.** A group of entries sharing a ticket
  is a single thing to the plan, so it is a single block: it drags as one, and no drag can put
  something in the middle of it or pull a leg out — the two acts that cross a boundary stay the
  explicit move/copy. Its members are a `ReorderableListView` of their own inside the band
  (`GroupRunTile`), the same arrangement a decision has: a card that moves as a unit in the day,
  holding a list that reorders within itself. Before this each member was its own slot, so a run
  could be dragged apart, and the halves went on claiming to be one group — each drawing the
  band and printing the shared ticket. The renumbering therefore walks a **running counter**
  rather than writing each block's index (`_onReorder`), since a run of three legs is one block
  holding three ordinary items; and reordering *within* a run hands the run's own sort orders
  back out in the new order, so rearranging it can never walk it out of its place in the day.
  `buildItemBlocks` collects a run by `groupId` rather than by adjacency: nothing can split one
  any more, but a database written before this could hold one that a drag had split, and closing
  the gap is better than drawing it as two.
- **Drag reorders *within* a list; move/copy crosses between them.** A day and an option are
  two separate `ReorderableListView`s, and a decision is one index in its day, so no drag can
  express "into that option" — nor should one, since landing in an unchosen option takes an
  entry's money out of the trip's totals, and this app's rule is that gestures browse while
  buttons commit. Crossing a boundary is therefore two explicit steps: the item sheet's
  **Move to… / Copy to…** picks the entry up into `itemClipboardProvider`
  (`features/itinerary/application/item_clipboard.dart` — a `HeldItem`, autoDispose so leaving
  the trip screen drops the hold rather than leaving an invisible pending move); the day's and
  each option's add-row then grows a `PutDownChip`, so the destination names itself by being
  the place you navigated to. The held entry stays visible, dimmed (`TimelineTile.held`), under
  a `_HoldingBar`. `ItineraryDao.moveItem` / `duplicateItem` do the writing, appending to the
  end of the destination (finer placement is the drag's job again). Two rules there: a moved
  entry **leaves its group** (a group is one contiguous run inside one day or option), and a
  **copy takes the plan, not the money** — a cost records a payment that happened once, and
  duplicating it would silently invent money inside the settle-up. The clipboard's `Held` is a
  sealed type: a `HeldItem` *or* a `HeldGroup`, so a whole shared-ticket run rides along too —
  dimmed member-by-member (`isHeldItem`), landing via
  `GroupDao.moveGroup` (members travel together, still grouped, the shared cost riding along
  since it hangs off the surviving group) / `copyGroup` (a fresh bundle, no costs). The copy
  fields live once, in `copyItemPlan` (`data/database/item_copy.dart`), shared by every
  duplicate so a new column reaches them all at once.
- **What is done to a whole run is done on the run's label** — the ⋮ menu on the group band
  (`_GroupMenu` in `widgets/timeline_tile.dart`): *Rename group*, *Move group to…*,
  *Copy group to…*, *Ungroup*, *Delete group*. The unit an act applies to is the unit it is
  offered on, the way a decision's acts sit on the decision card; a member's edit form is where
  that *entry* is changed, and it cannot name the run standing above it. So all five live here
  **only**, and the grouping section of a member's sheet keeps just what is about that entry's
  own membership — group with next, remove from group. The name and the dissolving were the last
  two to move: both act on the run, yet were reached through whichever member you happened to
  open, which is an accident deciding where an act is performed from. Delete could not have
  lived there in any case, since it deletes the entry the form is editing. Ungrouping sits
  directly above deleting because it is the harmless half of the same question, and the delete
  dialog says as much in words — a way out named in a warning has to be within reach of the door
  it warns about, not two levels down in a member's form. Delete is also the act that had no path
  at all: deleting a run entry by entry dissolves the group only once one member is left, and
  `_dissolveIfDegenerate` then *rescues* the shared ticket onto that survivor, so a journey
  removed leg by leg left its fare behind on the last leg standing. `GroupDao.deleteGroup` is
  therefore the mirror image of `dissolveGroup`: the entries go, and with them the money —
  each member's own costs by cascade, the shared one with the group — since a ticket is not
  still paid for once every leg it covered is gone. Destructive, so it asks first, and the
  question says that ungrouping is the way to keep the entries.
- **Duplicating an *option* is in-place, not clipboard** (`AlternativeDao.duplicateAlternative`,
  the decision card's ⋮ menu): the "same as B, but…" third option. It adds an **unchosen** copy
  of the option on screen (the set already has its one chosen), cloning the option's internal
  grouping into fresh groups (a group is part of what the option *is*) but — as everywhere — not
  its costs. Moving a whole decision to another day, or flattening one option's contents out
  elsewhere, are deliberately *not* built.
- **A checklist travels by picker, not by hand** (`ChecklistDao.moveChecklist` / `copyChecklist`,
  offered from the card's overflow menu). Same two-step frame, different second step, because a
  checklist's destinations are just *the trips* — a short flat list that names itself, where an
  itinerary entry's are every day × every option. The rule that governs the money governs the
  ticks: a **copy arrives unticked** (a tick records that this was packed, on that trip), while
  a **move keeps them** — it is the same list, relocated. Copying last trip's packing list into
  the next one is what the feature is for, and a list is only reusable empty.
- **"You are here"**: a day is an ordered *list*, not a time-scaled axis (times are optional),
  so there is no offset to place a now-line at — only a slot. `features/itinerary/now_marker.dart`
  (pure) answers, for today's blocks and the current minute, either *this block is under way*
  (marked with a `NowBadge`, a red rail node, and a tinted tile) or *the line goes here* (a
  `NowLine` between two blocks, after the last block that is behind us). The same rule runs a
  second time *inside* a decision that is under way (`nowMarkerForItems` over its chosen
  option): a decision spans its option whole, so when now falls between two of that option's
  entries the day draws no line — the boundary is inside the card, and so is the line.
  Untimed entries stay
  *ahead* of the line unless something timed after them is already past — we cannot know when
  they happen, and claiming they are done is the guess that would make the mark lie. An
  **overnight** entry's end is on a later day, so `itemSpan` measures it on the entry's own
  minute line (`entry_times.dart`), past 1439, rather than letting `end < start` collapse the
  span to a moment: without that, a night train reads as finished the minute it departs, and
  the traveller sitting on it is told the journey is behind them. A decision
  is timed by its **chosen** option only. The mark is drawn *inside* the tile/card, never as an
  extra list child: the day is a `ReorderableListView` indexed by its blocks. `core/clock.dart`'s
  `nowProvider` ticks it on the minute; today's day header carries `Today · HH:mm` so a collapsed
  day still says where we are, and `TripDetailScreen` scrolls today into view on open.
- **Costs of unchosen branches are shown but never counted.** An item is *live* when it is
  loose or in the chosen branch; a cost counts when it is trip-level, on a live item, or on a
  group with a live member. The rule lives once, as a SQL predicate in `CostDao`
  (`_countsTowardTotals`), and is applied by `watchCountedCostsForTrip` (trip header + stats)
  and `watchTotalsByTrip` (overview cards); `watchCostsForTrip` stays unfiltered so the
  timeline can price every branch. Its Dart mirror for items is `features/itinerary/live_items.dart`
  (`liveItems` / `chosenBranchIds`), used by the timeline and the home widget. `computeTripStats`
  is deliberately left untouched by all this — it still sees one row per counted cost.
- **Planned vs. actual times.** An item carries two pairs: `startMinutes`/`endMinutes` are
  what was *planned* (a leg's departure/arrival), `actualStartMinutes`/`actualEndMinutes`
  what really happened. Both are optional and each end is compared with its own counterpart,
  so a leg that left late but has not landed yet runs from its actual departure to its
  planned arrival. What is *shown* is decided once, in the pure
  `features/itinerary/time_marks.dart` (`timeMarks`): the **planned** range, each end
  carrying its miss as a signed `(+15)` / `(−5)` (`formatSignedMinutes`; red late, green
  early or on time). The actual time itself is never printed — plan plus delta already says
  it, and the plan is what the day is judged against. Two renderers paint that one rule:
  `widgets/item_times.dart` (colored spans) and the home widget (see below). An actual time
  outranks its planned one in `now_marker.dart`, though: "you are here" is a claim about the
  day as it is going.
- **An entry ends on a day of its own** (`ItineraryItems.endDayOffset`, v40): how many days
  after its `date` the end falls, so a night train is 1 and a journey through two nights 2.
  It replaced the boolean `spansNextDay`, which could say "the next day" and nothing further.
  A count and not a second date, because the entry stays anchored to the day it starts on —
  that is where it is planned, dragged and counted — and an offset travels with that day
  through every move, copy and routine rebase, where a second date would have to be moved
  beside it at each of them. **Every reader places the times through
  `features/itinerary/entry_times.dart`**, which puts all four on one minute line counted from
  midnight of the start day. Before it the same fact had three answers: the now-marker read
  the flag, the transport statistics guessed "next day" from an end before its start, and the
  `.ics` export read neither and dropped the end. An **actual** time carries no day of its
  own; it takes the day nearest its planned counterpart (`foldNear`, within ±12 h), so 00:10
  against a planned 23:55 is fifteen minutes late and not a day early. That is a heuristic,
  chosen over two more stored day counts that would each have needed a field in the form: a
  delay of twelve hours or more is read as the wrong day. An end with no plan stands on the
  end day. An end before its start **on its own line** is refused by the form rather than
  saved, and one picked there is answered by offering the next day — visibly, in the end-day
  field, and never the reverse, since a later end may still be meant for a later day. The v40
  migration and the `.tpt` importer apply the same rule (`endsBeforeStart` /
  `settledEndDayOffset`) to records written before a day could be given, which is what a
  hand-entered night train always was.
  **A later day shows what reaches into it** (`continuationsOn` in `day_blocks.dart`, drawn
  as a `ContinuationTile`): the arrival, with its delay, or "continues all day", above the
  day's own blocks and outside its `ReorderableListView`, since that list is indexed by the
  day's blocks and the entry is not one of them. A reference, not a copy: not draggable,
  carrying no costs (they are counted on the start day) and never exported twice. Live entries
  only, and a branch entry starts on its decision's day, the rule `buildDayBlocks` follows.
  "You are here" asks it too (`continuationHappening`, the clock moved onto the entry's line),
  so the morning a night train is due in says the traveler is still on it. The days an entry
  covers are part of the plan's days everywhere those are listed — the timeline,
  `routineDaysOf` / `RoutineDao.routineDays`, and what `widenToCover` is handed on an import
  — or the morning an overnight leg arrives in would be missing from a one-day trip, and a
  routine's day numbers would disagree between the timeline and the form's day field.

## Transport modes

- **Transport modes are a user-managed table**, not a fixed enum: a leg's `ItineraryItems.mode`
  is a foreign key into `TransportModes` (setNull on delete). The `TransportMode` enum (in
  `tables.dart`) is only the *catalog of built-ins* the DB is seeded with — each value's
  `name` is the `builtinKey` stored on its seed row, giving it a localized label and a default
  icon (`transport_mode.dart`). A row's label is its `name` when set, else its `builtinKey`'s
  localized label; icons come from the curated `kTransportModeIcons` set. Built-ins seed in
  enum order so a fresh row's id is its enum index + 1 — the fact the v20 migration relies on
  to repoint legacy legs. CRUD lives in `TransportModeDao`; the sharing bundle denormalizes a
  leg's mode to its portable key (built-in key or custom name), carrying custom icons in
  `TripBundle.modeIcons`.
