package com.example.test1

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.os.IBinder
import android.util.Base64
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.net.Socket
import java.security.SecureRandom
import kotlin.math.abs
import kotlin.math.max

class BackgroundBeltService : Service() {
    private var worker: Thread? = null
    @Volatile private var running = false
    @Volatile private var userId: String? = null
    private var movementActive = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        userId = intent?.getStringExtra(EXTRA_USER_ID)
            ?: getSharedPreferences(PREFS, MODE_PRIVATE).getString(EXTRA_USER_ID, null)
        userId?.let {
            getSharedPreferences(PREFS, MODE_PRIVATE).edit().putString(EXTRA_USER_ID, it).apply()
        }
        startForeground(NOTIFICATION_ID, notification())
        startWorker()
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        worker?.interrupt()
        worker = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startWorker() {
        if (worker?.isAlive == true) return
        running = true
        worker = Thread {
            while (running) {
                try {
                    readWebSocket()
                } catch (_: Exception) {
                    resetMovement()
                    if (running) Thread.sleep(RETRY_INTERVAL_MS)
                }
            }
        }.also {
            it.name = "DingDongBackgroundBelt"
            it.start()
        }
    }

    private fun readWebSocket() {
        Socket(SENSOR_HOST, SENSOR_PORT).use { socket ->
            socket.soTimeout = 0
            val input = BufferedInputStream(socket.getInputStream())
            val output = BufferedOutputStream(socket.getOutputStream())
            val keyBytes = ByteArray(16)
            SecureRandom().nextBytes(keyBytes)
            val key = Base64.encodeToString(keyBytes, Base64.NO_WRAP)
            output.write(
                (
                    "GET / HTTP/1.1\r\n" +
                        "Host: $SENSOR_HOST:$SENSOR_PORT\r\n" +
                        "Upgrade: websocket\r\n" +
                        "Connection: Upgrade\r\n" +
                        "Sec-WebSocket-Key: $key\r\n" +
                        "Sec-WebSocket-Version: 13\r\n\r\n"
                    ).toByteArray(Charsets.US_ASCII)
            )
            output.flush()
            readHandshake(input)
            while (running) {
                val message = readFrame(input) ?: return
                val sample = parseSample(message) ?: continue
                handleSample(sample, System.currentTimeMillis())
            }
        }
    }

    private fun readHandshake(input: BufferedInputStream) {
        var matched = 0
        val end = byteArrayOf(13, 10, 13, 10)
        while (running) {
            val next = input.read()
            if (next < 0) return
            matched = if (next.toByte() == end[matched]) matched + 1 else 0
            if (matched == end.size) return
        }
    }

    private fun readFrame(input: BufferedInputStream): String? {
        val first = input.read()
        if (first < 0) return null
        val second = input.read()
        if (second < 0) return null
        val opcode = first and 0x0F
        val masked = second and 0x80 != 0
        var length = (second and 0x7F).toLong()
        if (length == 126L) {
            length = ((input.read() and 0xFF) shl 8 or (input.read() and 0xFF)).toLong()
        } else if (length == 127L) {
            length = 0
            repeat(8) { length = (length shl 8) or (input.read() and 0xFF).toLong() }
        }
        val mask = if (masked) ByteArray(4).also { input.readFullyCompat(it) } else null
        val payload = ByteArray(length.toInt())
        input.readFullyCompat(payload)
        if (mask != null) {
            for (i in payload.indices) {
                payload[i] = (payload[i].toInt() xor mask[i % 4].toInt()).toByte()
            }
        }
        if (opcode == 8) return null
        if (opcode != 1) return ""
        return payload.toString(Charsets.UTF_8)
    }

    private fun BufferedInputStream.readFullyCompat(buffer: ByteArray) {
        var offset = 0
        while (offset < buffer.size) {
            val count = read(buffer, offset, buffer.size - offset)
            if (count < 0) throw IllegalStateException("socket closed")
            offset += count
        }
    }

    private fun parseSample(message: String): BeltSample? {
        val jsonStart = message.indexOf('{')
        val jsonEnd = message.lastIndexOf('}')
        if (jsonStart < 0 || jsonEnd <= jsonStart) return null
        val data = JSONObject(message.substring(jsonStart, jsonEnd + 1))
        var peak = 0
        for (index in 0 until CHANNEL_COUNT) {
            if (!data.has("c$index")) return null
            val value = data.optDouble("c$index", Double.NaN)
            if (value.isNaN()) return null
            peak = max(peak, value.toInt().coerceIn(0, ADC_MAX))
        }
        val gyroX = flexibleDouble(data, "gx", "gyroX")
        val gyroY = flexibleDouble(data, "gy", "gyroY")
        val gyroZ = flexibleDouble(data, "gz", "gyroZ")
        val moving = isGyroAxisMoving(gyroX) ||
            isGyroAxisMoving(gyroY) ||
            isGyroAxisMoving(gyroZ)
        return BeltSample(peak, moving)
    }

    private fun flexibleDouble(data: JSONObject, vararg keys: String): Double? {
        for (key in keys) {
            if (data.has(key)) return data.optDouble(key)
            val upper = key.replaceFirstChar { it.uppercase() }
            if (data.has(upper)) return data.optDouble(upper)
        }
        return null
    }

    private fun isGyroAxisMoving(value: Double?): Boolean {
        return value != null && !value.isNaN() && abs(value) >= USER_MOTION_GYRO_AXIS_THRESHOLD
    }

    private fun handleSample(sample: BeltSample, sampledAt: Long) {
        val threshold = if (sample.measuredDuringUserMotion) {
            MOVEMENT_THRESHOLD_WHILE_USER_MOVING
        } else {
            MOVEMENT_THRESHOLD
        }
        if (sample.peak > threshold) {
            if (movementActive) return
            movementActive = true
            recordMovement(
                sampledAt,
                sample.peak.coerceIn(threshold + 1, ADC_MAX),
                sample.measuredDuringUserMotion,
            )
            return
        }
        resetMovement()
    }

    private fun resetMovement() {
        movementActive = false
    }

    private fun recordMovement(measuredAt: Long, intensity: Int, measuredDuringUserMotion: Boolean) {
        val currentUserId = userId ?: return
        openOrCreateDatabase().use { db ->
            db.execSQL(
                "INSERT INTO fetal_movement_records (user_id, measured_at, intensity, measured_during_user_motion) VALUES (?, ?, ?, ?)",
                arrayOf<Any>(
                    currentUserId,
                    measuredAt,
                    intensity,
                    if (measuredDuringUserMotion) 1 else 0,
                ),
            )
        }
    }

    private fun openOrCreateDatabase(): SQLiteDatabase {
        val db = SQLiteDatabase.openOrCreateDatabase(getDatabasePath("ding_dong.db"), null)
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS fetal_movement_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT NOT NULL,
                measured_at INTEGER NOT NULL,
                intensity INTEGER NOT NULL,
                measured_during_user_motion INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent()
        )
        try {
            db.execSQL(
                "ALTER TABLE fetal_movement_records ADD COLUMN measured_during_user_motion INTEGER NOT NULL DEFAULT 0"
            )
        } catch (_: Exception) {
        }
        db.execSQL(
            """
            CREATE INDEX IF NOT EXISTS idx_fetal_movement_user_time
            ON fetal_movement_records (user_id, measured_at)
            """.trimIndent()
        )
        return db
    }

    private fun notification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "DingDong Belt", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(android.R.drawable.stat_notify_sync)
            .setContentTitle("DingDong 벨트 연결 중")
            .setContentText("백그라운드에서 WebSocket 센서 값을 확인합니다.")
            .setOngoing(true)
            .build()
    }

    companion object {
        const val EXTRA_USER_ID = "userId"
        private const val PREFS = "background_belt"
        private const val CHANNEL_ID = "background_belt"
        private const val NOTIFICATION_ID = 3105
        private const val SENSOR_HOST = "192.168.4.1"
        private const val SENSOR_PORT = 81
        private const val CHANNEL_COUNT = 16
        private const val ADC_MAX = 4095
        private const val MOVEMENT_THRESHOLD = 3500
        private const val MOVEMENT_THRESHOLD_WHILE_USER_MOVING = 4090
        private const val USER_MOTION_GYRO_AXIS_THRESHOLD = 245.0
        private const val RETRY_INTERVAL_MS = 3000L
    }

    private data class BeltSample(
        val peak: Int,
        val measuredDuringUserMotion: Boolean,
    )
}

