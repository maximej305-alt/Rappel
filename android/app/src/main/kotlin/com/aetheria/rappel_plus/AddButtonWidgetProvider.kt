package com.aetheria.rappel_plus

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Widget « Bouton + » (1x1) : raccourci d'ouverture de l'application. */
class AddButtonWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_add)
        openAppOnClick(context, views, R.id.add_root)
        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, views) }
    }
}
