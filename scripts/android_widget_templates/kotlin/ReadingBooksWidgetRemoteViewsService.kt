package __PACKAGE__

import android.content.Intent
import android.widget.RemoteViewsService

class ReadingBooksWidgetRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ReadingBooksWidgetViewsFactory(applicationContext)
    }
}
