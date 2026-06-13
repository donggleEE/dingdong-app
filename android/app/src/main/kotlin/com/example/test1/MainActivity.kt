package com.example.test1

import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ding_dong/background_belt")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val userId = call.argument<String>("userId")
                        if (userId.isNullOrBlank()) {
                            result.error("missing_user", "userId is required", null)
                            return@setMethodCallHandler
                        }
                        val intent = Intent(this, BackgroundBeltService::class.java)
                            .putExtra(BackgroundBeltService.EXTRA_USER_ID, userId)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        stopService(Intent(this, BackgroundBeltService::class.java))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ding_dong/sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playAsset" -> {
                        val asset = call.argument<String>("asset")
                        if (asset.isNullOrBlank()) {
                            result.error("missing_asset", "asset is required", null)
                            return@setMethodCallHandler
                        }
                        try {
                            playFlutterAsset(asset)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("play_failed", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        mediaPlayer?.release()
        mediaPlayer = null
        super.onDestroy()
    }

    private fun playFlutterAsset(asset: String) {
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        val soundFile = File(cacheDir, "notification_sound_${asset.substringAfterLast('/')}")
        assets.open(key).use { input ->
            soundFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        mediaPlayer?.release()
        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            setDataSource(soundFile.absolutePath)
            setVolume(1.0f, 1.0f)
            setOnCompletionListener {
                it.release()
                if (mediaPlayer === it) mediaPlayer = null
            }
            prepare()
            start()
        }
    }
}
