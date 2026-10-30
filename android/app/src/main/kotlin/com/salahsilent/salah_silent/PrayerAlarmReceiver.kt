package com.salahsilent.salah_silent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receives exact prayer alarms. Milestone 2: identify Salah, log, reschedule next day.
 * Milestone 3 will activate silent mode from here.
 */
class PrayerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != AlarmScheduler.ACTION_PRAYER_ALARM) return

        val prayerName = intent.getStringExtra(AlarmScheduler.EXTRA_PRAYER_NAME) ?: return
        val hour = intent.getIntExtra(AlarmScheduler.EXTRA_HOUR, -1)
        val minute = intent.getIntExtra(AlarmScheduler.EXTRA_MINUTE, -1)

        Log.i(TAG, "Prayer alarm received: $prayerName hour=$hour minute=$minute")

        if (hour in 0..23 && minute in 0..59) {
            AlarmScheduler.onAlarmFired(context.applicationContext, prayerName, hour, minute)
        } else {
            // Recover hour/minute from saved config
            val cfg = AlarmScheduler.loadConfigs(context)
                .firstOrNull { it.prayerName == prayerName }
            if (cfg != null && cfg.enabled) {
                AlarmScheduler.onAlarmFired(
                    context.applicationContext,
                    cfg.prayerName,
                    cfg.hour,
                    cfg.minute,
                )
            }
        }

        // Notify Flutter if engine is alive (no-op if app is background-killed)
        MainActivity.emitAlarmEvent(
            mapOf(
                "type" to "prayer_alarm",
                "prayerName" to prayerName,
                "triggeredAtEpochMillis" to System.currentTimeMillis(),
            )
        )
    }

    companion object {
        private const val TAG = "SalahSilent/Alarm"
    }
}
