package com.aetheria.rappel_plus

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Widget « Prochaine activité » (4x1) : heure + nom de la prochaine tâche. */
class NextActivityWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val has = widgetData.getBoolean("n_has", false)
        val title = widgetData.getString("n_title", "") ?: ""
        val time = widgetData.getString("n_time", "") ?: ""

        val views = RemoteViews(context.packageName, R.layout.widget_next)
        views.setViewVisibility(R.id.next_empty, if (has) android.view.View.GONE else android.view.View.VISIBLE)
        views.setViewVisibility(R.id.next_content, if (has) android.view.View.VISIBLE else android.view.View.GONE)
        views.setTextViewText(R.id.next_time, time)
        views.setTextViewText(R.id.next_title, title)
        openAppOnClick(context, views, R.id.next_root)

        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, views) }
    }
}
