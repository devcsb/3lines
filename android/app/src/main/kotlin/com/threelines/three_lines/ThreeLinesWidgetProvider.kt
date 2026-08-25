package com.threelines.three_lines

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Home screen widget: streak + status + optional prompt/emotion chips.
 */
class ThreeLinesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = HomeWidgetPlugin.getData(context)
        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val useMedium = minWidth >= 250
            val layoutId =
                if (useMedium) R.layout.three_lines_widget_medium
                else R.layout.three_lines_widget_small

            val views = RemoteViews(context.packageName, layoutId)
            bindCommon(context, views, data, useMedium)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle?,
    ) {
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    private fun bindCommon(
        context: Context,
        views: RemoteViews,
        data: SharedPreferences,
        medium: Boolean,
    ) {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val state = resolveThreeLinesWidgetState(
            storedDate = data.getString("date", null),
            today = today,
            streakLabel = data.getString("streak_label", null) ?: "시작해볼까요",
            statusMessage = data.getString("status_message", null)
                ?: "앱을 열어 오늘을 기록해보세요",
            prompt = data.getString("prompt", null) ?: "오늘 감사한 작은 것 하나는?",
            isCompleted = data.getString("is_completed", "false") == "true",
            emotionRaw = data.getString("emotion", "") ?: "",
        )

        views.setTextViewText(R.id.widget_title, "3Lines")
        views.setTextViewText(R.id.widget_streak, state.streakLabel)
        views.setTextViewText(R.id.widget_status, state.statusMessage)

        val openToday =
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("threelines://today"),
            )
        views.setOnClickPendingIntent(R.id.widget_root, openToday)

        if (medium) {
            views.setTextViewText(R.id.widget_prompt, state.prompt)
            if (state.isCompleted) {
                views.setViewVisibility(R.id.widget_emotion_row, View.GONE)
                views.setViewVisibility(R.id.widget_completed_hint, View.VISIBLE)
                val hint =
                    if (state.emotionRaw.isNotEmpty()) {
                        "기록 완료 · 탭해서 보기"
                    } else {
                        "오늘 기록 완료"
                    }
                views.setTextViewText(R.id.widget_completed_hint, hint)
            } else {
                views.setViewVisibility(R.id.widget_emotion_row, View.VISIBLE)
                views.setViewVisibility(R.id.widget_completed_hint, View.GONE)
                bindEmotion(context, views, R.id.emotion_1, 1)
                bindEmotion(context, views, R.id.emotion_2, 2)
                bindEmotion(context, views, R.id.emotion_3, 3)
                bindEmotion(context, views, R.id.emotion_4, 4)
                bindEmotion(context, views, R.id.emotion_5, 5)
            }
        }
    }

    private fun bindEmotion(
        context: Context,
        views: RemoteViews,
        viewId: Int,
        emotion: Int,
    ) {
        val intent: PendingIntent =
            HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("threelines://today?emotion=$emotion"),
            )
        views.setOnClickPendingIntent(viewId, intent)
    }
}
