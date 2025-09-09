package com.example.quick_photo_sorter

import android.Manifest
import android.content.ContentResolver
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val DELETION_CHANNEL = "com.example.quick_photo_sorter/deletion"
    private val STORAGE_PERMISSION_CODE = 1001

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DELETION_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deletePhotos" -> {
                        val photos = call.argument<List<Map<String, String>>>("photos")
                        if (photos != null) {
                            deletePhotos(photos, result)
                        } else {
                            result.error("INVALID_ARGUMENTS", "Photo data not provided", null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun deletePhotos(photos: List<Map<String, String>>, result: MethodChannel.Result) {
        // Check permissions first
        if (!hasStoragePermissions()) {
            requestStoragePermissions()
            result.error("PERMISSION_DENIED", "Storage permissions required", null)
            return
        }

        try {
            var deletedCount = 0
            val contentResolver: ContentResolver = contentResolver

            for (photoData in photos) {
                val photoId = photoData["id"]
                val photoPath = photoData["path"]
                
                if (photoId != null && photoPath != null) {
                    val deleted = deletePhotoByPath(contentResolver, photoId, photoPath)
                    if (deleted) {
                        deletedCount++
                    }
                }
            }

            result.success(mapOf(
                "success" to true,
                "deletedCount" to deletedCount,
                "totalRequested" to photos.size
            ))

        } catch (e: Exception) {
            result.error("DELETE_FAILED", "Deletion failed: ${e.message}", null)
        }
    }

    private fun deletePhotoByPath(contentResolver: ContentResolver, photoId: String, photoPath: String): Boolean {
        return try {
            // For Android 10+ (API 29+), we need to use MediaStore properly
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Try to find the media item by its path
                val projection = arrayOf(MediaStore.Images.Media._ID)
                val selection = "${MediaStore.Images.Media.DATA} = ?"
                val selectionArgs = arrayOf(photoPath)
                
                val cursor = contentResolver.query(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                    projection,
                    selection,
                    selectionArgs,
                    null
                )
                
                cursor?.use {
                    if (it.moveToFirst()) {
                        val id = it.getLong(it.getColumnIndexOrThrow(MediaStore.Images.Media._ID))
                        val uri = Uri.withAppendedPath(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id.toString())
                        val deletedRows = contentResolver.delete(uri, null, null)
                        return deletedRows > 0
                    }
                }
                return false
            } else {
                // For older Android versions, try direct file deletion
                val file = File(photoPath)
                if (file.exists()) {
                    val deleted = file.delete()
                    if (deleted) {
                        // Also remove from MediaStore
                        val selection = "${MediaStore.Images.Media.DATA} = ?"
                        val selectionArgs = arrayOf(photoPath)
                        contentResolver.delete(
                            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                            selection,
                            selectionArgs
                        )
                    }
                    return deleted
                }
                return false
            }
        } catch (e: SecurityException) {
            // Handle security exceptions for newer Android versions
            false
        } catch (e: Exception) {
            false
        }
    }

    private fun hasStoragePermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Android 13+ (API 33+)
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_MEDIA_IMAGES) == PackageManager.PERMISSION_GRANTED
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10-12 (API 29-32)
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        } else {
            // Android 9 and below (API 28-)
            ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestStoragePermissions() {
        val permissions = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            arrayOf(Manifest.permission.READ_MEDIA_IMAGES)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        } else {
            arrayOf(
                Manifest.permission.READ_EXTERNAL_STORAGE,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            )
        }

        ActivityCompat.requestPermissions(this, permissions, STORAGE_PERMISSION_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == STORAGE_PERMISSION_CODE) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            // Permission result handled - you could notify Flutter if needed
        }
    }
}