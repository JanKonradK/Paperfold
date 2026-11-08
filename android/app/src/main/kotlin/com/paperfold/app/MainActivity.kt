package com.paperfold.app

import android.content.pm.PackageManager
import android.os.Bundle
import android.view.WindowManager
import android.content.res.Configuration
import android.content.Intent
import android.os.Build
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private var readerOrientation: Int? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Never retain a reader override after activity recreation.
        window.attributes = window.attributes.apply {
            screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
        }
        if (savedInstanceState?.containsKey("readerOrientation") == true) {
            requestedOrientation = savedInstanceState.getInt("readerOrientation")
        }
    }

    override fun onSaveInstanceState(outState: Bundle) {
        readerOrientation?.let { outState.putInt("readerOrientation", it) }
        super.onSaveInstanceState(outState)
    }

    private fun restoreReaderOrientation() {
        readerOrientation?.let { requestedOrientation = it }
        readerOrientation = null
    }

    // A still page needs no fast refresh. While the reader is open, the window
    // asks for the slowest mode at full resolution once input stops, and gives
    // the choice back to the system on the next touch or key.
    private var lowRefresh = false
    private val idleRefresh = Runnable { setDisplayMode(slowestModeId()) }

    private fun slowestModeId(): Int {
        @Suppress("DEPRECATION")
        val display = windowManager.defaultDisplay
        val current = display.mode
        return display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .minByOrNull { it.refreshRate }?.modeId ?: 0
    }

    private fun setDisplayMode(id: Int) {
        if (window.attributes.preferredDisplayModeId != id) {
            window.attributes = window.attributes.apply { preferredDisplayModeId = id }
        }
    }

    private fun onReaderInput(down: Boolean) {
        if (!lowRefresh) return
        window.decorView.removeCallbacks(idleRefresh)
        if (down) setDisplayMode(0) else window.decorView.postDelayed(idleRefresh, 2000)
    }

    private fun stopLowRefresh() {
        lowRefresh = false
        window.decorView.removeCallbacks(idleRefresh)
        setDisplayMode(0)
    }

    override fun dispatchTouchEvent(ev: MotionEvent): Boolean {
        when (ev.actionMasked) {
            MotionEvent.ACTION_DOWN -> onReaderInput(true)
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> onReaderInput(false)
        }
        return super.dispatchTouchEvent(ev)
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        onReaderInput(event.action == KeyEvent.ACTION_DOWN)
        return super.dispatchKeyEvent(event)
    }

    private var captureChannel: MethodChannel? = null
    private var pendingLaunch: String? = null
    private var captureReady = false

    private fun captureUri(intent: Intent?): String? {
        val uri = intent?.data ?: return null
        return if (uri.scheme == "paperfold" && (uri.host == "capture" || uri.host == "open")) uri.toString() else null
    }


    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Ensure the latest intent is stored so plugins relying on Activity#getIntent can read it.
        setIntent(intent)
        captureUri(intent)?.let {
            if (!captureReady) pendingLaunch = it
            else captureChannel?.invokeMethod("launch", it)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.paperfold.app/reader_window")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "brightness" -> {
                            val value = (call.arguments as? Number)?.toFloat()
                            if (value != null && (!value.isFinite() || value < 0.05f || value > 1f)) {
                                result.error("BRIGHTNESS_RANGE", "Expected 0.05 to 1", null)
                            } else {
                                window.attributes = window.attributes.apply {
                                    screenBrightness = value ?: WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                                }
                                result.success(null)
                            }
                        }
                        "rotation" -> {
                            if ((Build.VERSION.SDK_INT >= 24 && isInMultiWindowMode) ||
                                (Build.VERSION.SDK_INT >= 36 && resources.configuration.smallestScreenWidthDp >= 600)) {
                                result.success(null)
                            } else {
                                if (readerOrientation == null) readerOrientation = requestedOrientation
                                @Suppress("DEPRECATION")
                                val rotation = windowManager.defaultDisplay.rotation
                                val landscape = resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
                                val naturalLandscape = if (rotation % 2 == 0) landscape else !landscape
                                result.success((rotation + if (naturalLandscape) 1 else 0) % 4)
                            }
                        }
                        "state" -> result.success(mapOf(
                            "brightness" to window.attributes.screenBrightness,
                            "locked" to (readerOrientation != null)
                        ))
                        "restoreOrientation" -> { restoreReaderOrientation(); result.success(null) }
                        "lowRefresh" -> {
                            lowRefresh = true
                            onReaderInput(false)
                            result.success(null)
                        }
                        "restore" -> {
                            window.attributes = window.attributes.apply {
                                screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                            }
                            restoreReaderOrientation()
                            stopLowRefresh()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    window.attributes = window.attributes.apply {
                        screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                    }
                    restoreReaderOrientation()
                    stopLowRefresh()
                    result.error("READER_WINDOW", error.message, null)
                }
            }
        pendingLaunch = captureUri(intent)
        captureChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.paperfold.app/capture").also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeLaunch" -> { captureReady = true; result.success(pendingLaunch); pendingLaunch = null }
                    "updateWidgets" -> {
                        getSharedPreferences("paperfold_widgets", MODE_PRIVATE).edit()
                            .putString("snapshot", call.arguments as String).apply()
                        ContinueReadingWidget.refresh(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INSTALL_INFO_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstallInfo" -> {
                    try {
                        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            packageManager.getPackageInfo(
                                packageName,
                                PackageManager.PackageInfoFlags.of(0),
                            )
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, 0)
                        }
                        result.success(
                            hashMapOf(
                                "firstInstallTime" to packageInfo.firstInstallTime,
                                "lastUpdateTime" to packageInfo.lastUpdateTime,
                            ),
                        )
                    } catch (e: Exception) {
                        result.error("PACKAGE_INFO_ERROR", e.message, null)
                    }
                }

                // The system installer asks the reader to confirm the update.
                // ACTION_VIEW also offers Paperfold, which opens any file;
                // only installers handle ACTION_INSTALL_PACKAGE.
                "installUpdate" -> {
                    try {
                        val apk = FileProvider.getUriForFile(
                            this,
                            "$packageName.updates",
                            File(call.arguments as String),
                        )
                        @Suppress("DEPRECATION")
                        startActivity(
                            Intent(Intent.ACTION_INSTALL_PACKAGE)
                                .setDataAndType(apk, "application/vnd.android.package-archive")
                                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val INSTALL_INFO_CHANNEL = "com.paperfold.app/install_info"
    }
}
