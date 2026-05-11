package com.iponlock.iponlock

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class PesoFlowWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs: SharedPreferences = HomeWidgetPlugin.getData(context)
        val assets = prefs.getString("pf_assets", "₱ 0") ?: "₱ 0"
        val iOwe = prefs.getString("pf_iowe", "₱ 0") ?: "₱ 0"
        val owedToMe = prefs.getString("pf_owedtome", "₱ 0") ?: "₱ 0"
        val updated = prefs.getString("pf_updated", "") ?: ""

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.peso_flow_widget)
            views.setTextViewText(R.id.widget_assets, assets)
            views.setTextViewText(R.id.widget_iowe, iOwe)
            views.setTextViewText(R.id.widget_owedtome, owedToMe)
            views.setTextViewText(R.id.widget_updated,
                if (updated.isEmpty()) "Open PesoFlow to sync" else "Updated $updated")

            // Launch the app on widget tap
            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
