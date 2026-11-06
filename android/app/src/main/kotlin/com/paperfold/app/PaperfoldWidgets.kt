package com.paperfold.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/** Static RemoteViews: updates come only from app writes and launcher requests. */
open class ContinueReadingWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it, this is QuickCaptureWidget) }
    }
    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: android.os.Bundle) {
        update(context, manager, id, this is QuickCaptureWidget)
    }
    companion object {
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            listOf(ContinueReadingWidget::class.java, QuickCaptureWidget::class.java).forEach { cls ->
                val ids = manager.getAppWidgetIds(ComponentName(context, cls))
                ids.forEach { update(context, manager, it, cls == QuickCaptureWidget::class.java) }
            }
        }
        private fun launch(context: Context, uri: String): PendingIntent = PendingIntent.getActivity(
            context, 0, Intent(context, MainActivity::class.java)
                .setAction(Intent.ACTION_VIEW).setData(Uri.parse(uri))
                .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

        private fun update(context: Context, manager: AppWidgetManager, id: Int, capture: Boolean) {
            val raw = context.getSharedPreferences("paperfold_widgets", Context.MODE_PRIVATE).getString("snapshot", "{}")
            val data = try { JSONObject(raw ?: "{}") } catch (_: Exception) { JSONObject() }
            val views = RemoteViews(context.packageName, if (capture) R.layout.widget_capture else R.layout.widget_continue)
            val ground = Color.parseColor(data.optString("ground", "#3D1723"))
            val text = Color.parseColor(data.optString("text", "#F3EBDD"))
            val accent = Color.parseColor(data.optString("accent", "#C8B28F"))
            views.setInt(R.id.widget_background, "setColorFilter", ground)
            val book = data.optInt("book", -1)
            val query = if (book > 0) "&book=$book" else ""
            if (capture) {
                listOf(R.id.capture_note to "note", R.id.capture_quote to "quote", R.id.capture_pages to "progress").forEach { (view, kind) ->
                    views.setTextColor(view, text)
                    views.setOnClickPendingIntent(view, launch(context, "paperfold://capture?kind=$kind$query"))
                }
            } else {
                views.setViewVisibility(R.id.book_cover, if (context.resources.configuration.fontScale >= 1.4f) View.GONE else View.VISIBLE)
                val title = data.optString("title", "").ifEmpty { context.getString(R.string.widget_continue) }
                val progress = data.optInt("progress", 0).coerceIn(0, 100)
                views.setTextViewText(R.id.book_title, title)
                views.setTextColor(R.id.book_title, text)
                val percent = java.text.NumberFormat.getPercentInstance().format(progress / 100.0)
                views.setTextViewText(R.id.book_progress, percent)
                views.setTextColor(R.id.book_progress, text)
                views.setContentDescription(R.id.book_cover, title)
                views.setImageViewResource(R.id.book_cover, R.drawable.widget_cover)
                cover(data.optString("cover"))?.let { views.setImageViewBitmap(R.id.book_cover, it) }
                val bar = Bitmap.createBitmap(240, 6, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bar)
                val paint = Paint(Paint.ANTI_ALIAS_FLAG)
                paint.color = accent; paint.alpha = 55
                canvas.drawRoundRect(0f, 0f, 240f, 6f, 3f, 3f, paint)
                paint.alpha = 255
                canvas.drawRoundRect(0f, 0f, 240f * progress / 100f, 6f, 3f, 3f, paint)
                views.setImageViewBitmap(R.id.progress_bar, bar)
                val uri = if (book > 0 && data.optBoolean("physical")) "paperfold://capture?kind=progress&book=$book"
                    else if (book > 0) "paperfold://open?book=$book" else "paperfold://open"
                views.setOnClickPendingIntent(R.id.widget_root, launch(context, uri))
            }
            manager.updateAppWidget(id, views)
        }

        // Bound decode and binder size. Rounded art is rasterised once per update.
        private fun cover(path: String): Bitmap? = try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) null else {
                val options = BitmapFactory.Options().apply {
                    inSampleSize = 1
                    while (bounds.outWidth / inSampleSize > 256 || bounds.outHeight / inSampleSize > 384) inSampleSize *= 2
                }
                val original = BitmapFactory.decodeFile(path, options)
                if (original == null) null else {
                    val result = Bitmap.createBitmap(128, 192, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(result)
                    val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
                    paint.shader = BitmapShader(original, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP).apply {
                        val scale = maxOf(128f / original.width, 192f / original.height)
                        setLocalMatrix(Matrix().apply {
                            setScale(scale, scale)
                            postTranslate((128 - original.width * scale) / 2, (192 - original.height * scale) / 2)
                        })
                    }
                    canvas.drawRoundRect(0f, 0f, 128f, 192f, 16f, 16f, paint)
                    original.recycle()
                    result
                }
            }
        } catch (_: Exception) { null }
    }
}
class QuickCaptureWidget : ContinueReadingWidget()
