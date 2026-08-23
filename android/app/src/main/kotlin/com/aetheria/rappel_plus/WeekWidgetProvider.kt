package com.aetheria.rappel_plus

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget « Semaine » (4x2) : les 7 jours lun→dim avec lettre, numéro du
 * jour et mini-barre de réussite. Journée complète = numéro en vert.
 */
class WeekWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_week)
        val barIds = intArrayOf(
            R.id.wk_bar_0, R.id.wk_bar_1, R.id.wk_bar_2, R.id.wk_bar_3,
            R.id.wk_bar_4, R.id.wk_bar_5, R.id.wk_bar_6,
        )
        val letterIds = intArrayOf(
            R.id.wk_letter_0, R.id.wk_letter_1, R.id.wk_letter_2, R.id.wk_letter_3,
            R.id.wk_letter_4, R.id.wk_letter_5, R.id.wk_letter_6,
        )
        val dayIds = intArrayOf(
            R.id.wk_day_0, R.id.wk_day_1, R.id.wk_day_2, R.id.wk_day_3,
            R.id.wk_day_4, R.id.wk_day_5, R.id.wk_day_6,
        )

        for (i in 0..6) {
            val due = widgetData.getInt("d_due_$i", 0)
            val doneCount = widgetData.getInt("d_done_$i", 0)
            val complete = due > 0 && doneCount >= due

            views.setTextViewText(
                letterIds[i],
                widgetData.getString("d_letter_$i", "?") ?: "?",
            )
            views.setTextViewText(
                dayIds[i],
                widgetData.getInt("d_day_$i", 0).toString(),
            )
            views.setTextColor(
                dayIds[i],
                if (complete) 0xFF34D399.toInt() else 0xFFF2F3F8.toInt(),
            )
            views.setProgressBar(barIds[i], 100, if (due == 0) 0 else doneCount * 100 / due, false)
        }
        openAppOnClick(context, views, R.id.week_root)

        appWidgetIds.forEach { appWidgetManager.updateAppWidget(it, views) }
    }
}
