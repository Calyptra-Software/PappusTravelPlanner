package dev.calyptra.pappus

import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Asking for `POST_NOTIFICATIONS`, the one thing the track recorder wants from
 * Android 13 onwards and nothing else in the app does.
 *
 * A recording runs in geolocator's foreground service, and that service posts a
 * notification whether or not this is granted: without it, Android 13 and later
 * keep the notification out of the drawer and show the running service only in
 * the quick settings' task manager. So the answer changes what the user *sees*
 * and never whether the recording works, which is why the Dart side asks on the
 * record press and goes on regardless of what comes back.
 *
 * One method, `request`, answering whether notifications may be posted. Below
 * Android 13 there is no such permission and the answer is always yes; where the
 * user has refused for good, Android answers without showing a dialog.
 */
class NotificationPermission(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        const val CHANNEL = "dev.calyptra.pappus/notifications"

        /** Ours among whatever else the activity asks for. */
        const val REQUEST_CODE = 0x9108
    }

    private val channel = MethodChannel(messenger, CHANNEL)

    /** The `request` call waiting for the dialog's answer, if one is open. */
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(::onMethodCall)
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "request" -> request(result)
            else -> result.notImplemented()
        }
    }

    private fun granted(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            activity.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED

    /**
     * Shows the system dialog where there is one to show. A second call while
     * one is open is answered with the current state rather than queued, as in
     * [MediaLocationBridge]: a result that is never completed hangs the press
     * waiting for it.
     */
    private fun request(result: MethodChannel.Result) {
        if (granted() || pending != null) {
            result.success(granted())
            return
        }
        pending = result
        activity.requestPermissions(
            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
            REQUEST_CODE
        )
    }

    /** The dialog's answer. Returns whether it was ours. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        result.success(
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        )
        return true
    }
}
