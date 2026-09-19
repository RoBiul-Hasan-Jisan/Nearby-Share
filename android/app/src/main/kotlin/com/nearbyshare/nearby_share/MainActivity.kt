package com.nearbyshare.nearby_share

import android.app.Activity
import android.app.DownloadManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "nearby_share/system"
        private const val REQUEST_ENABLE_BT = 4711
    }

    private var pendingBluetoothResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "isBluetoothEnabled" -> result.success(bluetoothAdapter()?.isEnabled == true)
            "isWifiEnabled" -> result.success(wifiManager()?.isWifiEnabled == true)
            "requestEnableBluetooth" -> requestEnableBluetooth(result)
            "openWifiSettings" -> { openWifiSettings(); result.success(true) }
            "openLocationSettings" -> { launch(Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS)); result.success(true) }
            "deviceName" -> result.success(deviceName())
            "saveToDownloads" -> saveToDownloads(call, result)
            "openDownloads" -> { launch(Intent(DownloadManager.ACTION_VIEW_DOWNLOADS)); result.success(true) }
            else -> result.notImplemented()
        }
    }

    private fun bluetoothAdapter(): BluetoothAdapter? =
        (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    private fun wifiManager(): WifiManager? =
        applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager

    private fun launch(intent: Intent) {
        try {
            startActivity(intent)
        } catch (e: Exception) {
            // Nothing can handle it; ignore.
        }
    }

    private fun openWifiSettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startActivity(Intent(Settings.Panel.ACTION_INTERNET_CONNECTIVITY))
            } else {
                startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
            }
        } catch (e: Exception) {
            launch(Intent(Settings.ACTION_WIFI_SETTINGS))
        }
    }

    @Suppress("DEPRECATION")
    private fun requestEnableBluetooth(result: MethodChannel.Result) {
        val adapter = bluetoothAdapter()
        if (adapter == null) { result.success(false); return }
        if (adapter.isEnabled) { result.success(true); return }
        if (pendingBluetoothResult != null) { result.success(false); return }
        pendingBluetoothResult = result
        try {
            startActivityForResult(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), REQUEST_ENABLE_BT)
        } catch (e: Exception) {
            pendingBluetoothResult = null
            result.success(false)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_ENABLE_BT) {
            pendingBluetoothResult?.success(resultCode == Activity.RESULT_OK)
            pendingBluetoothResult = null
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    private fun deviceName(): String {
        val fromSettings = try {
            Settings.Global.getString(contentResolver, "device_name")
        } catch (e: Exception) {
            null
        }
        if (!fromSettings.isNullOrBlank()) return fromSettings.trim()
        val manufacturer = Build.MANUFACTURER ?: ""
        val model = Build.MODEL ?: ""
        val combined = if (model.startsWith(manufacturer, ignoreCase = true)) model else "$manufacturer $model"
        val name = combined.trim()
        return if (name.isEmpty()) "Android Device" else name.replaceFirstChar { it.uppercase() }
    }

    /** Copies [path] into Downloads/Nearby Share/Received via MediaStore (Android 10+, no permission needed). */
    private fun saveToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val name = call.argument<String>("name")
        val mime = call.argument<String>("mime") ?: "application/octet-stream"
        if (path == null || name == null) {
            result.error("bad_args", "path and name are required", null)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.success(null) // Dart falls back to app-specific external storage
            return
        }
        Thread {
            try {
                val resolver = contentResolver
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                    put(MediaStore.MediaColumns.MIME_TYPE, mime)
                    put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Nearby Share/Received")
                    put(MediaStore.MediaColumns.IS_PENDING, 1)
                }
                val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                val uri = resolver.insert(collection, values)
                    ?: throw IllegalStateException("Could not create a file in Downloads")
                try {
                    val out = resolver.openOutputStream(uri)
                        ?: throw IllegalStateException("Could not open the output file")
                    out.use { o ->
                        FileInputStream(File(path)).use { input -> input.copyTo(o, 256 * 1024) }
                    }
                    val done = ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }
                    resolver.update(uri, done, null, null)
                } catch (e: Exception) {
                    resolver.delete(uri, null, null)
                    throw e
                }
                mainHandler.post { result.success("Downloads/Nearby Share/Received") }
            } catch (e: Exception) {
                mainHandler.post { result.error("save_failed", e.message, null) }
            }
        }.start()
    }
}
