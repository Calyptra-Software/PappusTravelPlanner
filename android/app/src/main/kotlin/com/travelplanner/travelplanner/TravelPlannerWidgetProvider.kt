package com.travelplanner.travelplanner

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget showing the featured trip and today's plan. All display
 * strings are pre-formatted (and localised) on the Flutter side and read here
 * from [widgetData]; this class renders them, sizing the item list to the
 * widget's current height, and wires the tap intent.
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

    /** Re-render on resize so the item list fills the new height. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
    }

    private fun render(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        data: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.travelplanner_widget)

        if (data.getBoolean("has_trip", false)) {
            showTrip(context, appWidgetManager, widgetId, views, data)
        } else {
            showEmptyState(views, data)
        }

        // Deep-link the whole widget to the featured trip (or the list).
        val tripId = data.getInt("trip_id", -1)
        val uri = Uri.parse("travelplanner://trip?id=$tripId")
        val pendingIntent = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            uri,
        )
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun showEmptyState(views: RemoteViews, data: SharedPreferences) {
        views.setViewVisibility(R.id.trip_content, View.GONE)
        views.setViewVisibility(R.id.empty_content, View.VISIBLE)
        views.setTextViewText(R.id.empty_title, data.getString("empty_title", ""))
        views.setTextViewText(R.id.empty_body, data.getString("empty_body", ""))
    }

    private fun showTrip(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        views: RemoteViews,
        data: SharedPreferences,
    ) {
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
        if (!showToday) return

        setOrHide(views, R.id.today_header, data.getString("today_header", ""))

        // Render as many rows as fit the widget's current height, then a "+N"
        // only for whatever genuinely didn't fit.
        val shown = rowsThatFit(data, itemCount, widgetHeightDp(appWidgetManager, widgetId))
        views.removeAllViews(R.id.today_list_container)
        for (i in 0 until shown) {
            val row = RemoteViews(context.packageName, R.layout.widget_item_row)
            setOrHide(row, R.id.item_time, data.getString("item${i}_time", ""))
            row.setTextViewText(R.id.item_text, data.getString("item${i}_text", ""))
            setOrHide(row, R.id.item_note, data.getString("item${i}_note", ""))
            views.addView(R.id.today_list_container, row)
        }

        val remaining = itemCount - shown
        setOrHide(views, R.id.today_more, if (remaining > 0) "+$remaining" else "")
    }

    /** Current widget height in dp, from the host's size options. */
    private fun widgetHeightDp(appWidgetManager: AppWidgetManager, widgetId: Int): Int {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        // Portrait reports MAX_HEIGHT; fall back to MIN_HEIGHT, then a default.
        val max = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        val min = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        val height = if (max > 0) max else min
        return if (height > 0) height else DEFAULT_HEIGHT_DP
    }

    /**
     * How many item rows fit in [heightDp]. Estimates height from the fixed
     * header plus each row (taller when it carries a note). Always shows at
     * least the previous baseline so small widgets don't regress, and never
     * more than there are items.
     */
    private fun rowsThatFit(data: SharedPreferences, itemCount: Int, heightDp: Int): Int {
        val available = heightDp - HEADER_OVERHEAD_DP
        var used = 0
        var fit = 0
        for (i in 0 until itemCount) {
            val note = data.getString("item${i}_note", "") ?: ""
            val rowHeight = ROW_BASE_DP + if (note.isNotEmpty()) NOTE_DP else 0
            if (fit > 0 && used + rowHeight > available) break
            used += rowHeight
            fit++
        }
        return fit.coerceAtLeast(minOf(itemCount, BASELINE_ROWS))
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

    private companion object {
        // Rough dp estimates used only to decide the row count.
        const val HEADER_OVERHEAD_DP = 150
        const val ROW_BASE_DP = 26
        const val NOTE_DP = 18
        const val DEFAULT_HEIGHT_DP = 180
        const val BASELINE_ROWS = 3
    }
}
