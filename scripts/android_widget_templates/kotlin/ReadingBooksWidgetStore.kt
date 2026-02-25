package __PACKAGE__

import android.content.Context
import org.json.JSONArray
import org.json.JSONException

private const val FLUTTER_PREFS_FILE = "FlutterSharedPreferences"
private const val BOOKS_KEY_V2 = "flutter.book_items_v2"
private const val BOOKS_KEY_V1 = "flutter.book_items_v1"

data class ReadingWidgetBook(
    val id: String,
    val title: String,
    val author: String,
    val progressPercent: Int,
)

object ReadingBooksWidgetStore {
    fun loadReadingBooks(context: Context): List<ReadingWidgetBook> {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS_FILE, Context.MODE_PRIVATE)
        val raw = prefs.getString(BOOKS_KEY_V2, null) ?: prefs.getString(BOOKS_KEY_V1, null)
        if (raw.isNullOrBlank()) return emptyList()

        return try {
            val array = JSONArray(raw)
            buildList {
                for (i in 0 until array.length()) {
                    val item = array.optJSONObject(i) ?: continue
                    val status = item.optString("status").trim().lowercase()
                    if (status != "reading") continue
                    add(
                        ReadingWidgetBook(
                            id = item.optString("id").trim(),
                            title = item.optString("title").trim().ifBlank { "Untitled" },
                            author = item.optString("author").trim(),
                            progressPercent = clampProgress(item.optInt("progressPercent", 0)),
                        )
                    )
                }
            }
        } catch (_: JSONException) {
            emptyList()
        }
    }

    fun adjustProgress(context: Context, bookId: String, delta: Int): Boolean {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS_FILE, Context.MODE_PRIVATE)
        val key = when {
            prefs.contains(BOOKS_KEY_V2) -> BOOKS_KEY_V2
            prefs.contains(BOOKS_KEY_V1) -> BOOKS_KEY_V1
            else -> return false
        }
        val raw = prefs.getString(key, null) ?: return false

        return try {
            val array = JSONArray(raw)
            var changed = false
            for (i in 0 until array.length()) {
                val item = array.optJSONObject(i) ?: continue
                if (item.optString("id").trim() != bookId) continue
                val current = clampProgress(item.optInt("progressPercent", 0))
                val next = clampProgress(current + delta)
                if (next == current) return false
                item.put("progressPercent", next)
                changed = true
                break
            }
            if (!changed) return false
            prefs.edit().putString(key, array.toString()).apply()
            true
        } catch (_: JSONException) {
            false
        }
    }

    private fun clampProgress(value: Int): Int = value.coerceIn(0, 100)
}
