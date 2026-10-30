package com.salahsilent.salah_silent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class TimeChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_TIME_CHANGED &&
            action != Intent.ACTION_TIMEZONE_CHANGED &&
            action != Intent.ACTION_DATE_CHANGED
        ) {
            return
        }

        Log.i(TAG, "Time/timezone/date change: $action")
        val pendingResult = goAsync()
        try {
            val app = context.applicationContext
            AlarmScheduler.cancelAll(app)
            AlarmScheduler.restoreFromPrefs(app)
            SilentSessionManager.getInstance(app).recoverAfterBoot()
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
