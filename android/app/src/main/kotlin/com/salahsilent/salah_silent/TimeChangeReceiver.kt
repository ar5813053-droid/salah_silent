package com.salahsilent.salah_silent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Recalculates all prayer alarms when the user or system changes clock / timezone / date.
 */
class TimeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_TIME_CHANGED &&
            action != Intent.ACTION_TIMEZONE_CHANGED &&
            action != Intent.ACTION_DATE_CHANGED
        ) {
            return
        }

        Log.i(TAG, "Time/timezone/date change: $action — recalculating alarms")
        val pendingResult = goAsync()
        try {
            // Cancel + reschedule from saved configs with new local calendar
            AlarmScheduler.cancelAll(context.applicationContext)
            val status = AlarmScheduler.restoreFromPrefs(context.applicationContext)
            Log.i(TAG, "Recalculation complete: $status")
        } catch (e: Exception) {
            Log.e(TAG, "Recalculation failed: ${e.message}", e)
        } finally {
            pendingResult.finish()
        }
    }

    companion object {
        private const val TAG = "SalahSilent/Alarm"
    }
}
