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

**It reads files it did not write.** A `.tpt` trip bundle arrives through the
share sheet or a file picker, and `TripBundle.fromJson`
(`lib/features/sharing/trip_bundle.dart`) parses whatever is in it. A malformed
bundle should produce a clean refusal and nothing else. Anything beyond that —
a crash that leaves the database inconsistent, an import that writes outside the
trip it was told to create, a value that ends up somewhere it is not escaped —
is worth reporting.

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

**Nothing else leaves the device.** There is no analytics, no crash reporting,
and no telemetry of any kind, and the Android build asks for one permission,
`INTERNET`.

## What happens after a report

I will confirm what you found, or explain why I think it does not hold. If it
does, the fix goes out in a release and the advisory says what was wrong and
which versions were affected. Tell me how you would like to be credited, or that
you would rather not be — either is fine, and neither is a condition.
