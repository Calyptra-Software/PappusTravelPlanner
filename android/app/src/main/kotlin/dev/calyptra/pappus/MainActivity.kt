package dev.calyptra.pappus

import android.content.Intent
import android.net.Uri
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges shared `.tpt` trip files into Flutter. When the app is opened by
 * tapping a trip file (ACTION_VIEW) or receiving one from the share sheet
 * (ACTION_SEND), the file's bytes are read here and handed to Dart over a
 * [MethodChannel] as Base64. A cold-start file is buffered until Dart pulls it
 * via `getInitialTrip`; a file opened while running is pushed via
 * `onTripReceived`.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "dev.calyptra.pappus/trip_import"
    private var channel: MethodChannel? = null

    /** Bytes from a launch intent, waiting for Dart to request them. */
    private var pendingTrip: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialTrip") {
                result.success(pendingTrip)
                pendingTrip = null
            } else {
                result.notImplemented()
            }
        }
        // The intent that launched us (cold start): buffer it — Dart isn't
        // listening for pushes yet, so it will pull via getInitialTrip.
        pendingTrip = readTrip(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Opened while already running: push straight to Dart if it's ready,
        // otherwise buffer for the next getInitialTrip.
        val encoded = readTrip(intent) ?: return
        val mc = channel
        if (mc != null) {
            mc.invokeMethod("onTripReceived", encoded)
        } else {
            pendingTrip = encoded
        }
    }

    /** Reads the trip file referenced by [intent], as Base64, or null. */
    private fun readTrip(intent: Intent?): String? {
        if (intent == null) return null
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
            else -> null
        }
        if (uri == null) return null
        return try {
            contentResolver.openInputStream(uri)?.use { stream ->
                Base64.encodeToString(stream.readBytes(), Base64.NO_WRAP)
            }
        } catch (e: Exception) {
            Log.e("TripShare", "Failed to read shared trip file", e)
            null
        }
    }
}
