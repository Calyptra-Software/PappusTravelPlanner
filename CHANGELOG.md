# Changelog

Notable changes per release. Dates are release dates; the git tags carry the
exact commits.

## Unreleased

- **An entry can end on a later day, and that day shows it.** The form has an *Arrives* (or
  *Ends*) field for the day, offered as the next day as soon as the end is before the start,
  and a journey can run through several nights. The timeline marks such an end with **+1**
  (or **+2** …), and the day it arrives on shows the arrival at the top, with its delay and
  "you are here" while you are still on board.
- **A delay across midnight reads as a delay.** A train planned for 23:55 that leaves at
  00:10 is fifteen minutes late, no longer almost a day early.
- **Overnight entries keep their end in the calendar export.** An event ending the next
  morning used to lose its end time.
- **A trip across a daylight-saving change no longer shows one of its days twice.**
- **A trip shared with a leg of two or more nights needs this version to be opened.** One
  night stays readable by older versions.
- **The line down the left of a day runs straight through groups and decisions.** It no
  longer shifts sideways inside a group or a decision, and it no longer breaks at their
  headers, a group's shared cost, or a decision's option pills.
- **A leg can keep its coordinates without a line between them.** Its list of lines
  on the map now has a *Straight line* row with the same eye as a recorded line, in
  the leg's form and in the sheet a tap on the map opens. Switched off, the map draws
  no line for that leg unless one of its other lines is on.
- **A color picked in a map entry's sheet is no longer undone by *Edit*.** The form
  opened from there used to start from the color the entry had before, and saving it
  put that color back.
- **A connection can be searched from where you are.** The **From** and **To** pickers offer
  *Use my position* beside *Choose on map*, which was the old route to the same thing by way
  of the map and its locate button. The field then shows the coordinate. Not for a
  via stop, where the routing service only accepts stations.
- **The map remembers that you want to see where you are.** The locate button used to
  have to be pressed again on every map, which is a lot of pressing when you move
  between a trip's timeline and its map. Now the mark comes back on its own, without
  moving the camera off what the map was showing. While it is on, a press centers the
  map on you and a long press switches it off again — after which maps open without the
  mark, as before. A map that starts the receiver this way never asks for the location
  permission: that still only happens on a press.
- **The photo gallery turns with the arrow keys**, and with two chevrons that appear
  when there is a mouse. Swiping still works; it is just hard to aim on a trackpad.
- **In the browser, exporting the database downloads the file.** The button could stop
  without a word: the database's own shutdown never answered and the export waited for
  it for good. It now carries on after a few seconds, and the copy is handed to the
  browser's downloads directly rather than through a route that dropped it.
- **In the browser, recorded lines and the world map are drawn again.** A track showed
  nothing on the map and the countries map reported an error instead of drawing. Only
  the reading was affected: a line imported in the browser was always stored correctly
  and has been drawing on every other platform throughout.
- **A connection search no longer shows "Canceled" for a journey that runs.** The
  router sometimes marks a walk between two stops as canceled; only a canceled train,
  bus or other service now marks a connection.

## 1.12.0 — 2026-09-18

- **An expense's payer can invite people.** Tap a name under "Paid for", or tick
  "Invited by …" for everyone at once: an invited person owes nothing for it, and the
  balances show who was invited to how much.
- **Tapping a photo on the map shows it full screen**, also when it is the only one
  there. Its details are behind the gallery's ⋮ menu.
- **Importing a recording: a handover can be moved again right away.** Chips under the map
  choose which handover the next tap places, so a badly placed one no longer has to wait
  until all the others are placed.
- **A new transport entry starts out as a walk** instead of a train.
- **Linux and Windows builds are released too**, next to the Android APKs: an AppImage
  and a `.tar.gz` for Linux, and a `.zip` for Windows. The Linux `.tar.gz` carries an
  `install.sh` that adds a menu entry and an icon for your user, and an `uninstall.sh`
  that removes them again.
- **The connection search makes room for its results.** After searching, the form folds
  into a one-line summary of what was searched, so more connections fit on screen; tap it
  to change the search.
- **Setting a photo's position opens the map where the trip is**, showing the trip's other
  places as context, instead of starting on the whole world — the same as setting an
  entry's position.
- **A settlement can be marked as a reimbursement from outside the group**, such as an
  employer's allowance. It no longer shows the receiver owing the source money, and the
  statistics show how much was reimbursed and by whom, also across all trips.
- **The trip list says how many trips match the search and filters**, e.g. "12 of 40
  trips", with a button to clear the filters while any is active. The routine list has the
  same line.
- **The overall statistics can be narrowed to some of the trips** — by status, dates, tag,
  routine, or participant. The filter is separate from the trip list's and starts over each
  time the statistics are opened.
- **Routines no longer count twice in the overall statistics.** The transport tab counted a
  routine's legs on top of the trips made from it, and the countries tab its places; the
  expenses already left routines out.
- **The Android app declares five fewer permissions.** A library behind the home-screen
  widget added a wake lock, network state, start at boot, a foreground service, and one
  internal permission. The app used none of them, and they are now removed.

## 1.11.4 — 2026-09-06

- **Nothing changes in the app.** The three per-ABI builds are numbered by a different
  scheme, at F-Droid's request: `10 × build number + 1|2|3` rather than Flutter's own
  `1000|2000|4000 + build number`. Android will not install a build whose number is lower
  than the installed one, and the new scheme counts smaller — so the build number jumps
  from 15 to 402, which is the first value that leaves every one of the three above what
  1.11.3 published. The version you see is unaffected.

## 1.11.3 — 2026-09-05

- **Nothing changes in the app.** The Android build no longer writes Gradle's dependency
  tree into the APK's signing block, where it sat compressed and encrypted with a Google
  Play signing key — data nobody but Google could read, inside an app whose whole point is
  that anyone can check what is in it. Nothing ever consumed it; there is no Play Store
  listing here. F-Droid's APK scanner refuses such a block outright, which is how it was
  found.

## 1.11.2 — 2026-09-05

- **Nothing changes in the app.** F-Droid reads a listing — the description, the
  screenshots, the icon — out of the source tree of the release it builds, and 1.11.1 was
  tagged before that listing existed in this repository. This release carries it.

## 1.11.1 — 2026-09-05

- **Nothing changes in the app.** This release exists so that two builds of the same source
  come out byte for byte identical, which is what lets somebody else check that a published
  APK really was built from the code in this repository.

## 1.11.0 — 2026-09-04

- **This version installs fresh rather than as an update, and you should export your data
  before you install it.** From this release on the app is signed with a new key, and
  Android identifies an app by the key that signed it — so it refuses to install this
  version over the one you already have, reporting a conflicting package rather than
  anything wrong with the download.

  In order: *Settings → Database → Export database…*, and save the file somewhere you will
  find it again — it is a single file and it holds your photographs, so it may be large.
  Check that it is really there before going on. Then uninstall the app, install this
  version, and *Settings → Database → Import database…* to bring everything back.
  Home-screen widgets have to be added again afterwards. Nothing on Linux, Windows, macOS
  or the web is affected — this is an Android install mechanism and nothing else.

- **The Android app no longer contains any Google Play Services code.** Where the device
  is now comes from Android itself rather than from Google's location library, which was
  being linked in by the plugin the app uses for it. Nothing about the locate button
  changes, and nothing is asked of you that was not asked before — the same two location
  permissions, still only when you press it. From Android 12 onwards the system's own
  combined provider is asked instead, with the same accuracy and the same distance filter
  as before, and a position takes as long to arrive as it did — measured on a phone, four
  runs, the same eight to eleven seconds either way. What you may notice is that the mark
  now appears only once there is a real measurement: where Play Services or microG are
  installed, they used to draw a remembered position first and correct it a second later,
  which was sometimes a hundred metres out. On Android 11 and older, and on any phone
  whose system offers no combined provider of its own, the position now comes from GPS
  alone and a first fix can take longer than it used to. It is also what
  makes a listing on F-Droid possible, which does not accept apps carrying proprietary
  code.

- **A photo can bring the place it was taken, on Android too.** Android takes a photo's
  coordinates out before handing it to an app, so one attached here arrived with no place
  and a note saying why. *Settings → Photos → Read where a photo was taken* asks for the
  permission to read them, and it is off until you turn it on. Turn it off again and photos
  go back to arriving without their place at once — Android itself keeps the permission
  until you revoke it on the app's own page in the system settings, and the app offers you
  that screen when you switch off. Nothing else about attaching a photo changes: the same
  picker, and the picture that is stored is still the scaled copy with everything else out
  of its metadata. Desktop, the web and Android 9 and older never lost the position and
  have no such setting.
- **The settings screen stays still while you scroll it.** Scrolling back up through it
  jumped up: the managed lists — cost reasons, currencies, transport
  modes, people — were thrown away once you had scrolled past them and drew themselves
  empty for a moment on the way back. The line saying what the database weighs no longer
  grows into place after the screen has opened, either.

## 1.10.0 — 2026-08-30

- **Picking more than one file no longer breaks an import.** Marking two files at once
  in the database import, the trip import or the track import crashed instead of importing
  one of them: the dialogs let you select several while the code behind them expected
  exactly one. They ask for a single file now, which is what they always meant. Attaching
  photos and documents is unaffected — taking several at once is the point there.

- **The map picker's grey dots can be seen in a dark theme.** The dots marking where the
  trip's other positions already are were tinted by the app's theme and half transparent,
  which over the map's pale tiles left them all but invisible in dark mode — the layer read
  as missing rather than as faint. They are drawn in the map's own colors now, opaque and
  ringed in white, like every other mark on that map.
- **Choosing a point on the map for a connection opens where the trip is.** *Choose on map*
  in the connection search used to start fully zoomed out, on the whole world, even for a
  trip whose entries already say which part of it you are traveling in — while the position
  fields in an entry's own form have always opened on those entries. Now both do. Once one
  end of the journey has been named, the map opens on that end as well, which is also what a
  search made from the overview, with no trip behind it, has to go on.
- **Places that hide each other are gathered, on both maps.** The same commute drawn once
  per day you made it put twenty pins on one spot of the all-trips map, and a hotel returned
  to every evening puts two on a trip's own — all but the top one impossible to tap, since a
  pin covers whatever is beneath it. They now come up as one pin with a count and come apart
  again as you zoom in, the rule the photographs already follow. Tapping a gathered pin lists
  what it holds — the trips on the overview's map, the entries on a trip's — and you pick.
  The pin keeps the color every place under it would have had and turns grey only where they
  differ; an entry that is under way still turns it red.
- **A trip's lines can be saved as a `.gpx`.** The trip's ⋮ menu writes every line its entries
  carry in the format every mapping tool reads — recordings as tracks, the routes the
  connection search computed as routes — so the pieces one import was cut into, and the routes
  that exist nowhere else, can be opened somewhere other than here. It is not the file you
  imported: elevation and timestamps were dropped on the way in and cannot be invented, so
  what comes out is the geometry, the day, and the mode. Routines can be exported too.
- **A line can be put away instead of deleted.** Every line on an entry now carries an eye:
  by default a recording is drawn and a route the search computed is not, and either can be
  overruled
  Each row also says whether its line is being drawn at all.
- **Tapping a line on the map says which line it is.** A leg that carries several — a
  recording in two segments, a route beside a recording — now draws each of them as itself,
  and a tap opens the entry with its lines listed and the one you touched marked. Where two
  entries run over the same ground, the tap lists both rather than picking one for you.
- **The lines on a leg can be removed one at a time.** An entry often carries several — a
  recording that stopped and started again arrives as one line per segment, a second import
  adds to them, and a connection from the search brings its computed route. The entry's form
  used to say only how many there were, over a single *Remove* that took all of them. Now
  each line is a row of its own, saying its name, where it came from and how far it runs,
  with its own remove button beside it; *Remove all* is still there once there are two.
- **The routines can be searched and filtered too.** The routine list now
  carries the overview's own controls: search by title, destination or notes, a
  tag bar above the list, a filter sheet for tags and participants, and a sort by
  name or by when you made it. Not statuses or a date range — a routine has no
  dates. As on the overview, everything but the text search is remembered across
  launches, and the two lists are filtered apart: narrowing the routines never
  moves the trips.
- **A sheet no longer reaches the top of the screen.** The big ones — filter and
  sort in the trip overview, the connection search and its options — used to put
  their drag handle in the strip Android pulls the notification shade down from,
  so the only way back was the back button. Every sheet in the app now stops
  below the status bar and leaves a strip of scrim above itself: the handle can
  be dragged, and a tap beside the sheet closes it.
- **The countries map opens on the whole screen.** A button on the map puts it
  there with the list out of the way; the same button, the back button and the
  back gesture all bring the list back. The camera travels in both directions,
  so a region you zoomed in on fullscreen is where the small map is looking when
  you return.

## 1.9.0 — 2026-08-23

- **Photos and files on a plan.** A photograph or a document can hang on a single
  entry, on a group, or on the whole trip — the same three things a cost hangs
  on. They live **in** the database, not beside it, so a copy of that one file is
  still a copy of everything, and a `.tpt` bundle carries the bytes and stays
  lossless.
- **Which of the two a file becomes is the door it came through**, never the
  decoder: *Add photo* bounds and re-encodes the picture with a thumbnail beside
  it, *Add file* keeps the bytes exactly as they arrived, up to 20 MB — so a
  ticket sent as a `.png` can be filed under documents and handed on unchanged.
- A photo keeps the **position** the camera recorded, lifted into a field of its
  own and clearable there, and loses the rest of its EXIF to the re-encoding. A
  document is not re-encoded and so keeps its metadata; `SECURITY.md` says both.
- An entry counts its **photos and its documents apart**, because they are two
  acts: the first opens that entry's pictures as a gallery, the second lists its
  files. A trip's own photographs are a gallery too, reached from a band of
  thumbnails on the trip screen that folds away and stays folded.
- **One amber star does the cover.** Star a picture in the gallery and the trip's
  overview card shows it; unstar it and the card shows none. Until then the card
  shows the first photograph in gallery order, with the star filled on it.
- **Photographs are on the map** where they carry a position, drawn as their
  thumbnail in the color of the entry they hang on; those that would hide each
  other are gathered under one thumbnail with a count and come apart as you zoom
  in.
- The PDF gains a **Photos** section, off until you tick it, with the size beside
  the count. **Settings → Database** says what the file weighs and how much of it
  the attachments account for, and space freed by a deletion comes back on its
  own.

## 1.8.0 — 2026-08-21

- **Which countries you have been to**, as a third tab of the statistics: the
  world drawn from bundled outlines with the ones you have stood in filled in,
  and underneath a list by continent with how many of each you have been to, as
  a share and a worldwide total — out of the 195 states of the United Nations,
  with a dependency counting for the state it belongs to. It is counted from
  where an entry stands and never from the line between two, so a flight does
  not claim the countries it passes over. The map draws no tiles at all, so it
  needs no connection — the outlines are Natural Earth, public domain, credited
  on the license page.
- The countries map zooms **two steps further in**, which is what it takes to see
  Liechtenstein or Monaco, and Antarctica is drawn the right way round — the sea
  south of 60° was filled in and the continent left empty.
- A country can also be **ticked by hand** — in the list, or by tapping it on the
  map, which is the only way to tick a territory like Greenland — for somewhere
  you went before the app knew about it; it counts and draws exactly like one
  worked out from a trip. Which is also the answer to the very small countries:
  Monaco and the Vatican sit too far from their own generalized outlines to be
  recognized from a position.
- **Everything done to a group is now done on the group.** Its name and
  *Ungroup* move from the edit form of whichever member you happened to open to
  the ⋮ menu on the run's own label, beside moving, copying and deleting it.
  Ungrouping sits right above deleting, where the warning that ungrouping is the
  way to keep the entries can be acted on. A member's form keeps what is about
  that entry: group with next, remove from group.
- **The map can show where you are.** A locate button on a trip's map, on the
  all-trips map, and in the map picker — where it also takes that reading as the
  point being picked. One press asks for the permission, starts the receiver and
  centers the map once; after that the mark moves and the camera does not, so a
  map panned ahead stays where it was put. The reading is drawn with its accuracy
  as a circle around it, in a blue of its own so it cannot be mistaken for the
  plan's own "you are here".
- The position is **never stored and never sent** — not to a row, not into a
  `.tpt` bundle or any export, and not to the tile server, which is addressed by
  grid square exactly as before. It is the app's first runtime permission, asked
  for on the button press and at no other moment, and the receiver is released
  when the map is left. Nothing runs in the background.
- **A GPX import covers one path through the plan.** The entry picker lists a
  day as the timeline reads it, and each decision contributes a single option,
  switched on the decision's own row — which never settles it, and says so when
  it points at a road not taken. Listing every option at once printed the same
  station two and three times, and divided the recording at the wrong places.

## 1.7.0 — 2026-08-18

- **One recording is divided among the entries it covered.** A GPX file is made
  in one go and a plan is not, so an import cuts the line where one entry handed
  over to the next. Only legs get a stretch, a place between two legs supplies
  their handover — and a place with no position is filled in from it. Every
  handover nobody could supply is asked for, one tap on the line, with the
  division drawn while it is being decided.
- **An entry carries its own color on the map** (schema v30): a leg's line or a
  place's pin, chosen against the picture it lands in. Null still means the
  trip's accent. It travels with a copy, in a `.tpt` bundle, and through a
  re-route — but "under way" still outranks it, since red must not be hidden.
- **An end the router was given as a coordinate is named and dated.** A picked
  address, a point tapped on the map or an imported leg's own ends come back as
  `START`/`END` with no timezone at all. Those were being read as statements: the
  placeholder went into the timeline as the station's name, and the missing zone
  as UTC, which showed *and stored* a Hamburg walk two hours early.
- **The timetable is asked only about runs it can answer for.** Placing both ends
  of a campus walk on the map used to enlist it in a routine's unattended lookup,
  which asked about it every morning. A run of nothing but street legs is left
  alone; asking is still one tap away where a human is watching.
- **A re-routed connection draws along its line too**, not as chords between its
  stops — which is most visible in a routine, where re-routing is the ordinary
  act and adding a run the rare one.

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
