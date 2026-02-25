package __PACKAGE__

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews

class ReadingBooksWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_ADJUST_PROGRESS) return

        val bookId = intent.getStringExtra(EXTRA_BOOK_ID)?.trim().orEmpty()
        val delta = intent.getIntExtra(EXTRA_PROGRESS_DELTA, 0)
        if (bookId.isEmpty() || delta == 0) return

        val changed = ReadingBooksWidgetStore.adjustProgress(context, bookId, delta)
        if (changed) {
            refreshAllWidgets(context)
        }
    }

    companion object {
        const val ACTION_ADJUST_PROGRESS = "__PACKAGE__.widget.ADJUST_PROGRESS"
        const val EXTRA_BOOK_ID = "extra_book_id"
        const val EXTRA_PROGRESS_DELTA = "extra_progress_delta"

        @JvmStatic
        fun refreshAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, ReadingBooksWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(component)
            if (appWidgetIds.isEmpty()) return
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_book_list)
            for (appWidgetId in appWidgetIds) {
                updateWidget(context, appWidgetManager, appWidgetId)
            }
        }

        private fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val books = ReadingBooksWidgetStore.loadReadingBooks(context)
            val views = RemoteViews(context.packageName, R.layout.reading_books_widget)
            views.setTextViewText(
                R.id.widget_subtitle,
                if (books.isEmpty()) "No books currently in Reading" else "${books.size} currently reading",
            )

            val serviceIntent = Intent(context, ReadingBooksWidgetRemoteViewsService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_book_list, serviceIntent)
            views.setEmptyView(R.id.widget_book_list, R.id.widget_empty)

            val clickTemplate = Intent(context, ReadingBooksWidgetProvider::class.java)
                .setAction(ACTION_ADJUST_PROGRESS)
            val clickPendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                clickTemplate,
                mutableUpdateCurrentFlags(),
            )
            views.setPendingIntentTemplate(R.id.widget_book_list, clickPendingIntent)

            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val launchPendingIntent = PendingIntent.getActivity(
                    context,
                    appWidgetId + 10_000,
                    launchIntent,
                    immutableUpdateCurrentFlags(),
                )
                views.setOnClickPendingIntent(R.id.widget_header, launchPendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun mutableUpdateCurrentFlags(): Int {
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                flags = flags or PendingIntent.FLAG_MUTABLE
            }
            return flags
        }

        private fun immutableUpdateCurrentFlags(): Int {
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                flags = flags or PendingIntent.FLAG_IMMUTABLE
            }
            return flags
        }
    }
}
