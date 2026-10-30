package com.salahsilent.salah_silent

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.provider.Settings
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

/**
 * Central exact-alarm scheduler for the five daily Salah.
 *
 * Uses setExactAndAllowWhileIdle when SCHEDULE_EXACT_ALARM is granted.
 * Falls back to setAndAllowWhileIdle (inexact) only when permission is missing,
 * and reports that honestly to Flutter.
 *
 * setAlarmClock() alternative: most reliable against Doze and shows a system
 * alarm icon in the status bar. Trade-off: user sees a clock icon. We prefer
 * setExactAndAllowWhileIdle per product requirements; setAlarmClock remains
 * available via [useAlarmClock] if needed later.
 */
object AlarmScheduler {
    private const val TAG = "SalahSilent/Alarm"
    private const val PREFS = "salah_silent_alarms"
    private const val KEY_SCHEDULES_JSON = "schedules_json"
    private const val KEY_LAST_REFRESH = "last_refresh_epoch"
    private const val KEY_LAST_ERROR = "last_error"
    private const val KEY_LAST_TRIGGER = "last_trigger_" // + prayer name

    const val ACTION_PRAYER_ALARM = "com.salahsilent.salah_silent.ACTION_PRAYER_ALARM"
    const val EXTRA_PRAYER_NAME = "prayer_name"
    const val EXTRA_HOUR = "hour"
    const val EXTRA_MINUTE = "minute"

    /** Stable request codes — never random. */
    private val REQUEST_CODES = mapOf(
        "Fajr" to 1001,
        "Dhuhr" to 1002,
        "Asr" to 1003,
        "Maghrib" to 1004,
        "Isha" to 1005,
    )

    data class PrayerAlarmConfig(
        val prayerName: String,
        val hour: Int,
        val minute: Int,
        val enabled: Boolean,
    )

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun canScheduleExactAlarms(context: Context): Boolean {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            am.canScheduleExactAlarms()
        } else {
            true
        }
    }

    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = android.net.Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
            } catch (e: Exception) {
                Log.w(TAG, "openExactAlarmSettings fallback: ${e.message}")
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = android.net.Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
            }
        }
    }

    /**
     * Persist configs and (re)register alarms for all five prayers.
     * Disabled prayers are cancelled.
     */
    fun scheduleAll(context: Context, configs: List<PrayerAlarmConfig>): Map<String, Any?> {
        saveConfigs(context, configs)
        var scheduled = 0
        var cancelled = 0
        val exact = canScheduleExactAlarms(context)
        val errors = mutableListOf<String>()

        for (cfg in configs) {
            try {
                if (cfg.enabled) {
                    val triggerAt = nextOccurrenceMillis(cfg.hour, cfg.minute)
                    scheduleOne(context, cfg.prayerName, cfg.hour, cfg.minute, triggerAt, exact)
                    scheduled++
                    Log.i(TAG, "Scheduled ${cfg.prayerName} at $triggerAt (exact=$exact)")
                } else {
                    cancelOne(context, cfg.prayerName)
                    cancelled++
                    Log.i(TAG, "Cancelled ${cfg.prayerName} (disabled)")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed ${cfg.prayerName}: ${e.message}", e)
                errors.add("${cfg.prayerName}: ${e.message}")
            }
        }

        val now = System.currentTimeMillis()
        prefs(context).edit()
            .putLong(KEY_LAST_REFRESH, now)
            .putString(KEY_LAST_ERROR, if (errors.isEmpty()) null else errors.joinToString("; "))
            .apply()

        return statusMap(context, scheduledCount = scheduled)
    }

    fun cancelAll(context: Context): Map<String, Any?> {
        for (name in REQUEST_CODES.keys) {
            cancelOne(context, name)
        }
        Log.i(TAG, "Cancelled all prayer alarms")
        prefs(context).edit()
            .putLong(KEY_LAST_REFRESH, System.currentTimeMillis())
            .putString(KEY_LAST_ERROR, null)
            .apply()
        return statusMap(context, scheduledCount = 0)
    }

    fun updateOne(context: Context, config: PrayerAlarmConfig): Map<String, Any?> {
        val all = loadConfigs(context).toMutableList()
        val idx = all.indexOfFirst { it.prayerName == config.prayerName }
        if (idx >= 0) {
            all[idx] = config
        } else {
            all.add(config)
        }
        return scheduleAll(context, all)
    }

    /** Restore after boot / time change using last saved configs. */
    fun restoreFromPrefs(context: Context): Map<String, Any?> {
        val configs = loadConfigs(context)
        if (configs.isEmpty()) {
            Log.i(TAG, "No saved schedules to restore")
            return statusMap(context, scheduledCount = 0)
        }
        Log.i(TAG, "Restoring ${configs.size} prayer configs")
        return scheduleAll(context, configs)
    }

    fun getStatus(context: Context): Map<String, Any?> {
        return statusMap(context)
    }

    fun getNextScheduled(context: Context): Map<String, Any?>? {
        val configs = loadConfigs(context).filter { it.enabled }
        if (configs.isEmpty()) return null

        var bestName: String? = null
        var bestAt = Long.MAX_VALUE
        for (cfg in configs) {
            val at = nextOccurrenceMillis(cfg.hour, cfg.minute)
            if (at < bestAt) {
                bestAt = at
                bestName = cfg.prayerName
            }
        }
        if (bestName == null) return null
        return mapOf(
            "prayerName" to bestName,
            "triggerEpochMillis" to bestAt,
            "hour" to configs.first { it.prayerName == bestName }.hour,
            "minute" to configs.first { it.prayerName == bestName }.minute,
        )
    }

    /** Called when a prayer alarm fires — reschedule next daily occurrence. */
    fun onAlarmFired(context: Context, prayerName: String, hour: Int, minute: Int) {
        Log.i(TAG, "Alarm fired for $prayerName")
        prefs(context).edit()
            .putLong(KEY_LAST_TRIGGER + prayerName, System.currentTimeMillis())
            .apply()

        val exact = canScheduleExactAlarms(context)
        val next = nextOccurrenceMillis(hour, minute)
        // nextOccurrence after fire: if we fire at exact minute, nextOccurrence might still be "now"
        // force at least +1 day if computed time is not sufficiently in the future
        val triggerAt = if (next <= System.currentTimeMillis() + 30_000L) {
            next + 24L * 60 * 60 * 1000
        } else {
            next
        }
        scheduleOne(context, prayerName, hour, minute, triggerAt, exact)
        Log.i(TAG, "Rescheduled $prayerName for $triggerAt")
    }

    // ─── internals ───────────────────────────────────────────────────────

    private fun scheduleOne(
        context: Context,
        prayerName: String,
        hour: Int,
        minute: Int,
        triggerAtMillis: Long,
        exact: Boolean,
        useAlarmClock: Boolean = false,
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = pendingIntentFor(context, prayerName, hour, minute)

        when {
            useAlarmClock && exact -> {
                val show = PendingIntent.getActivity(
                    context,
                    REQUEST_CODES[prayerName]!! + 100,
                    context.packageManager.getLaunchIntentForPackage(context.packageName),
                    pendingFlags(),
                )
                am.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAtMillis, show), pi)
            }
            exact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            }
            exact -> {
                am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            }
            else -> {
                am.set(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            }
        }
    }

    private fun cancelOne(context: Context, prayerName: String) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val code = REQUEST_CODES[prayerName] ?: return
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = ACTION_PRAYER_ALARM
            putExtra(EXTRA_PRAYER_NAME, prayerName)
        }
        val pi = PendingIntent.getBroadcast(
            context,
            code,
            intent,
            pendingFlags(),
        )
        am.cancel(pi)
        pi.cancel()
    }

    private fun pendingIntentFor(
        context: Context,
        prayerName: String,
        hour: Int,
        minute: Int,
    ): PendingIntent {
        val code = REQUEST_CODES[prayerName]
            ?: throw IllegalArgumentException("Unknown prayer: $prayerName")
        val intent = Intent(context, PrayerAlarmReceiver::class.java).apply {
            action = ACTION_PRAYER_ALARM
            putExtra(EXTRA_PRAYER_NAME, prayerName)
            putExtra(EXTRA_HOUR, hour)
            putExtra(EXTRA_MINUTE, minute)
        }
        return PendingIntent.getBroadcast(context, code, intent, pendingFlags())
    }

    private fun pendingFlags(): Int {
        return PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    }

    /** Next local occurrence of hour:minute that is strictly in the future. */
    fun nextOccurrenceMillis(hour: Int, minute: Int): Long {
        val h = hour.coerceIn(0, 23)
        val m = minute.coerceIn(0, 59)
        val cal = Calendar.getInstance(TimeZone.getDefault())
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        cal.set(Calendar.HOUR_OF_DAY, h)
        cal.set(Calendar.MINUTE, m)
        if (cal.timeInMillis <= System.currentTimeMillis()) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return cal.timeInMillis
    }

    private fun saveConfigs(context: Context, configs: List<PrayerAlarmConfig>) {
        val arr = JSONArray()
        for (c in configs) {
            arr.put(JSONObject().apply {
                put("prayerName", c.prayerName)
                put("hour", c.hour)
                put("minute", c.minute)
                put("enabled", c.enabled)
            })
        }
        prefs(context).edit().putString(KEY_SCHEDULES_JSON, arr.toString()).apply()
    }

    fun loadConfigs(context: Context): List<PrayerAlarmConfig> {
        val raw = prefs(context).getString(KEY_SCHEDULES_JSON, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            val list = mutableListOf<PrayerAlarmConfig>()
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                list.add(
                    PrayerAlarmConfig(
                        prayerName = o.getString("prayerName"),
                        hour = o.getInt("hour"),
                        minute = o.getInt("minute"),
                        enabled = o.getBoolean("enabled"),
                    )
                )
            }
            list
        } catch (e: Exception) {
            Log.e(TAG, "loadConfigs parse error: ${e.message}")
            emptyList()
        }
    }

    private fun statusMap(context: Context, scheduledCount: Int? = null): Map<String, Any?> {
        val configs = loadConfigs(context)
        val enabled = configs.count { it.enabled }
        val count = scheduledCount ?: enabled
        val next = getNextScheduled(context)
        val p = prefs(context)
        return mapOf(
            "exactAlarmGranted" to canScheduleExactAlarms(context),
            "activeAlarmCount" to count,
            "enabledPrayerCount" to enabled,
            "nextPrayerName" to next?.get("prayerName"),
            "nextTriggerEpochMillis" to next?.get("triggerEpochMillis"),
            "lastRefreshEpochMillis" to p.getLong(KEY_LAST_REFRESH, 0L),
            "lastError" to p.getString(KEY_LAST_ERROR, null),
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }
}
