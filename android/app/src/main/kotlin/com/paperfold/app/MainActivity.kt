package com.paperfold.app

import android.content.pm.PackageManager
import android.content.Intent
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
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
