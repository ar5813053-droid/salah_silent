package com.salahsilent.salah_silent

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.salahsilent.app/native"
    private val eventChannelName = "com.salahsilent.app/alarm_events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            methodChannelName,
        )
        methodChannel?.setMethodCallHandler { call, result ->
            try {
                val mgr = SilentSessionManager.getInstance(this)
                when (call.method) {
                    "getPlatformVersion" ->
                        result.success("Android ${android.os.Build.VERSION.RELEASE}")
                    "pingSilentSessionManager" ->
                        result.success("SilentSessionManager ready")
                    "canScheduleExactAlarms" ->
                        result.success(AlarmScheduler.canScheduleExactAlarms(this))
                    "openExactAlarmSettings" -> {
                        result.success(PermissionStatusHelper.openExactAlarmSettings(this))
                    }
                    "scheduleAllPrayers" -> {
                        val configs = parseConfigs(call.arguments as? List<*>)
                        result.success(AlarmScheduler.scheduleAll(this, configs))
                    }
                    "cancelAllPrayers" ->
                        result.success(AlarmScheduler.cancelAll(this))
                    "updatePrayerAlarm" -> {
                        val map = call.arguments as? Map<*, *>
                        if (map == null) {
                            result.error("bad_args", "Expected map", null)
                            return@setMethodCallHandler
                        }
                        val cfg = AlarmScheduler.PrayerAlarmConfig(
                            prayerName = map["prayerName"] as String,
                            hour = (map["hour"] as Number).toInt(),
                            minute = (map["minute"] as Number).toInt(),
                            enabled = map["enabled"] as Boolean,
                            durationMinutes = (map["durationMinutes"] as? Number)?.toInt() ?: 10,
                        )
                        result.success(AlarmScheduler.updateOne(this, cfg))
                    }
                    "getSchedulingStatus" ->
                        result.success(AlarmScheduler.getStatus(this))
                    "getNextScheduledAlarm" ->
                        result.success(AlarmScheduler.getNextScheduled(this))
                    "refreshAlarmsFromFlutter" -> {
                        val configs = parseConfigs(call.arguments as? List<*>)
                        result.success(AlarmScheduler.scheduleAll(this, configs))
                    }
                    // ── Silent session (Milestone 3) ──
                    "startSilentSession" -> {
                        val map = call.arguments as? Map<*, *>
                        val name = map?.get("prayerName") as? String ?: "Manual"
                        val dur = (map?.get("durationMinutes") as? Number)?.toInt() ?: 10
                        result.success(mgr.startSession(name, dur))
                    }
                    "endSilentSession" -> {
                        val map = call.arguments as? Map<*, *>
                        val sid = map?.get("sessionId") as? String
                        result.success(mgr.endSession(sid, manual = true))
                    }
                    "cancelSilentSession" ->
                        result.success(mgr.cancelSilentSession())
                    "getSilentSessionStatus" ->
                        result.success(mgr.getStatus())
                    "getRemainingSilentDuration" ->
                        result.success(mgr.getRemainingMillis())
                    "isSilentModeActive" ->
                        result.success(mgr.isSilentModeActive())
                    "checkNotificationPolicyAccess" ->
                        result.success(mgr.hasNotificationPolicyAccess())
                    "openNotificationPolicySettings" -> {
                        result.success(PermissionStatusHelper.openNotificationPolicySettings(this))
                    }
                    "getPreviousSoundState" ->
                        result.success(mgr.getPreviousSoundState())
                    "reconcileSilentSession" ->
                        result.success(mgr.reconcileSilentSession())
                    "getPermissionStatuses" ->
                        result.success(PermissionStatusHelper.getAllStatuses(this))
                    "openNotificationListenerSettings" ->
                        result.success(PermissionStatusHelper.openNotificationListenerSettings(this))
                    "openAppNotificationSettings" ->
                        result.success(PermissionStatusHelper.openAppNotificationSettings(this))
                    "openBatterySettings" ->
                        result.success(PermissionStatusHelper.openBatterySettings(this))
                    "openAppDetailsSettings" ->
                        result.success(PermissionStatusHelper.openAppDetails(this))
                    "checkBatteryOptimizationStatus" ->
                        result.success(PermissionStatusHelper.batteryOptimizationStatus(this))
                    "getDeviceManufacturerInfo" ->
                        result.success(PermissionStatusHelper.deviceInfo())
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                Log.e(TAG, "MethodChannel error ${call.method}: ${e.message}", e)
                result.error("native_error", e.message, null)
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            eventChannelName,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // Reconcile on engine attach (process may have been killed mid-session)
        try {
            SilentSessionManager.getInstance(this).recoverAfterBoot()
        } catch (e: Exception) {
            Log.w(TAG, "recover on engine: ${e.message}")
        }
    }

    override fun onDestroy() {
        if (isFinishing) {
            methodChannel = null
            eventSink = null
        }
        super.onDestroy()
    }

    private fun parseConfigs(list: List<*>?): List<AlarmScheduler.PrayerAlarmConfig> {
        if (list == null) return emptyList()
        return list.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val name = map["prayerName"] as? String ?: return@mapNotNull null
            val hour = (map["hour"] as? Number)?.toInt() ?: return@mapNotNull null
            val minute = (map["minute"] as? Number)?.toInt() ?: return@mapNotNull null
            val enabled = map["enabled"] as? Boolean ?: true
            val duration = (map["durationMinutes"] as? Number)?.toInt() ?: 10
            AlarmScheduler.PrayerAlarmConfig(
                prayerName = name,
                hour = hour.coerceIn(0, 23),
                minute = minute.coerceIn(0, 59),
                enabled = enabled,
                durationMinutes = duration.coerceIn(1, 180),
            )
        }
    }

    companion object {
        private const val TAG = "SalahSilent/Alarm"

        @Volatile
        private var methodChannel: MethodChannel? = null

        @Volatile
        private var eventSink: EventChannel.EventSink? = null

        fun emitAlarmEvent(payload: Map<String, Any?>) {
            try {
                eventSink?.success(payload)
            } catch (e: Exception) {
                Log.w(TAG, "emitAlarmEvent failed: ${e.message}")
            }
        }
    }
}
