package dev.calyptra.pappus

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hands a copy of an attachment to whatever app on the device views its type.
 *
 * The Dart side writes the copy into `cache/opened/` (`open_file_io.dart`);
 * this turns the path into a `content://` URI of [DocumentFileProvider] and
 * starts `ACTION_VIEW` with a one-off read grant. No permission is involved on
 * either side: the viewer is granted this one URI for as long as it holds it,
 * and nothing outside `cache/opened/` can be named through the provider at all
 * (`res/xml/opened_documents.xml`).
 *
 * `open` answers whether an app took the file. `false` is never a crash: the
 * Dart side opens the attachment's sheet and offers *Share* instead.
 */
class DocumentOpener(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        const val CHANNEL = "dev.calyptra.pappus/open_document"
        private const val TAG = "DocumentOpener"
        private const val UNTYPED = "application/octet-stream"
    }

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "open") {
                result.success(open(call.argument<String>("path"), call.argument<String>("mimeType")))
            } else {
                result.notImplemented()
            }
        }
    }

    private fun open(path: String?, mimeType: String?): Boolean {
        if (path == null) return false
        val file = File(path)
        val type = typeOf(file, mimeType) ?: return false
        val uri = try {
            FileProvider.getUriForFile(activity, "${activity.packageName}.opened", file)
        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "Not a path the provider serves: $path", e)
            return false
        }
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, type)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        return try {
            activity.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }

    /**
     * The media type to open [file] as, or null for none worth sending.
     *
     * The stored type first, else the platform's reading of the extension. A
     * file still untyped after both is not sent at all: `application/octet-stream`
     * is exactly the type this app's own `.tpt` filter answers, so the viewer
     * offered — or started outright — would be Pappus importing the file as a
     * trip. Sharing is the honest route for a file nobody can name.
     */
    private fun typeOf(file: File, mimeType: String?): String? {
        if (mimeType != null && mimeType != UNTYPED) return mimeType
        val guessed = MimeTypeMap.getSingleton()
            .getMimeTypeFromExtension(file.extension.lowercase())
        return guessed?.takeIf { it != UNTYPED }
    }
}

/**
 * A provider of its own rather than `androidx.core`'s class named directly: two
 * manifests declaring the same provider class cannot be merged, and a plugin
 * may one day bring one.
 */
class DocumentFileProvider : FileProvider()
