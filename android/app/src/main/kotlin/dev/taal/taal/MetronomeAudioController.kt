package dev.taal.taal

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class MetronomeAudioController(messenger: BinaryMessenger) {
    private val nativeHandle: Long = nativeCreate()

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "configure" -> {
                    val args = call.arguments as? Map<*, *>
                    val volume = (args?.get("volume") as? Number)?.toFloat()
                    val preset = args?.get("preset") as? String
                    if (volume == null || volume < 0.0f || volume > 1.0f || preset == null) {
                        result.error(
                            "invalid_argument",
                            "configure expects volume 0..1 and preset.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val error = nativeConfigure(nativeHandle, volume, preset)
                    if (error != null) {
                        result.error("audio_configure_failed", error, null)
                    } else {
                        result.success(true)
                    }
                }
                "scheduleClicks" -> {
                    val args = call.arguments as? Map<*, *>
                    val sessionStartTimeNs =
                        (args?.get("session_start_time_ns") as? Number)?.toLong()
                    val clicks = args?.get("clicks") as? List<*>
                    if (sessionStartTimeNs == null || clicks == null) {
                        result.error(
                            "invalid_argument",
                            "scheduleClicks expects session_start_time_ns and clicks.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val tMs = LongArray(clicks.size)
                    val accents = BooleanArray(clicks.size)
                    for ((index, rawClick) in clicks.withIndex()) {
                        val click = rawClick as? Map<*, *>
                        val clickTMs = (click?.get("t_ms") as? Number)?.toLong()
                        val accent = click?.get("accent") as? Boolean
                        if (clickTMs == null || clickTMs < 0L || accent == null) {
                            result.error(
                                "invalid_argument",
                                "Each scheduled click needs non-negative t_ms and accent.",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        tMs[index] = clickTMs
                        accents[index] = accent
                    }

                    val error = nativeScheduleClicks(
                        nativeHandle,
                        sessionStartTimeNs,
                        tMs,
                        accents,
                    )
                    if (error != null) {
                        result.error("audio_schedule_failed", error, null)
                    } else {
                        result.success(true)
                    }
                }
                "scheduleDrumHits" -> {
                    val args = call.arguments as? Map<*, *>
                    val sessionStartTimeNs =
                        (args?.get("session_start_time_ns") as? Number)?.toLong()
                    val hits = args?.get("hits") as? List<*>
                    if (sessionStartTimeNs == null || hits == null) {
                        result.error(
                            "invalid_argument",
                            "scheduleDrumHits expects session_start_time_ns and hits.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val tMs = LongArray(hits.size)
                    val laneIds = Array(hits.size) { "" }
                    val velocities = IntArray(hits.size)
                    val articulations = Array(hits.size) { "normal" }
                    for ((index, rawHit) in hits.withIndex()) {
                        val hit = rawHit as? Map<*, *>
                        val hitTMs = (hit?.get("t_ms") as? Number)?.toLong()
                        val laneId = hit?.get("lane_id") as? String
                        val velocity = (hit?.get("velocity") as? Number)?.toInt()
                        val articulation = hit?.get("articulation") as? String ?: "normal"
                        if (
                            hitTMs == null ||
                            hitTMs < 0L ||
                            laneId.isNullOrBlank() ||
                            velocity == null ||
                            velocity !in 1..127 ||
                            articulation.isBlank()
                        ) {
                            result.error(
                                "invalid_argument",
                                "Each scheduled drum hit needs non-negative t_ms, lane_id, velocity 1..127, and articulation.",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        tMs[index] = hitTMs
                        laneIds[index] = laneId
                        velocities[index] = velocity
                        articulations[index] = articulation
                    }

                    val error = nativeScheduleDrumHits(
                        nativeHandle,
                        sessionStartTimeNs,
                        tMs,
                        laneIds,
                        velocities,
                        articulations,
                    )
                    if (error != null) {
                        result.error("audio_schedule_failed", error, null)
                    } else {
                        result.success(true)
                    }
                }
                "stop" -> {
                    nativeStop(nativeHandle)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        nativeDestroy(nativeHandle)
    }

    private external fun nativeCreate(): Long

    private external fun nativeDestroy(handle: Long)

    private external fun nativeConfigure(handle: Long, volume: Float, preset: String): String?

    private external fun nativeScheduleClicks(
        handle: Long,
        sessionStartTimeNs: Long,
        clickTimesMs: LongArray,
        accents: BooleanArray,
    ): String?

    private external fun nativeScheduleDrumHits(
        handle: Long,
        sessionStartTimeNs: Long,
        hitTimesMs: LongArray,
        laneIds: Array<String>,
        velocities: IntArray,
        articulations: Array<String>,
    ): String?

    private external fun nativeStop(handle: Long)

    companion object {
        private const val CHANNEL = "taal/metronome_audio"

        init {
            System.loadLibrary("taal_metronome")
        }
    }
}
