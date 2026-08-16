# Features

Pappus Travel Planner plans a trip day by day: where you go, how you get there, what each
part costs, and who travels. This page goes through that in order — what each
piece does, and, where the behavior is a decision rather than an obvious default, why it
works that way. The [README](../README.md) has the same list in a sentence each.

Everything described here happens on your device, against a single SQLite file that
belongs to you. Two things reach outside it: the connection search, which asks a routing
service about real timetables and writes the answer into your local plan, and the map,
which fetches its background tiles while you look at them. Neither sends anything about
your trip anywhere.

---

## Trips

### What is a trip and how to create one?

Adding a trip from the overview first asks what you are making: a **Trip** — "a trip on the
calendar, one day or many" — or a **Routine**, a reusable plan with no dates, described
[further down](#routines--a-plan-you-make-again). Pick *Trip* and the form opens.

A trip begins as a name, and that is the only thing it needs. Everything else is offered
rather than demanded: a **destination**, a **start** and **end date**, **notes**, an
**accent color** that marks the trip's card and its bar in the calendar, the
**Participants** coming along, and **Tags** to file it under. Any of it can be filled
in later — the same form reopens from the trip's own screen — or left out for good.

Dates are optional on purpose. A plan whose timing you have not settled is a trip with no
range, rather than a trip pushed into pretending it has one — put them in when you know
them, and everything dated adjusts around them.

What hangs off a trip is the rest of this page: a **day-by-day itinerary** of places and
transport legs, the **costs** those come to and how they divide among the people on it,
and any number of **checklists**.

A walk to the shops, a commute, a multi-day hike, and a fortnight in Rome are the same kind
of thing with different dates. Everything the app can do is open to all of them: the
twenty-minute errand gets the same itinerary, the same costs, and the same checklists as
the fortnight abroad, and you start planning straight away instead of first declaring what
sort of thing this is going to be. If you do want to tell a commute from a holiday,
[tags](#tags-are-your-filing) are how — in your own words, applied whenever
you feel like it, and only ever for your own sorting.

A one-day trip is simply one whose start and end fall on the same day, and the timeline
quietly drops its day headers when it is drawing a single day.

### Tags are your filing

You define the labels yourself — e.g., "walks", "bike", "ski tour", "cruise", "work", … —
and assign one or many of (e.g. "vacation" and "hiking") them to trips from the trip
form's **Tags** field.

The chip row above the overview list is where they are used and where they are kept. Tap a
chip to narrow the list to those trips, tap **All** to widen it again, and open **Manage
tags** from the same row to add one, rename it, give it a color, or delete it — a tag's
color is what makes a row of chips scannable.

They sit above the list rather than two taps deep inside a filter sheet because a filter
that is two taps deep stops being used, and then the filing that feeds it stops too.

Nothing ever *behaves* differently because of a tag. They can be renamed and deleted
freely, which is only safe because nothing hangs logic off them.

### The people you travel with

Names live in a list of their own rather than being typed afresh into every trip and every
expense. Add, rename, and remove them under **Settings → People**; a trip then picks its
participants from that list, and an expense picks its payer and the people it was for.

Mark one of them **"This is me"**, and the overview can show *my* expenses rather than
everybody's.

Renaming somebody follows them everywhere: every expense they paid is repointed, and
renaming one person onto a name that already exists merges the two. Removing somebody only
takes them off the list — expenses they paid keep naming them, because who paid is part of
what happened rather than a link that should quietly break.

### Routines — a plan you make again

A commute, a training ride, the yearly route to the cabin: keep it as a **routine** — a
plan that carries no dates of its own. Routines have their own screen and stay out of the
trip list, so something you do every week never crowds out the journeys you actually took.

Stamp one out onto a day whenever you want it on the calendar: tomorrow's commute planned
tonight, yesterday's added after the fact, any date you like. What you get is an ordinary
trip, free from then on to go however that particular day went.

Stamping one out copies the plan, the participants, the tags, and the checklists (arriving
unticked, because packing is something an occurrence does). It also copies the fare — the
one place a copy takes money with it, because a routine's cost is a *price*, "what this
ride costs", rather than a payment that happened. It arrives unpaid, and a routine's own
costs count toward no total, or the same fare would be charged twice.

A trip remembers which routine it came from: enough to ask before recording the same
routine twice on one day, and to filter the overview down to what a routine has produced.

### Finding and filtering trips

Search by text, and filter by status (upcoming / ongoing / past / undated), by tag, by
participant, by originating routine, or by date range. Sort by date, name, creation, or
total expenses. The search and filter buttons are in the main menu bar.

Every part of that except the text search is remembered across launches, so "only my
walks, newest first" survives closing the app. The text search deliberately is not: a
search is one act, which is why the app bar's close button throws it away.

The overview draws the same trips three ways, chosen from one menu in the app bar: the
**list**, a **month calendar** where each trip is a bar in its accent color spanning its
days, and a **map** of everywhere the visible trips go. Whichever you pick is remembered.

The map inherits the filter rather than having one of its own. Each trip is drawn in its own accent, the same color
as its card, so a tangle of routes still says which trip is which. Changing the filter
re-frames the map on what is left.

Tap a route or a place and the **trip** it belongs to comes up — its card, exactly as the
list draws it — and tapping that opens the trip. The unit here is the trip: with many of
them on one map, "which trip is that line" is the question, where a single trip's own map
answers the other one, about a single entry.

Where several routes lie on top of each other or run side by side — the same commute drawn
once per day you made it, or two trips sharing a stretch of road — the tap lists **all** of
them and you pick.

---

## The itinerary

### A day is an ordered list

Each day of a trip is a vertical timeline of two kinds of entry: **places** and
**transport legs** (walk, bike, ski, car, taxi, bus, train, tram, subway, ferry, flight, …),
each with optional times and notes. Days collapse and expand, and entries are reordered
by dragging.

Times are optional throughout, which is why a day is a *list* and not a scaled axis — an
entry without a time still has a place in the order.

### Transport modes

The transport modes are not a fixed list. Add, rename, re-icon, reorder, or remove them
under **Settings → Transport modes**; the built-ins are only the starting set, and a mode
you delete leaves its legs intact.

### One ticket, several legs

Adjacent entries can be **grouped** — the three trains of one journey, sharing one ticket.
A group is a single thing to the plan: it drags as a unit, it is priced once, and the
whole run can be moved, copied, or deleted from the label above it.

### Alternatives

Plan competing options for one stretch of a day. Alternatives can, e.g., be used to plan
different connections, transport modes, or activities. The decision sits in the timeline
as a card you swipe between; each option holds its own places, legs, and costs.

You make one out of an entry you already have: open it and press **Plan alternatives**,
which turns it into a choice with that entry as the first option; the card's ⋮ menu then
offers **Add option** for the next one, and each option can be given a name of its own.

Swiping only *browses*. To settle on one, swipe to it and press **Use this option**; the
one currently in force shows a **Chosen** badge in place of that button, so a glance at the
card says which way the day is going. Choosing is deliberately its own act rather than a
side effect of swiping — an option's money counts toward the trip only while it is chosen,
and no gesture should move a budget by accident. Every option's price stays visible side by
side under the card, which is the comparison a pager otherwise hides.

Only the **chosen** option counts toward the trip's totals, its expense split, the PDF,
the calendar export, and the shared bundle. An option you considered and dropped never
inflates the budget and never leaves the app. Afterwards you either choose what you
actually did, or clear the decision away with **Keep only this option**.

### Planned versus what happened

Every entry carries two pairs of times: what was *planned*, and — once you record them —
what actually happened. The timeline keeps showing the plan, with a green or red **+/−**
on each end saying how early or late it ran. The actual time itself is never printed:
plan plus delta already says it, and the plan is what the day is judged against.

Each end is compared with its own counterpart, so a train that left late but has not
landed yet runs from its actual departure to its planned arrival.

### "You are here"

On today's plan, the entry currently under way is marked with a badge and tinted, and
where the day has got to *between* two entries a red line sits in the gap. A decision that
is under way spans its chosen option whole, and the same mark runs a second time inside
the card.

Untimed entries stay ahead of the line unless something timed after them is already past —
we cannot know when they happened, and claiming they are done is the guess that would make
the mark lie.

### Moving entries around

Dragging reorders within one list. Crossing a boundary — to another day, or into one
option of a decision — is deliberately two explicit steps: *Move to…* or *Copy to…* picks
the entry up, and the destination's add-row then offers to put it down. The held entry
stays visible, dimmed, until you place it.

A **copy takes the plan, not the money**: a cost records a payment that happened once, and
duplicating it would invent money inside the settle-up.

### What the legs add up to

The bar-chart button in a trip's app bar opens its **Statistics**, which has two tabs:
**Expenses** and **Transport**. The transport one counts the traveling — for each mode, how
many legs used it and how much time they came to, most-used first — and a **Legs** / **Time**
switch decides which of the two the bars are sized by. The overview's overflow menu holds
the same thing across every trip at once, as **Overall statistics**.

Both of the app's time axes are kept side by side — what was planned, and what was
actually recorded — so a trip's timetable can be held against the day it turned into. And
as with the money, only live entries count: an option you considered and dropped never
shows up here either.

---

## Connections from a real timetable

This is the app's one online feature. It asks [Transitous](https://transitous.org), a
community-run MOTIS instance built on OpenStreetMap and open timetable data from operators
around the world — local public transport, long-distance trains, buses, and more. No
account, no API key, and nothing to sign up for.

### Searching

Search *from* / *to* with live stop suggestions, set a departure or an arrival time, and
compare the results by time, duration, and number of changes, with live delays where the
service publishes them.

The search options are remembered for next time and cover what actually decides whether a
connection is usable: which **means of transport** may be used, the **shortest change**
you want planned for, **how fast you walk** (or cycle), whether you have a **bike** with
you and whether it comes on board, whether the journey must be **step-free**, how long you
spend **getting to and from stops**, and the **most changes** to accept — down to *direct
connections only*, so a search never books you a three-minute sprint across a terminus. A
**via stop** can be required as well, with a minimum time to stay there.

Results come back as a window around what you asked for; **earlier** and **later** load the
departures either side onto the same list. Tapping one opens it in full — leg by leg, with
platforms, the length of each change, and every stop the service calls at on the way. A
stop the train is *skipping* is struck through rather than given a reassuring time, because
a partially canceled train goes on publishing the planned departure for stops it will pass
straight through.

You can also search a connection with **no trip behind it at all**, straight from the
overview — "when is the next train?" is asked long before there is a trip to hang the
answer on. Nothing is stored unless you then file the result into a trip by name.

### What an import keeps

Importing writes the journey as that day's transport legs, bundled under one shared
ticket, carrying each leg's line and train number, direction, platform, and stop list, and
handling overnight legs that arrive the next morning.

An imported journey reads back exactly the way it did in the search, so the walking
transfer between two trains stays *the change* rather than becoming another leg.

### Live times

Each imported leg gets a **refresh** button that pulls its current real-time departure and
arrival and updates its stops along with its ends — one tap, one leg, never on a timer.
The result surfaces through the planned-versus-actual marks above, and says so plainly when
the service has been **canceled**.

### Asking the timetable again

A journey can be looked up again later from the sheet that shows it, and a single leg from
its own card — because the questions differ. "Is there a better way to make this journey"
is asked of the whole run; "the train in came twenty late and the connection is gone" is
asked of the rest of it, and only that leg is replaced.

Either way it opens the ordinary search form, pre-filled — the question is rarely quite the
old one, and a list of departures is what a traveler picks from. The shared ticket, the
group, and the entry's place in the day all survive the swap.

### A routine's plan becoming a real connection

Stamping out a routine that contains a searched journey copies the plan first — instant,
offline, correct on its own — and *then* looks the connection up for the day it now sits
on, offering the day's actual departure to swap in.

Declining it, finding nothing, or having no signal all leave the copied plan standing. And
"no train" is never reported when it was "no network".

---

## The map

Every trip has a map, reached from the map button on the trip screen. Places appear as
pins and transport legs as lines between their ends.

Two things it deliberately does not do. A leg is drawn **only when both of its ends have a
position and nothing is drawn between one place and the next. On today, the entry that is under way is marked.

### Where the positions come from

An imported connection brings the coordinates of its stations with it, so a trip planned
through the connection search appears on the map without you doing anything.

Everything else you place yourself. Any place, and either end of any transport leg, has a
**Coordinates** field beside its name with a map button: the map opens, you tap the spot,
and *Use this point* writes it down. Tapping again moves the marker. The field then shows
what was written and can be cleared again on its own.

The connection search offers the same thing: its **From** and **To** pickers list *Choose on
map* above the search results, for an address the geocoder does not know or a spot with no
name at all. (A via stop is the exception — the routing service only accepts stations
there.)

Placing both ends of a leg has a side effect worth knowing: a leg you entered by hand can
then be looked up in the timetable, because the app finally knows where it starts and ends.
And moving an end that *came* from a search makes the app forget which station the search
used — it now goes by the point you chose.

### Asking a marker what it is

Tap a pin or a transport badge and the entry behind it opens: its name, where the leg runs
from and to, its times with the same green and red `+/−` the timeline shows, any note on it,
and the coordinates themselves. A map can only draw *where* something is; everything else
about it lives in the entry. Editing is a further tap, in the same form the timeline opens.

### The line you actually followed

An entry draws as a straight segment between its ends, which is the best a plan
can say. If you have a **GPX** file open the leg and *Import GPX…*: the map then draws
that line instead of the straight one.

A connection imported from the search brings its own route with it: the map then
draws the train along its line and the walk around the corner, rather than a
straight line between the stops. Those are drawn **dashed**, because they are
what the router computed and not what you recorded. Importing a GPX onto the
same leg shows only the imported track.

A line is part of the plan, so it **travels with a copy** — duplicate the leg,
stamp out the routine, share the trip, and it comes along. A `.tpt` bundle
carries it, which is what keeps that export lossless.

### Where the background comes from

The map draws [OpenStreetMap](https://www.openstreetmap.org/copyright) tiles. Tiles already fetched
are cached so panning back over ground you have seen does not need to download new tiles again.

---

## Money

### Costs

Attach a cost to any place, any transport leg, a whole shared ticket, or the trip as a
whole. Each carries an amount, a currency, a category, who paid, and who it was for.
Amounts may be negative, for a refund or an income.

Each one also carries an **Already paid** tick, which separates money that has actually
changed hands from what you have so far only planned to spend. The statistics report both
sides, as an amount and a share of the trip: how much is paid, and how much is still open.

Categories are your own. There is no fixed set of "food / transport / accommodation" to
squeeze a trip into: they are a reusable list of labels, each with an icon of its choosing,
kept under **Settings → Expense categories** and shared across every trip.

Per-entry subtotals and a per-trip total, grouped by currency, are shown as you go, and the
overview can be scoped to *my* expenses.

### Your own currencies, with rates

The four built-ins (€ / US-$ / £ / CHF) are a starting list. Add, rename, re-symbol,
reorder, or remove currencies in **Settings → Currencies**, mark one as the **base**, and
give the others a rate against it (e.g., "1 USD = 0.92 EUR").

Where a total spans several currencies and every one of them has a rate, the base-currency
equivalent appears *beside* the exact figures — `€349.90 · US$50.00 ≈ €394.90` — never in
place of them, and never from a partial set of rates. Rates start unset, and the app
declines to convert rather than guess.

### Statistics, splitting, and settling up

A per-trip statistics screen breaks spending down by category and by person — paid versus
fair share — and suggests a minimal set of payments to settle up.

This is always computed **per currency, with no conversion**: what you owe is what was
actually spent, not a figure derived from a rate you typed in.

A cost splits among the people it was for, falling back to everyone on the trip when you
have not said.

### Recording the money handed back

A suggested payment can be booked as a **settlement** — from one person to another, no
category, no split — straight from the settle-up list or from the trip's general expenses.

It moves the two balances and nothing else. The trip's total, its expense count, and its
category breakdown stay untouched, so "paid" still means "spent on the trip" while the
settle-up list shrinks by what has already been repaid.

---

## Checklists

Any number of named checklists per trip — e.g., a packing list, a to-do list, one per person —
with reorderable, tickable items and collapsible cards.

A checklist moves or copies to another trip from its overflow menu. A **copy arrives
unticked**, because a tick records that this was packed on *that* trip; a **move keeps the
ticks**, because it is the same list, relocated. Copying last trip's packing list into the
next one is what the feature is for, and a list is only reusable empty.

---

## Sharing and export

### A whole trip, losslessly

The share button on a trip's screen offers three ways out, of which the first is this one:
**Share trip** writes a self-contained `.tpt` bundle — handed to the Android share sheet, or
saved as a file on desktop. (The other two, **Export as PDF** and **Export to calendar**,
are described below.)

To bring one in, use **Import trip** from the overview's ⋮ menu and pick the file. On
Android you can skip that: a `.tpt` shared to Pappus, or simply opened from a file manager
or a mail attachment, goes straight into the same import.

Either way the bundle recreates the trip with its itinerary, decisions, groups, costs,
checklists, and tags. A **routine** shares just as well as a dated trip.

The format is independent of the local database's IDs, so sender and recipient need no
matching data: a currency or a transport mode the recipient does not have is created from
the bundle, and one they already have keeps their own symbol and rate. A bundle only stamps
the format version the trip actually needs, so an older copy of the app keeps reading what
it can.

This is the only export that round-trips.

### A printable PDF

Turn a trip into paper for people who do not use the app. A header with the dates, notes,
and participants is always printed; beyond that you tick which of the **itinerary**, the
**expense summary** (per-currency total, breakdown, and settlements) and the **checklists**
to include.

Each row says what it would print — e.g., "5 days · 18 entries" — sections this trip has nothing
for are grayed out rather than offered as a switch that yields no pages, and the choice is
remembered for next time.

### Into whatever calendar you already use

Export a trip as a standard `.ics` file: one event per place and transport leg, plus an
all-day banner for the trip itself.

Times are **floating**, so 09:30 stays 09:30 wherever the file is read — the app stores no
timezone at all, which is exactly what iCalendar's floating time means, so nothing is
converted and nothing can be converted wrongly. What a calendar cannot hold is dropped
rather than faked: an untimed entry becomes an all-day event, and costs ride along as
readable description text.

---

## Your data

Everything lives in **one SQLite file**. Not a proprietary container — a standard database
you can copy between devices and platforms and open with any tool that reads SQLite.

On desktop you can point the app at a database anywhere, or create a new one, and the
choice is remembered across launches. On Android and the web the file lives at a fixed
location, so there you import and export it instead. On the web the data sits in browser
storage (OPFS, falling back to IndexedDB).

There is no account, no server, and no sync. Nothing is uploaded, and nothing about your
trips leaves the device unless you export it yourself.

---

## The app itself

**Languages and theme.** English and German, and a light / dark / system theme, both
switchable in-app. Dates and money use locale-correct formatting, and the connection search
asks the routing service for its results in the app's language too.

**Android home-screen widget.** Your current or next trip, a countdown, and today's plan
with the same planned-time-plus-delay marks the timeline uses. Tapping a row opens that
entry.

**Offline-first.** No account, no server, no network required. The connection search is the
only thing that needs an internet connection, and what it brings back becomes part of your
local plan like anything else.
