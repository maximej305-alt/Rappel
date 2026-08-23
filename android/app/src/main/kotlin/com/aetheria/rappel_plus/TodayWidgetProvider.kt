package com.aetheria.rappel_plus

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Widget « Aujourd'hui » de Rappel+.
 *
 * Affiche la liste du jour (miroir en clair écrit par le code Dart via
 * home_widget) : titre, progression X/Y et jusqu'à 5 lignes (heure + nom,
 * barrées quand terminées). Un tap ouvre l'application.
 */
class TodayWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_today)

            val total = widgetData.getInt("w_total", 0)
            val done = widgetData.getInt("w_done", 0)
            val rowCount = widgetData.getInt("w_rows", 0)

            // En-tête : titre + progression.
            views.setTextViewText(
                R.id.widget_progress_label,
                if (total == 0) "0/0" else "$done/$total",
            )
            views.setProgressBar(R.id.widget_progress, total, done, false)

            // État vide.
            val empty = total == 0
            views.setViewVisibility(R.id.widget_empty, if (empty) android.view.View.VISIBLE else android.view.View.GONE)
            views.setViewVisibility(R.id.widget_rows, if (empty) android.view.View.GONE else android.view.View.VISIBLE)

            // Lignes : reconstruites à chaque mise à jour.
            views.removeAllViews(R.id.widget_rows)
            for (i in 0 until minOf(rowCount, 5)) {
                val title = widgetData.getString("w_title_$i", "") ?: ""
                val time = widgetData.getString("w_time_$i", "") ?: ""
                val isDone = widgetData.getBoolean("w_done_$i", false)

                val row = RemoteViews(context.packageName, R.layout.widget_today_row)
                row.setTextViewText(R.id.row_time, time)
                row.setTextViewText(R.id.row_title, title)
                row.setTextColor(
                    R.id.row_title,
                    if (isDone) 0xFF9AA0B5.toInt() else 0xFFF2F3F8.toInt(),
                )
                // Barre latérale : verte si fait, bleu Rappel+ sinon.
                row.setInt(
                    R.id.row_bar,
                    "setBackgroundColor",
                    if (isDone) 0xFF34D399.toInt() else 0xFF4F5DFF.toInt(),
                )
                views.addView(R.id.widget_rows, row)
            }

            // Tap n'importe où : ouvre l'application.
            val launch = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, launch)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
