package dev.takt.takt

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.Settings
import android.provider.DocumentsContract
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

// Android owns permission dialogs, MediaStore access and system-approved deletion.
class MainActivity : AudioServiceActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val ui = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var pendingScan: (() -> Unit)? = null
    private val artworkChecked = mutableSetOf<String>()
    private var pendingFolder: MethodChannel.Result? = null
    private var pendingNotifications: MethodChannel.Result? = null
    private var pendingDelete: MethodChannel.Result? = null
    private lateinit var analyzer: AudioAnalyzer
    private val observer = object : ContentObserver(ui) {
        override fun onChange(selfChange: Boolean) { channel?.invokeMethod("mediaChanged", null) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        analyzer = AudioAnalyzer(this, flutterEngine.dartExecutor.binaryMessenger)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "takt/android")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "scan" -> {
                    val directory = call.argument<String>("artworkDirectory") ?: "$filesDir/artwork"
                    val sources = call.argument<List<String>>("sources") ?: emptyList()
                    val scan = { readLibrary(directory, sources, result) }
                    if (checkSelfPermission(Manifest.permission.READ_MEDIA_AUDIO) == PackageManager.PERMISSION_GRANTED) scan()
                    else if (call.argument<Boolean>("requestPermission") != true) result.success(null)
                    else if (pendingScan != null) result.error("busy", "Permission request already open", null)
                    else {
                        pendingScan = scan
                        requestPermissions(arrayOf(Manifest.permission.READ_MEDIA_AUDIO), 100)
                    }
                }
                "folders" -> {
                    worker.execute {
                        try {
                            val folders = sortedSetOf<String>()
                            contentResolver.query(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                                arrayOf("volume_name", "relative_path"), "is_pending=0 AND is_trashed=0", null, null)?.use { cursor ->
                                while (cursor.moveToNext()) folders.add("${cursor.getString(0)}:${cursor.getString(1) ?: ""}")
                            }
                            ui.post { result.success(folders.toList()) }
                        } catch (e: Exception) { ui.post { result.error("folders", e.message, null) } }
                    }
                }
                "notifications" -> {
                    if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) result.success(true)
                    else if (pendingNotifications != null) result.error("busy", "Permission request already open", null)
                    else { pendingNotifications = result; requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 103) }
                }
                "pickFolder" -> {
                    if (pendingFolder != null) result.error("busy", "Folder picker already open", null)
                    else { pendingFolder = result; startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), 102) }
                }
                "appSettings" -> {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                    result.success(null)
                }
                "delete" -> {
                    if (pendingDelete != null) result.error("busy", "Deletion request already open", null)
                    else try {
                        val uris = call.argument<List<String>>("uris")!!.map(Uri::parse)
                        val request = MediaStore.createDeleteRequest(contentResolver, uris)
                        pendingDelete = result
                        startIntentSenderForResult(request.intentSender, 101, null, 0, 0, 0)
                    } catch (e: Exception) { pendingDelete = null; result.error("delete", e.message, null) }
                }
                "background" -> { moveTaskToBack(true); result.success(null) }
                "quit" -> {
                    analyzer.cancel()
                    result.success(null)
                    finishAndRemoveTask()
                    ui.postDelayed({ android.os.Process.killProcess(android.os.Process.myPid()) }, 400)
                }
                "analyze" -> { analyzer.load(call.argument<String>("uri")!!, call.argument<Int>("generation")!!, call.argument<Number>("position")?.toLong() ?: 0L); result.success(null) }
                "analysisActive" -> { analyzer.active = call.argument<Boolean>("active") == true; result.success(null) }
                "analysisPosition" -> { analyzer.positionMs = call.argument<Number>("position")!!.toLong(); result.success(null) }
                "analysisCancel" -> { analyzer.cancel(); result.success(null) }
                else -> result.notImplemented()
            }
        }
        contentResolver.registerContentObserver(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, true, observer)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 103) { pendingNotifications?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED); pendingNotifications = null }
        if (requestCode == 100) {
            val scan = pendingScan
            pendingScan = null
            scan?.invoke()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 102) {
            val uri = data?.data
            val value = if (resultCode == Activity.RESULT_OK && uri != null) {
                val document = DocumentsContract.getTreeDocumentId(uri)
                val volume = document.substringBefore(':').let { if (it == "primary") "external_primary" else it.lowercase() }
                if (volume !in MediaStore.getExternalVolumeNames(this)) {
                    pendingFolder?.error("local_folder", "Choose a folder on this device or SD card", null)
                    pendingFolder = null
                    return
                }
                val path = document.substringAfter(':', "").trim('/')
                "$volume:${if (path.isEmpty()) "" else "$path/"}"
            } else null
            pendingFolder?.success(value); pendingFolder = null
        }
        if (requestCode == 101) { pendingDelete?.success(resultCode == Activity.RESULT_OK); pendingDelete = null }
    }

    private fun readLibrary(directory: String, configured: List<String>, result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.READ_MEDIA_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            result.success(null)
            return
        }
        worker.execute {
            try {
                val rows = ArrayList<Map<String, Any?>>()
                val columns = arrayOf("_id", "title", "artist", "album", "duration", "volume_name", "_display_name", "date_modified", "relative_path")
                val covers = File(directory).apply { mkdirs() }
                var selected = configured
                contentResolver.query(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, columns,
                    "is_pending=0 AND is_trashed=0", null, "title COLLATE NOCASE ASC")?.use { cursor ->
                    if (selected.isEmpty()) {
                        val counts = mutableMapOf<String, Int>()
                        while (cursor.moveToNext()) {
                            val source = "${cursor.getString(5)}:${cursor.getString(8) ?: ""}"
                            counts[source] = (counts[source] ?: 0) + 1
                        }
                        val preferred = "external_primary:Music/"
                        val initial = if (counts.keys.any { it.startsWith(preferred) }) preferred else counts.maxByOrNull { it.value }?.key
                        selected = listOfNotNull(initial)
                        cursor.moveToPosition(-1)
                    }
                    while (cursor.moveToNext()) {
                        val volume = cursor.getString(5)
                        val relative = cursor.getString(8) ?: ""
                        if (selected.none { it.substringBefore(':') == volume && relative.startsWith(it.substringAfter(':')) }) continue
                        // Store the actual directory so overlapping parent/subfolder views both work.
                        val source = "$volume:$relative"
                        val id = cursor.getLong(0)
                        val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.getContentUri(volume), id)
                        val key = "android-$volume-$id"
                        val cover = File(covers, "$key.jpg")
                        if (!cover.exists() && artworkChecked.add("$key-${cursor.getLong(7)}")) {
                            val retriever = MediaMetadataRetriever()
                            try {
                                retriever.setDataSource(this, uri)
                                retriever.embeddedPicture?.let { bytes ->
                                    val options = android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds = true }
                                    android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                                    options.inSampleSize = maxOf(1, maxOf(options.outWidth, options.outHeight) / 600)
                                    options.inJustDecodeBounds = false
                                    android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)?.let { bitmap ->
                                        cover.outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 88, it) }
                                        bitmap.recycle()
                                    }
                                }
                            } catch (_: Exception) { /* A missing cover must not reject a playable track. */ }
                            finally { retriever.release() }
                        }
                        fun tag(index: Int) = cursor.getString(index)?.takeUnless { it == "<unknown>" } ?: ""
                        rows.add(mapOf("source" to source, "id" to key, "path" to uri.toString(),
                            "title" to tag(1).ifBlank { tag(6).substringBeforeLast('.') },
                            "artist" to tag(2), "album" to tag(3),
                            "seconds" to cursor.getLong(4) / 1000.0,
                            "artwork" to cover.path.takeIf { cover.exists() }))
                    }
                }
                ui.post { result.success(mapOf("tracks" to rows, "sources" to selected)) }
            } catch (e: Exception) { ui.post { result.error("library", e.message, null) } }
        }
    }

    override fun onDestroy() {
        contentResolver.unregisterContentObserver(observer)
        worker.shutdownNow()
        super.onDestroy()
    }
}
