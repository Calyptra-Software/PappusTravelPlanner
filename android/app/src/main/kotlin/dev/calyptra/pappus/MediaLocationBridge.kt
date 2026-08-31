package dev.calyptra.pappus

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * The one thing Android takes out of a photograph, and the permission that puts
 * it back.
 *
 * Since Android 10 the system zeroes `GPSLatitude`/`GPSLongitude` in a picture
 * handed to an app that does not hold `ACCESS_MEDIA_LOCATION`. Nothing in the
 * Dart can see the difference between that and a camera that never had a fix —
 * which is why `exifLocationRedacted` exists on the other side — and nothing in
 * the Dart can undo it either: the permission is granted to a *process*, and the
 * unredacted bytes are asked for through `MediaStore`.
 *
 * So this bridge answers exactly three questions and does one job:
 *
 * * `status` / `request` — where the permission stands, and asking for it. It is
 *   requested on the switch in settings and at no other moment, the arrangement
 *   the map's locate button already has.
 * * `openSettings` — the way back when the platform will not ask again.
 * * `readLocation` — the position of one picked photograph, read from the
 *   original bytes. Only the coordinates cross the channel; the picture the app
 *   stores is still the re-encoded, EXIF-stripped one that `attachment_import`
 *   makes, so holding the permission changes what the app *knows* and not what
 *   it keeps.
 */
class MediaLocationBridge(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        const val CHANNEL = "dev.calyptra.pappus/media_location"
        private const val TAG = "MediaLocation"

        /** Ours among whatever else the activity asks for. */
        const val REQUEST_CODE = 0x9107

        private const val PERMISSION = android.Manifest.permission.ACCESS_MEDIA_LOCATION

        /** Nothing is redacted before Android 10, so there is nothing to ask for. */
        private const val NOT_NEEDED = "notNeeded"
        private const val GRANTED = "granted"
        private const val DENIED = "denied"

        /**
         * Declined in a way the platform will not ask about again — the only
         * state where the app has to send the user to a system screen instead
         * of showing a dialog itself.
         */
        private const val DENIED_FOREVER = "deniedForever"
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    /** The `request` call waiting for the dialog's answer, if one is open. */
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "request" -> request(result)
            "openSettings" -> {
                openSettings()
                result.success(null)
            }
            "readLocation" -> result.success(readLocation(call.argument<String>("uri")))
            else -> result.notImplemented()
        }
    }

    private fun status(): String = when {
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q -> NOT_NEEDED
        activity.checkSelfPermission(PERMISSION) == PackageManager.PERMISSION_GRANTED -> GRANTED
        else -> DENIED
    }

    /**
     * Shows the system dialog, once. A second call while one is open is
     * answered with the current state rather than queued: two dialogs cannot be
     * on screen at the same time, and a result that is never completed hangs the
     * switch that is waiting for it.
     */
    private fun request(result: MethodChannel.Result) {
        val current = status()
        if (current != DENIED || pending != null) {
            result.success(current)
            return
        }
        pending = result
        activity.requestPermissions(arrayOf(PERMISSION), REQUEST_CODE)
    }

    /**
     * The dialog's answer. Returns whether it was ours, so the activity can go
     * on offering the result to everything else that asked for a permission.
     *
     * "Denied forever" is read off `shouldShowRequestPermissionRationale`, which
     * is only meaningful *here*: before a request it cannot tell "never asked"
     * from "asked and permanently refused", and after one it separates the two
     * exactly.
     */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        result.success(
            when {
                granted -> GRANTED
                activity.shouldShowRequestPermissionRationale(PERMISSION) -> DENIED
                else -> DENIED_FOREVER
            }
        )
        return true
    }

    private fun openSettings() {
        try {
            activity.startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", activity.packageName, null)
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "No app-details screen to open", e)
        }
    }

    /**
     * Where the camera stood, read from the original of the file behind [uriString].
     *
     * The picker hands back a copy it made with a plain `openInputStream`, and
     * that copy is redacted whatever this process holds. Asking again is
     * therefore not a duplicate read but the only one that can answer: the
     * unredacted bytes come from a `MediaStore` URI carrying `requireOriginal`,
     * which is what [MediaStore.setRequireOriginal] adds and what
     * [MediaStore.getMediaUri] gets us to from the document URI the Storage
     * Access Framework returned.
     *
     * Every step of that is allowed to fail — a picture on a cloud provider has
     * no MediaStore row, a file manager may hand back a URI from a provider of
     * its own — and a failure means one photograph attaches without a position,
     * which the app already has a sentence for. Null is the answer to all of
     * them; nothing here throws into Dart.
     */
    private fun readLocation(uriString: String?): Map<String, Double>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        if (uriString == null || status() != GRANTED) return null
        val uri = runCatching { Uri.parse(uriString) }.getOrNull() ?: return null
        val media = runCatching {
            MediaStore.getMediaUri(activity, uri)
        }.getOrNull() ?: return null
        val original = runCatching {
            MediaStore.setRequireOriginal(media)
        }.getOrNull() ?: return null
        return try {
            activity.contentResolver.openInputStream(original)?.use { stream ->
                // The framework's reader, not the AndroidX one: it has read EXIF
                // out of a stream since API 24, and a second copy of an EXIF
                // parser is not worth a dependency for two numbers.
                val exif = android.media.ExifInterface(stream)
                val lat = degrees(
                    exif.getAttribute(android.media.ExifInterface.TAG_GPS_LATITUDE),
                    exif.getAttribute(android.media.ExifInterface.TAG_GPS_LATITUDE_REF),
                    "S"
                )
                val lon = degrees(
                    exif.getAttribute(android.media.ExifInterface.TAG_GPS_LONGITUDE),
                    exif.getAttribute(android.media.ExifInterface.TAG_GPS_LONGITUDE_REF),
                    "W"
                )
                if (lat == null || lon == null) null
                else mapOf("lat" to lat, "lon" to lon)
            }
        } catch (e: Exception) {
            // Includes the SecurityException a provider throws when it will not
            // serve the original, which is an answer and not a crash.
            Log.w(TAG, "Could not read the original of $uriString", e)
            null
        }
    }

    /**
     * Degrees, minutes and seconds as EXIF writes them — `"53/1,33/1,367/100"` —
     * folded into one number, negated by the hemisphere letter.
     *
     * The rationals are read rather than `getLatLong`, which hands back floats
     * and would round a coordinate at about a metre before it is ever stored.
     * This is the same arithmetic `exifPosition` does on the Dart side, on the
     * same three values, so the two routes to a photograph's place cannot
     * disagree about what it is.
     *
     * A denominator of zero is what a redaction leaves behind, and it comes back
     * as null here rather than as a coordinate of nothing.
     */
    private fun degrees(value: String?, ref: String?, negative: String): Double? {
        val parts = value?.split(',') ?: return null
        if (parts.size < 3) return null
        var total = 0.0
        var divisor = 1.0
        for (i in 0 until 3) {
            val pair = parts[i].split('/')
            if (pair.size != 2) return null
            val numerator = pair[0].trim().toDoubleOrNull() ?: return null
            val denominator = pair[1].trim().toDoubleOrNull() ?: return null
            if (denominator == 0.0) return null
            total += numerator / denominator / divisor
            divisor *= 60
        }
        val negated = ref?.trim()?.uppercase()?.startsWith(negative) == true
        return if (negated) -total else total
    }
}
