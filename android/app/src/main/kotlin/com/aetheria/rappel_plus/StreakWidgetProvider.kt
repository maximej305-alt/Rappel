package com.aetheria.rappel_plus

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Widget « Série » (2x2) : flamme + série actuelle et record. */
class StreakWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val has = widgetData.getBoolean("s_has", false)
        val current = widgetData.getInt("s_current", 0)
        val best = widgetData.getInt("s_best", 0)

        val views = RemoteViews(context.packageName, R.layout.widget_streak)
        views.setTextViewText(R.id.streak_flame, if (current > 0) "🔥" else "💤")
        views.setTextViewText(
            R.id.streak_current,
            if (has) "$current j" else "—",
        )
        views.setTextViewText(
            R.id.streak_best,
            "★ $best",
        )
        openAppOnClick(context, views, R.id.streak_root)

        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, views) }
    }
}
