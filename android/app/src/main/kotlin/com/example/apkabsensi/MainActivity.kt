package com.example.apkabsensi

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.DocumentsContract
import android.util.Log
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private var safResult: MethodChannel.Result? = null
    private val TAG = "MainActivity"

    companion object {
        private const val OPEN_DOCUMENT_TREE_REQUEST_CODE = 1
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "saf_channel").setMethodCallHandler { call, result ->
            when (call.method) {
                "openDocumentTree" -> {
                    safResult = result
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                        startActivityForResult(intent, OPEN_DOCUMENT_TREE_REQUEST_CODE)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error launching document tree picker: ${e.message}", e)
                        result.error("LAUNCH_ERROR", e.message, null)
                        safResult = null
                    }
                }
                "writeFileToUri" -> {
                    try {
                        val uriString = call.argument<String>("uri")
                        val fileName = call.argument<String>("fileName")
                        val bytes = call.argument<ByteArray>("bytes")
                        val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                        
                        if (uriString == null) {
                            result.error("NULL_URI", "URI tidak boleh null", null)
                            return@setMethodCallHandler
                        }
                        
                        if (fileName == null) {
                            result.error("NULL_FILENAME", "Nama file tidak boleh null", null)
                            return@setMethodCallHandler
                        }
                        
                        if (bytes == null) {
                            result.error("NULL_DATA", "Data file tidak boleh null", null)
                            return@setMethodCallHandler
                        }
                        
                        val treeUri = Uri.parse(uriString)
                        
                        // Pastikan kita masih punya izin untuk URI
                        val hasPermission = contentResolver.persistedUriPermissions.any { 
                            it.uri.toString() == uriString && it.isWritePermission 
                        }
                        
                        if (!hasPermission) {
                            result.error("NO_PERMISSION", "Tidak ada izin untuk menulis ke folder ini", null)
                            return@setMethodCallHandler
                        }
                        
                        // Gunakan DocumentFile untuk menavigasi struktur dokumen
                        try {
                            val pickedDir = DocumentFile.fromTreeUri(context, treeUri)
                            if (pickedDir == null) {
                                result.error("INVALID_DIR", "Tidak dapat mengakses direktori", null)
                                return@setMethodCallHandler
                            }
                            
                            // Cek apakah file dengan nama yang sama sudah ada dan hapus jika ada
                            val existingFile = pickedDir.findFile(fileName)
                            existingFile?.delete()
                            
                            // Buat file baru
                            val newFile = pickedDir.createFile(mimeType, fileName)
                            if (newFile == null) {
                                result.error("CREATE_FILE_ERROR", "Tidak dapat membuat file", null)
                                return@setMethodCallHandler
                            }
                            
                            // Tulis konten ke file
                            contentResolver.openOutputStream(newFile.uri)?.use { outputStream ->
                                outputStream.write(bytes)
                                outputStream.flush()
                            }
                            
                            result.success(true)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error creating/writing file: ${e.message}", e)
                            result.error("FILE_OPERATION_ERROR", e.message, null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Unexpected error: ${e.message}", e)
                        result.error("UNEXPECTED_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == OPEN_DOCUMENT_TREE_REQUEST_CODE) {
            val uri = data?.data
            if (uri != null && resultCode == RESULT_OK) {
                try {
                    // Ambil izin persistable untuk uri yang dipilih
                    contentResolver.takePersistableUriPermission(
                        uri,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                    )
                    
                    // Kembalikan uri ke Flutter
                    safResult?.success(uri.toString())
                } catch (e: Exception) {
                    Log.e(TAG, "Error taking persistable URI permission: ${e.message}", e)
                    safResult?.error("PERMISSION_ERROR", e.message, null)
                }
            } else {
                safResult?.success(null)
            }
            safResult = null
        }
    }
}
