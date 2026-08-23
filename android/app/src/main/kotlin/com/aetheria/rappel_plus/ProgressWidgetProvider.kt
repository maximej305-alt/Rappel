package com.aetheria.rappel_plus

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Widget « Progression du jour » (4x1) : compteur X/Y + barre. */
class ProgressWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val total = widgetData.getInt("w_total", 0)
        val done = widgetData.getInt("w_done", 0)

        val views = RemoteViews(context.packageName, R.layout.widget_progress)
        views.setTextViewText(R.id.progress_count, "$done/$total")
        views.setProgressBar(R.id.progress_bar, if (total == 0) 1 else total, done, false)
        openAppOnClick(context, views, R.id.progress_root)

        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, views) }
    }
}
