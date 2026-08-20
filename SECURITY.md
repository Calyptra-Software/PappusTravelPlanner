# Security Policy

## Reporting a vulnerability

Please don't open a public issue for something that could be used against people
before there is a fix. Two private routes:

- **GitHub** — the *Report a vulnerability* button on this repository's
  *Advisories* page, under the security tab.
- **E-mail** — calyptra-software@proton.me.

Either is fine; the first keeps the discussion attached to the repository. Say
what you did, what happened, and what you expected instead — a crafted file, a
link, or a request that triggers it is worth more than a description of it.

This is a spare-time project, not a company with an on-call rotation. You should
have an acknowledgement within a week. If you don't, assume the mail went astray
and try the other route rather than assuming you are being ignored.

## Supported versions

The most recent release, and only that one. There is a single line of releases
and no maintenance branch behind it: a fix ships as a new version rather than as
a patch to an old one. The version string is on the *About* screen — it is the
first thing worth putting in a report, because it names the build exactly
(e.g., `1.4.0+5`, build number included).

## What this app actually exposes

Worth stating plainly, because the attack surface of an offline app is small but
not empty:

**It reads files it did not write.** Two formats, both through a file picker or
the share sheet:

* A `.tpt` trip bundle, parsed by `TripBundle.fromJson`
  (`lib/features/sharing/trip_bundle.dart`).
* A `.gpx` track, parsed by `parseGpx` (`lib/features/map/gpx.dart`) using the
  `xml` package, and stored as packed coordinates — the file's markup is never
  kept and never re-read. A bundle may also carry an already-packed line, which
  `decodeTrackPoints` (`lib/data/database/track_points.dart`) reads back and
  which is therefore held to the same standard as the file it came from.

A malformed file of either kind should produce a clean refusal and nothing else.
Anything beyond that — a crash that leaves the database inconsistent, an import
that writes outside the trip it was told to create, a value that ends up
somewhere it is not escaped — is worth reporting.

**It opens databases it did not create.** On desktop the settings screen will
point the app at any `.sqlite` a file picker hands back, and the app writes to
it. The header check (`kApplicationId`) is a sanity check, not a security
boundary.

**It parses replies from two network services.** The connection search talks to
`https://api.transitous.org` (`lib/features/transport_search/data/motis_client.dart`),
and the map fetches tile images from `https://tile.openstreetmap.org`
(`lib/features/map/basemap.dart`). A hostile or compromised reply should not be
able to do more than produce a wrong or empty result, or a wrong picture.

**It accepts deep links.** `pappus://trip?id=N`, used by the Android home-screen
widget to open a trip.

**It reads the device's position, on request.** A map's locate button starts the
platform's location service and stops it again when the map is closed. The
reading is held in memory for as long as it is on screen — it is not written to
the database, does not go into a `.tpt` bundle or any other export, and is not
sent anywhere. See *What is deliberately not a vulnerability* below for what the
tile server does and does not learn from it.

## What is deliberately not a vulnerability

**The database is not encrypted.** It is an ordinary SQLite file, and being able
to copy it, open it, back it up, and carry it to another machine is the whole
premise of the app. Anyone who has the file has the trips in it. If that matters
for your threat model, the answer is disk encryption underneath, not something
this app can add on top without giving up what it is for.

**The exports are plaintext too** — `.tpt`, `.ics` and the PDF are all meant to
be handed to other people and other programs.

**There are no accounts and no server of ours.** Nothing to authenticate to,
nothing held anywhere but on your device.

**The connection search tells Transitous what it must.** A place query, a date,
and a time go to the routing service, along with a `User-Agent` naming the app
and linking this repository — its
[usage policy](https://transitous.org/api/) asks for exactly that. Searching a
connection without telling anyone where and when you want to go is not a thing
that can be built.

**The map tells OpenStreetMap which tiles it is looking at.** Opening a trip's
map requests the image tiles covering it, which means the tile server sees the
area you are looking at, along with a `User-Agent` naming the app and its
version — the [tile usage policy](https://operations.osmfoundation.org/policies/tiles/)
requires that identification. Tiles are cached, so panning back over ground
already seen asks for nothing. No coordinate of yours is ever *sent*: a tile is
addressed by a grid square, and which entries of your trip sit inside it is
something only your device knows.

**The map can show where you are, and tells nobody.** Pressing the locate button
asks the platform for the device's position; the mark it draws is the only thing
that happens with the answer. It is never stored and never transmitted — and in
particular it is not what the map is fetched with: a tile is addressed by grid
square, exactly as it is when the mark is off, so centering on yourself asks for
the same tiles as panning there by hand would. Nothing on the device is followed
in the background either: the request has no `ACCESS_BACKGROUND_LOCATION` behind
it, and the receiver is released when the map goes away.

**Nothing else leaves the device.** There is no analytics, no crash reporting,
and no telemetry of any kind, and the Android build asks for three permissions:
`INTERNET`, and — only when the locate button is pressed —
`ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`. Both of the latter are
declared so that the system dialog can offer the choice between an exact and an
approximate position; the app works either way.

## What happens after a report

I will confirm what you found, or explain why I think it does not hold. If it
does, the fix goes out in a release and the advisory says what was wrong and
which versions were affected. Tell me how you would like to be credited, or that
you would rather not be — either is fine, and neither is a condition.
