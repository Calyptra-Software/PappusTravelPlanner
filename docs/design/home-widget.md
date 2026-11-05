# Android home-screen widget

Design notes moved out of [`AGENTS.md`](../../AGENTS.md) so they are read when the work needs them rather than every session. They were written as one document: an "above" or "below" may point into another file in this directory. Read this for the home-screen widget and its payload.

`lib/features/home_widget/` pushes a fully pre-formatted, already-localized `WidgetPayload`
to the native Kotlin `PappusWidgetProvider` (`android/app/src/main/kotlin/.../`) as
flat key/value pairs via `home_widget`. `HomeWidgetSync` (wrapping the app in `app.dart`)
watches trips/itinerary and re-pushes on change; widget taps deep-link via
`pappus://trip?id=N`. `pickFeaturedTrip` decides which trip to show (ongoing → next
upcoming → most recent past). Widget code is Android-only and no-ops elsewhere.

**Every entry point needs the `_widgetSupported` guard, including the one that only
listens.** `listenWidgetClicks` was missing it, and merely *activating*
`HomeWidget.widgetClicked` threw a `MissingPluginException` — reported with a full stack
into the console at every start on the web and on the desktops, where nothing depended on
the stream in the first place. The other three calls had the guard, which is what made
this one invisible: the sentence above was true of the feature and false of one line.
The failure of a channel with no implementation is loud but harmless, so it cost no
function, only a red error standing in front of every real one. `widget_deep_link_test.dart`
now asserts the guard for the four non-Android platforms — no plugin is registered under
`flutter test`, so an unguarded listen fails there exactly as it does in the app.

**WorkManager is in the build and never starts.** `home_widget` depends on
androidx `work-runtime` directly *and* on `androidx.glance:glance-appwidget`, which depends
on it again — neither can be excluded, since three of the plugin's own Kotlin sources
reference Glance. Its only user is `HomeWidgetBackgroundWorker`, reached solely from
`HomeWidget.registerInteractivityCallback`, which this app does not use: it pushes a payload
with `saveWidgetData`/`updateWidget` and answers a tap with a deep link. So four of the five
permissions it merged into the manifest are removed with `tools:node="remove"` — the fifth,
`FOREGROUND_SERVICE`, is the app's own since the track recorder, and stays — and — the
other half, without which the first is a crash rather than a tidy-up — the
`WorkManagerInitializer` node is removed from `androidx.startup`'s provider, because that
initializer runs in every process at launch and its `ForceStopRunnable` takes a
`PowerManager` wake lock immediately. Adding an interactivity callback later means undoing
both; the failure if you forget is "WorkManager is not initialized properly", which is loud.

A row's time (`widgetTime`) is the one place the payload is not plain text: it carries the
same planned-time-plus-miss line as the timeline, and a `RemoteViews` text can only be
colored in part through HTML, so the `(+15)` is wrapped in a `<font color>` that
`TodayItemsRemoteViewsService` parses back into spans with `Html.fromHtml`. The colors are
the widget's own (a lighter red/green — it paints on its own dark background, not the app's
theme), and a row with nothing recorded still sends plain "09:00 – 10:30".

An entry running into today from an earlier day is a row too, above today's own, from the
same `continuationsOn` the timeline draws its `ContinuationTile`s from (`continuationRow`):
its time is the **end** alone behind a `↳`, the timeline's turn-down arrow ("↳ 07:12
(+15)"), since yesterday's departure says nothing about today, and where there is no end
time to give — a day the entry runs through — the arrow stands alone and the note says
"Continues all day". No Kotlin changed for it: the arrow goes through the same
`Html.fromHtml` as any time.
