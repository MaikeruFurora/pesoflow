package com.iponlock.iponlock

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class PesoFlowWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val assets = prefs.getString("pf_assets", null) ?: "₱ 0"
        val updated = prefs.getString("pf_updated", null) ?: ""

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.peso_flow_widget)
            views.setTextViewText(R.id.widget_assets, assets)
            views.setTextViewText(
                R.id.widget_updated,
                if (updated.isEmpty()) "Open PesoFlow to sync" else "Updated $updated",
            )

            val launchIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
            )
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent)

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
