package com.travelplanner.travelplanner

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Backs the scrollable "today's plan" [android.widget.ListView] in the widget.
 * Reads the same pre-formatted, already-localised item data that the Flutter
 * side pushes into [HomeWidgetPlugin]'s shared preferences (item_count plus
 * item{i}_time / item{i}_text / item{i}_note) and renders one row per item.
 *
 * Each row carries a fill-in intent that, merged with the list's PendingIntent
 * template (set in the provider), deep-links to that specific item.
 */
class TodayItemsRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TodayItemsFactory(applicationContext)
}

private class TodayItemsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private var count = 0

    override fun onCreate() {}

    override fun onDataSetChanged() {
        count = HomeWidgetPlugin.getData(context).getInt("item_count", 0)
    }

    override fun onDestroy() {
        count = 0
    }

    override fun getCount(): Int = count

    override fun getViewAt(position: Int): RemoteViews {
        val data = HomeWidgetPlugin.getData(context)
        val row = RemoteViews(context.packageName, R.layout.widget_item_row)

        val time = data.getString("item${position}_time", "") ?: ""
        if (time.isEmpty()) {
            row.setViewVisibility(R.id.item_time, View.GONE)
        } else {
            row.setViewVisibility(R.id.item_time, View.VISIBLE)
            row.setTextViewText(R.id.item_time, time)
        }

        row.setTextViewText(R.id.item_text, data.getString("item${position}_text", ""))

        val note = data.getString("item${position}_note", "") ?: ""
        if (note.isEmpty()) {
            row.setViewVisibility(R.id.item_note, View.GONE)
        } else {
            row.setViewVisibility(R.id.item_note, View.VISIBLE)
            row.setTextViewText(R.id.item_note, note)
        }

        // Fill-in intent (merged with the list's PendingIntent template): deep
        // link to this specific item so tapping the row opens its editor.
        val tripId = data.getInt("trip_id", -1)
        val itemId = data.getInt("item${position}_id", -1)
        val fillIn = Intent().apply {
            this.data = Uri.parse("travelplanner://trip?id=$tripId&item=$itemId")
        }
        row.setOnClickFillInIntent(R.id.item_row, fillIn)

        return row
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
