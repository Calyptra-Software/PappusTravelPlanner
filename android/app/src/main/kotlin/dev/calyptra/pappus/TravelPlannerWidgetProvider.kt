package dev.calyptra.pappus

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing the featured trip and today's plan. All display
 * strings are pre-formatted (and localised) on the Flutter side and read here
 * from [widgetData]; this class renders the header and wires the tap intent.
 * The scrollable list of today's items is served by
 * [TodayItemsRemoteViewsService].
 */
class TravelPlannerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            render(context, appWidgetManager, widgetId, widgetData)
        }
    }

    private fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        data: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.travelplanner_widget)

        val listShown = if (data.getBoolean("has_trip", false)) {
            showTrip(context, widgetId, views, data)
        } else {
            showEmptyState(views, data)
            false
        }

        // Deep-link the whole widget to the featured trip (or the list). Note the
        // scrollable list intercepts its own touches, so this currently only
        // covers the header area; per-row taps are a separate step.
        val tripId = data.getInt("trip_id", -1)
        val uri = Uri.parse("pappus://trip?id=$tripId")
        val pendingIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            uri,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        appWidgetManager.updateAppWidget(widgetId, views)
        // Tell the list adapter to reload from the freshly-pushed data.
        if (listShown) {
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.today_list)
        }
    }

    private fun showEmptyState(views: RemoteViews, data: SharedPreferences) {
        views.setViewVisibility(R.id.trip_content, View.GONE)
        views.setViewVisibility(R.id.empty_content, View.VISIBLE)
        views.setTextViewText(R.id.empty_title, data.getString("empty_title", ""))
        views.setTextViewText(R.id.empty_body, data.getString("empty_body", ""))
    }

    /** Renders the trip header and, when there are items today, the list. */
    private fun showTrip(
        context: Context,
        widgetId: Int,
        views: RemoteViews,
        data: SharedPreferences,
    ): Boolean {
        views.setViewVisibility(R.id.empty_content, View.GONE)
        views.setViewVisibility(R.id.trip_content, View.VISIBLE)

        views.setTextViewText(R.id.trip_title, data.getString("title", ""))
        setOrHide(views, R.id.trip_destination, data.getString("destination", ""))
        setOrHide(views, R.id.trip_dates, data.getString("dates", ""))
        setOrHide(views, R.id.trip_countdown, data.getString("countdown", ""))

        val isOngoing = data.getBoolean("is_ongoing", false)
        val itemCount = data.getInt("item_count", 0)
        val showToday = isOngoing && itemCount > 0
        views.setViewVisibility(R.id.today_section, if (showToday) View.VISIBLE else View.GONE)
        if (!showToday) return false

        setOrHide(views, R.id.today_header, data.getString("today_header", ""))

        val serviceIntent = Intent(context, TodayItemsRemoteViewsService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            // Make the intent unique per widget so each list gets its own adapter.
            this.data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
        }
        views.setRemoteAdapter(R.id.today_list, serviceIntent)
        views.setPendingIntentTemplate(R.id.today_list, itemTapTemplate(context, widgetId))
        return true
    }

    /**
     * Mutable [PendingIntent] template for list-item taps. Each row supplies a
     * fill-in intent with its own `pappus://trip?id=..&item=..` data,
     * which merges into this template's home_widget launch action so the app
     * routes to that item.
     */
    private fun itemTapTemplate(context: Context, widgetId: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = HomeWidgetLaunchIntent.HOME_WIDGET_LAUNCH_ACTION
        }
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        // A template must be mutable so each row's fill-in data applies; mutable
        // is the default before Android S, where the flag doesn't exist.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_MUTABLE
        }
        return PendingIntent.getActivity(context, widgetId, intent, flags)
    }

    /** Sets the text, or hides the view when the value is blank. */
    private fun setOrHide(views: RemoteViews, viewId: Int, value: String?) {
        if (value.isNullOrEmpty()) {
            views.setViewVisibility(viewId, View.GONE)
        } else {
            views.setViewVisibility(viewId, View.VISIBLE)
            views.setTextViewText(viewId, value)
        }
    }
}
