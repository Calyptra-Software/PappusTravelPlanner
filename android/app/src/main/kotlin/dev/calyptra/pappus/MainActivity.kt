package dev.calyptra.pappus

import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/**
 * Bridges shared `.tpt` trip files into Flutter. When the app is opened by
 * tapping a trip file (ACTION_VIEW) or receiving one from the share sheet
 * (ACTION_SEND), the file is copied into `cache/received/` off the main thread
 * and its path handed to Dart over a [MethodChannel]; Dart reads the copy and
 * deletes it. A cold-start file waits until Dart asks via `getInitialTrip`; a
 * file opened while running is pushed via `onTripReceived`, or `onTripFailed`
 * when it cannot be read.
 *
 * The bytes never cross the channel: a trip with photos runs to tens of
 * megabytes, and as a Base64 string on the Java heap it took about five times
 * that, past the heap limit, so the app died on launch.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "dev.calyptra.pappus/trip_import"
    private var channel: MethodChannel? = null

    /** The trip file of a launch intent, waiting for Dart to request it. */
    private var pendingTrip: Uri? = null

    /** Copies received trip files off the main thread, one at a time. */
    private val copier = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    /** ACCESS_MEDIA_LOCATION: asking for it, and reading a photo's original. */
    private var mediaLocation: MediaLocationBridge? = null

    /** POST_NOTIFICATIONS, asked for on the record press. */
    private var notifications: NotificationPermission? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialTrip") {
                val uri = pendingTrip
                pendingTrip = null
                if (uri == null) {
                    result.success(null)
                } else {
                    copyTrip(uri) { path ->
                        if (path != null) {
                            result.success(path)
                        } else {
                            result.error("unreadable", "Could not read the trip file", null)
                        }
                    }
                }
            } else {
                result.notImplemented()
            }
        }
        mediaLocation = MediaLocationBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        notifications = NotificationPermission(this, flutterEngine.dartExecutor.binaryMessenger)
        DocumentOpener(this, flutterEngine.dartExecutor.binaryMessenger)
        // The intent that launched us (cold start): buffer it — Dart isn't
        // listening for pushes yet, so it will pull via getInitialTrip.
        pendingTrip = tripUri(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Opened while already running: push straight to Dart if it's ready,
        // otherwise buffer for the next getInitialTrip.
        val uri = tripUri(intent) ?: return
        val mc = channel
        if (mc == null) {
            pendingTrip = uri
            return
        }
        copyTrip(uri) { path ->
            if (path != null) {
                mc.invokeMethod("onTripReceived", path)
            } else {
                mc.invokeMethod("onTripFailed", null)
            }
        }
    }

    override fun onDestroy() {
        // Lets a copy already under way finish; nothing new is accepted.
        copier.shutdown()
        super.onDestroy()
    }

    /**
     * `super` first, so the plugins that asked for a permission of their own
     * (the map's location, for one) still get their answer: ours is one request
     * code among several, and the bridge says whether the result was its.
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        mediaLocation?.onRequestPermissionsResult(requestCode, grantResults)
        notifications?.onRequestPermissionsResult(requestCode, grantResults)
    }

    /** The trip file referenced by [intent], or null. */
    private fun tripUri(intent: Intent?): Uri? = when (intent?.action) {
        Intent.ACTION_VIEW -> intent.data
        Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
        else -> null
    }

    /**
     * Copies [uri] into the cache on [copier] and calls [done] on the main
     * thread with the copy's path, or null when it could not be read.
     */
    private fun copyTrip(uri: Uri, done: (String?) -> Unit) {
        copier.execute {
            val path = copyToCache(uri)
            mainHandler.post { done(path) }
        }
    }

    /**
     * Streams [uri] into a new file under `cache/received/`, so the whole file
     * is never held in memory here. Returns the copy's path, or null.
     */
    private fun copyToCache(uri: Uri): String? {
        var copy: File? = null
        return try {
            val dir = File(cacheDir, "received").apply { mkdirs() }
            val target = File.createTempFile("trip", ".tpt", dir)
            copy = target
            val input = contentResolver.openInputStream(uri)
                ?: throw IOException("No stream for $uri")
            input.use { source -> target.outputStream().use { source.copyTo(it) } }
            target.path
        } catch (e: Exception) {
            Log.e("TripShare", "Failed to read shared trip file", e)
            copy?.delete()
            null
        }
    }
}
