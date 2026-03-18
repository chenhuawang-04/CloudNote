package com.example.client

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channel = "cloudnote/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                val bytes = call.argument<ByteArray>("bytes")
                val fileName = call.argument<String>("fileName")
                val mimeType = call.argument<String>("mimeType")
                if (bytes == null || fileName.isNullOrBlank()) {
                    result.error("invalid_args", "bytes and fileName are required", null)
                    return@setMethodCallHandler
                }
                try {
                    val uri = saveToDownloads(bytes, fileName, mimeType)
                    result.success(uri?.toString())
                } catch (e: Exception) {
                    result.error("save_failed", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveToDownloads(bytes: ByteArray, fileName: String, mimeType: String?): android.net.Uri? {
        val resolver = applicationContext.contentResolver
        val values = ContentValues()
        var finalName = fileName

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            if (!downloads.exists()) {
                downloads.mkdirs()
            }
            var target = File(downloads, finalName)
            if (target.exists()) {
                val dot = finalName.lastIndexOf('.')
                val base = if (dot > 0) finalName.substring(0, dot) else finalName
                val ext = if (dot > 0) finalName.substring(dot) else ""
                finalName = "${base}_${System.currentTimeMillis()}$ext"
                target = File(downloads, finalName)
            }
            values.put(MediaStore.MediaColumns.DATA, target.absolutePath)
        }

        values.put(MediaStore.MediaColumns.DISPLAY_NAME, finalName)
        if (!mimeType.isNullOrBlank()) {
            values.put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            values.put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        } else {
            MediaStore.Files.getContentUri("external")
        }

        val uri = resolver.insert(collection, values) ?: return null
        resolver.openOutputStream(uri)?.use { it.write(bytes) }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }

        return uri
    }
}
