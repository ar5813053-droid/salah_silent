package com.salahsilent.salah_silent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Prayer start alarm: reschedule next day + start silent session for configured duration.
 */
class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != AlarmScheduler.ACTION_PRAYER_ALARM) return

        val prayerName = intent.getStringExtra(AlarmScheduler.EXTRA_PRAYER_NAME) ?: return
        var hour = intent.getIntExtra(AlarmScheduler.EXTRA_HOUR, -1)
        var minute = intent.getIntExtra(AlarmScheduler.EXTRA_MINUTE, -1)

        Log.i(TAG, "Prayer alarm: $prayerName hour=$hour minute=$minute")

        val app = context.applicationContext
        val cfg = AlarmScheduler.loadConfigs(app).firstOrNull { it.prayerName == prayerName }
        if (hour !in 0..23 || minute !in 0..59) {
            hour = cfg?.hour ?: return
            minute = cfg.minute
        }

        // Always reschedule next occurrence for enabled prayers
        if (cfg == null || cfg.enabled) {
            AlarmScheduler.onAlarmFired(app, prayerName, hour, minute)
        }

        val duration = cfg?.durationMinutes
            ?: AlarmScheduler.durationFor(app, prayerName)

        val pending = goAsync()
        try {
            val result = SilentSessionManager.getInstance(app).startSession(prayerName, duration)
            Log.i(TAG, "Silent session result: $result")
            MainActivity.emitAlarmEvent(
                mapOf(
                    "type" to "prayer_alarm",
                    "prayerName" to prayerName,
                    "triggeredAtEpochMillis" to System.currentTimeMillis(),
                    "silentSession" to result,
                )
            )
        } catch (e: Exception) {
            Log.e(TAG, "startSession failed: ${e.message}", e)
        } finally {
            pending.finish()
        }
    }

    companion object {
        private const val TAG = "SalahSilent/Alarm"
    }
}
