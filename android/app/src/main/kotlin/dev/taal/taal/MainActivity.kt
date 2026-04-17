package dev.taal.taal

import android.content.ContentValues
import android.media.midi.MidiDevice
import android.media.midi.MidiDeviceInfo
import android.media.midi.MidiManager
import android.media.midi.MidiOutputPort
import android.media.midi.MidiReceiver
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var midiManager: MidiManager
    private var eventSink: EventChannel.EventSink? = null
    private var openedDevice: MidiDevice? = null
    private var openedOutputPort: MidiOutputPort? = null
    private var openedDeviceId: Int = -1
    private var metronomeAudioController: MetronomeAudioController? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        midiManager = getSystemService(MidiManager::class.java)
        metronomeAudioController = MetronomeAudioController(
            flutterEngine.dartExecutor.binaryMessenger,
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "listDevices" -> result.success(listDevices())
                "openDevice" -> {
                    val deviceId = call.arguments as? Int
                    if (deviceId == null || deviceId < 0) {
                        result.error(
                            "invalid_argument",
                            "openDevice expects a non-negative MIDI device id.",
                            null,
                        )
                    } else {
                        openDevice(deviceId, result)
                    }
                }
                "closeDevice" -> {
                    closeDevice()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            },
        )

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ARTIFACT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "writeTextArtifacts" -> writeTextArtifacts(call.arguments, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        metronomeAudioController?.dispose()
        metronomeAudioController = null
        closeDevice()
        super.onDestroy()
    }

    private fun listDevices(): List<Map<String, Any?>> {
        return midiManager.devices
            .filter { it.outputPortCount > 0 }
            .map { info ->
                val properties = info.properties
                val name = properties.getString(MidiDeviceInfo.PROPERTY_NAME)
                    ?: properties.getString(MidiDeviceInfo.PROPERTY_PRODUCT)
                    ?: "MIDI Device ${info.id}"
                mapOf(
                    "id" to info.id,
                    "name" to name,
                    "manufacturer_name" to properties.getString(MidiDeviceInfo.PROPERTY_MANUFACTURER),
                    "product_name" to properties.getString(MidiDeviceInfo.PROPERTY_PRODUCT),
                    "input_port_count" to info.inputPortCount,
                    "output_port_count" to info.outputPortCount,
                )
            }
    }

    private fun openDevice(deviceId: Int, result: MethodChannel.Result) {
        val info = midiManager.devices.firstOrNull { it.id == deviceId }
        if (info == null) {
            result.error("midi_open_failed", "MIDI input device id is out of range.", null)
            return
        }
        if (info.outputPortCount <= 0) {
            result.error("midi_open_failed", "MIDI device has no readable output ports.", null)
            return
        }

        closeDevice()
        midiManager.openDevice(
            info,
            { device ->
                if (device == null) {
                    result.error("midi_open_failed", "Android MidiManager returned null device.", null)
                    return@openDevice
                }

                val outputPort = device.openOutputPort(0)
                if (outputPort == null) {
                    device.close()
                    result.error("midi_open_failed", "Unable to open MIDI output port 0.", null)
                    return@openDevice
                }

                openedDevice = device
                openedOutputPort = outputPort
                openedDeviceId = deviceId
                outputPort.connect(noteOnReceiver)
                result.success(true)
            },
            mainHandler,
        )
    }

    private fun closeDevice() {
        try {
            openedOutputPort?.close()
        } catch (_: Exception) {
        }
        try {
            openedDevice?.close()
        } catch (_: Exception) {
        }
        openedOutputPort = null
        openedDevice = null
        openedDeviceId = -1
    }

    private val noteOnReceiver = object : MidiReceiver() {
        override fun onSend(data: ByteArray, offset: Int, count: Int, timestamp: Long) {
            var index = offset
            val end = offset + count
            while (index + 2 < end) {
                val status = data[index].toInt() and 0xFF
                if (status and 0x80 == 0) {
                    index += 1
                    continue
                }

                val messageType = status and 0xF0
                val channel = status and 0x0F
                val data1 = data[index + 1].toInt() and 0xFF
                val data2 = data[index + 2].toInt() and 0xFF
                if (messageType == 0x90 && data2 > 0) {
                    emitNoteOn(channel, data1, data2, System.nanoTime())
                }
                index += 3
            }
        }
    }

    private fun emitNoteOn(channel: Int, note: Int, velocity: Int, timestampNs: Long) {
        val event = mapOf(
            "type" to "note_on",
            "device_id" to openedDeviceId,
            "channel" to channel,
            "note" to note,
            "velocity" to velocity,
            "timestamp_ns" to timestampNs,
        )
        mainHandler.post {
            eventSink?.success(event)
        }
    }

    private fun writeTextArtifacts(arguments: Any?, result: MethodChannel.Result) {
        val map = arguments as? Map<*, *>
        if (map == null) {
            result.error("invalid_argument", "writeTextArtifacts expects a map.", null)
            return
        }

        val relativeDir = map["relative_dir"] as? String ?: "Taal/phase-0"
        val csvName = map["csv_name"] as? String
        val csvContent = map["csv_content"] as? String
        val reportName = map["report_name"] as? String
        val reportContent = map["report_content"] as? String
        if (csvName == null || csvContent == null || reportName == null || reportContent == null) {
            result.error("invalid_argument", "Missing artifact name or content.", null)
            return
        }

        try {
            val csvPath = writeDownloadTextFile(relativeDir, csvName, "text/csv", csvContent)
            val reportPath = writeDownloadTextFile(relativeDir, reportName, "text/markdown", reportContent)
            result.success(
                mapOf(
                    "csv_path" to csvPath,
                    "report_path" to reportPath,
                ),
            )
        } catch (error: Exception) {
            result.error("artifact_write_failed", error.message, null)
        }
    }

    private fun writeDownloadTextFile(
        relativeDir: String,
        fileName: String,
        mimeType: String,
        content: String,
    ): String {
        val normalizedDir = relativeDir.trim('/').ifBlank { "Taal/phase-0" }
        val displayPath = "Downloads/$normalizedDir/$fileName"

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(
                    MediaStore.Downloads.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DOWNLOADS}/$normalizedDir",
                )
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: error("MediaStore insert returned null for $fileName.")
            contentResolver.openOutputStream(uri)?.use { output ->
                output.write(content.toByteArray(Charsets.UTF_8))
            } ?: error("Unable to open output stream for $fileName.")
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            contentResolver.update(uri, values, null, null)
            return displayPath
        }

        val directory = java.io.File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            normalizedDir,
        )
        if (!directory.exists() && !directory.mkdirs()) {
            error("Unable to create ${directory.absolutePath}.")
        }
        val file = java.io.File(directory, fileName)
        file.writeText(content, Charsets.UTF_8)
        return displayPath
    }

    companion object {
        private const val METHOD_CHANNEL = "taal/android_midi"
        private const val EVENT_CHANNEL = "taal/android_midi/events"
        private const val ARTIFACT_CHANNEL = "taal/artifacts"
    }
}
