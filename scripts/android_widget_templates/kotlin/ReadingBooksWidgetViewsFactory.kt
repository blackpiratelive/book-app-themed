package __PACKAGE__

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService

class ReadingBooksWidgetViewsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {
    private var books: List<ReadingWidgetBook> = emptyList()

    override fun onCreate() {
        books = ReadingBooksWidgetStore.loadReadingBooks(context)
    }

    override fun onDataSetChanged() {
        books = ReadingBooksWidgetStore.loadReadingBooks(context)
    }

    override fun onDestroy() {
        books = emptyList()
    }

    override fun getCount(): Int = books.size

    override fun getViewAt(position: Int): RemoteViews? {
        val book = books.getOrNull(position) ?: return null
        val views = RemoteViews(context.packageName, R.layout.reading_books_widget_item)
        views.setTextViewText(R.id.widget_item_title, book.title)
        views.setTextViewText(
            R.id.widget_item_author,
            if (book.author.isBlank()) "Unknown author" else book.author,
        )
        views.setTextViewText(R.id.widget_item_progress_text, "${book.progressPercent}%")
        views.setProgressBar(R.id.widget_item_progress_bar, 100, book.progressPercent, false)

        val decrementIntent = Intent().apply {
            action = ReadingBooksWidgetProvider.ACTION_ADJUST_PROGRESS
            putExtra(ReadingBooksWidgetProvider.EXTRA_BOOK_ID, book.id)
            putExtra(ReadingBooksWidgetProvider.EXTRA_PROGRESS_DELTA, -5)
        }
        val incrementIntent = Intent().apply {
            action = ReadingBooksWidgetProvider.ACTION_ADJUST_PROGRESS
            putExtra(ReadingBooksWidgetProvider.EXTRA_BOOK_ID, book.id)
            putExtra(ReadingBooksWidgetProvider.EXTRA_PROGRESS_DELTA, 5)
        }
        views.setOnClickFillInIntent(R.id.widget_item_minus, decrementIntent)
        views.setOnClickFillInIntent(R.id.widget_item_plus, incrementIntent)
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = books.getOrNull(position)?.id?.hashCode()?.toLong() ?: position.toLong()

    override fun hasStableIds(): Boolean = true
}
