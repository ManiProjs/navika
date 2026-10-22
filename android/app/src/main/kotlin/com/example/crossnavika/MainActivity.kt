package com.example.navika

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.DocumentsContract
import android.media.MediaMetadataRetriever
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val channelName = "app.navika/local_folders"
    private val pickFolderRequest = 4817
    private var pendingFolderResult: MethodChannel.Result? = null
    private val ioExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickFolder" -> {
                        if (pendingFolderResult != null) {
                            result.error("picker_busy", "A folder picker is already open", null)
                            return@setMethodCallHandler
                        }
                        pendingFolderResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                        }
                        try {
                            startActivityForResult(intent, pickFolderRequest)
                        } catch (error: Exception) {
                            pendingFolderResult = null
                            result.error("picker_failed", error.message, null)
                        }
                    }
                    "scanFolder" -> {
                        val rawUri = call.argument<String>("uri")
                        if (rawUri.isNullOrBlank()) {
                            result.error("invalid_uri", "Missing folder URI", null)
                        } else {
                            ioExecutor.execute {
                                try {
                                    val files = scanTree(Uri.parse(rawUri))
                                    runOnUiThread { result.success(files) }
                                } catch (error: Exception) {
                                    runOnUiThread {
                                        result.error("scan_failed", error.message ?: error.toString(), null)
                                    }
                                }
                            }
                        }
                    }
                    "readMetadata" -> {
                        val rawUri = call.argument<String>("uri")
                        if (rawUri.isNullOrBlank()) {
                            result.error("invalid_uri", "Missing audio URI", null)
                        } else {
                            ioExecutor.execute {
                                val retriever = MediaMetadataRetriever()
                                try {
                                    val audioUri = Uri.parse(rawUri)
                                    retriever.setDataSource(this, audioUri)
                                    val displayName = contentResolver.query(
                                        audioUri,
                                        arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME),
                                        null,
                                        null,
                                        null,
                                    )?.use { cursor ->
                                        if (cursor.moveToFirst()) cursor.getString(0) else null
                                    }
                                    val metadata = mapOf(
                                        "title" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE),
                                        "artist" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
                                            ?: retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUMARTIST)),
                                        "album" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM),
                                        "duration" to retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)
                                            ?.toLongOrNull()?.div(1000L),
                                        "artwork" to retriever.embeddedPicture,
                                        "fileName" to displayName,
                                    )
                                    runOnUiThread { result.success(metadata) }
                                } catch (error: Exception) {
                                    runOnUiThread { result.error("metadata_failed", error.message, null) }
                                } finally {
                                    retriever.release()
                                }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android API; required for the FlutterActivity result callback")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickFolderRequest) return

        val result = pendingFolderResult ?: return
        pendingFolderResult = null
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        val uri = data.data!!
        val flags = data.flags and
            (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
        try {
            val readPermission = flags and Intent.FLAG_GRANT_READ_URI_PERMISSION
            if (readPermission == 0) {
                result.error("permission_failed", "Android did not grant read access to that folder", null)
                return
            }
            contentResolver.takePersistableUriPermission(uri, readPermission)
            result.success(mapOf("uri" to uri.toString(), "label" to (uri.lastPathSegment ?: "Selected folder")))
        } catch (error: Exception) {
            result.error("permission_failed", "Could not retain folder access: ${error.message}", null)
        }
    }

    private fun scanTree(treeUri: Uri): List<String> {
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        val discovered = mutableListOf<String>()
        val pending = ArrayDeque<String>()
        pending.add(rootId)

        while (pending.isNotEmpty()) {
            val parentId = pending.removeFirst()
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentId)
            val projection = arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            )
            val cursor: Cursor = contentResolver.query(childrenUri, projection, null, null, null)
                ?: throw IllegalStateException("Android could not read this folder. Re-select it to grant access.")
            cursor.use {
                val idColumn = it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
                val nameColumn = it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
                val mimeColumn = it.getColumnIndexOrThrow(DocumentsContract.Document.COLUMN_MIME_TYPE)

                while (it.moveToNext()) {
                    val documentId = it.getString(idColumn)
                    val name = it.getString(nameColumn) ?: "audio"
                    val mime = it.getString(mimeColumn)
                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        pending.add(documentId)
                        continue
                    }
                    if (!isAudio(name, mime)) continue

                    val documentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, documentId)
                    // Keep the provider URI. Copying each song into app storage
                    // duplicated entire music libraries and could consume GBs.
                    discovered.add(documentUri.toString())
                }
            }
        }
        return discovered
    }

    private fun isAudio(name: String, mime: String?): Boolean {
        val extension = name.substringAfterLast('.', "").lowercase()
        return extension in setOf(
            "mp3", "m4a", "m4b", "m4p", "aac", "adts", "wav", "wave", "bwf",
            "flac", "ogg", "oga", "opus", "aiff", "aif", "alac", "ape", "wv",
            "mp4", "3gp", "mka", "webm", "wma", "mid", "midi", "caf", "amr",
            "ac3", "dts", "dsf", "dff", "mpc", "tak"
        ) || mime?.startsWith("audio/") == true
    }

    override fun onDestroy() {
        ioExecutor.shutdown()
        super.onDestroy()
    }
}
