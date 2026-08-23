package com.aetheria.rappel_plus

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Fait s'ouvrir l'application quand la vue [viewId] du widget est touchée. */
fun HomeWidgetProvider.openAppOnClick(
    context: Context,
    views: RemoteViews,
    viewId: Int,
) {
    val launch = PendingIntent.getActivity(
        context,
        0,
        Intent(context, MainActivity::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    views.setOnClickPendingIntent(viewId, launch)
}
