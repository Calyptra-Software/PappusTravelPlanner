package com.travelplanner.travelplanner

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing the featured trip and today's plan. All display
 * strings are pre-formatted (and localised) on the Flutter side and read here
 * from [widgetData]; this class only renders and wires the tap intent.
 */
class TravelPlannerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.travelplanner_widget)
            val hasTrip = widgetData.getBoolean("has_trip", false)

            if (!hasTrip) {
                showEmptyState(views, widgetData)
            } else {
                showTrip(views, widgetData)
            }

            // Deep-link the whole widget to the featured trip (or the list).
            val tripId = widgetData.getInt("trip_id", -1)
            val uri = Uri.parse("travelplanner://trip?id=$tripId")
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                uri,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun showEmptyState(views: RemoteViews, data: SharedPreferences) {
        views.setViewVisibility(R.id.trip_content, View.GONE)
        views.setViewVisibility(R.id.empty_content, View.VISIBLE)
        views.setTextViewText(R.id.empty_title, data.getString("empty_title", ""))
        views.setTextViewText(R.id.empty_body, data.getString("empty_body", ""))
    }

    private fun showTrip(views: RemoteViews, data: SharedPreferences) {
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

        if (showToday) {
            setOrHide(views, R.id.today_header, data.getString("today_header", ""))
            bindRow(views, data, 0, R.id.item0_row, R.id.item0_time, R.id.item0_text, R.id.item0_note)
            bindRow(views, data, 1, R.id.item1_row, R.id.item1_time, R.id.item1_text, R.id.item1_note)
            bindRow(views, data, 2, R.id.item2_row, R.id.item2_time, R.id.item2_text, R.id.item2_note)
            setOrHide(views, R.id.today_more, data.getString("more_text", ""))
        }
    }

    private fun bindRow(
        views: RemoteViews,
        data: SharedPreferences,
        index: Int,
        rowId: Int,
        timeId: Int,
        textId: Int,
        noteId: Int,
    ) {
        val text = data.getString("item${index}_text", "") ?: ""
        if (text.isEmpty()) {
            views.setViewVisibility(rowId, View.GONE)
            return
        }
        views.setViewVisibility(rowId, View.VISIBLE)
        setOrHide(views, timeId, data.getString("item${index}_time", ""))
        views.setTextViewText(textId, text)
        setOrHide(views, noteId, data.getString("item${index}_note", ""))
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
