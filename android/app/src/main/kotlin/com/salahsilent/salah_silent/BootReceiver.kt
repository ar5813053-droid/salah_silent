package com.salahsilent.salah_silent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * After reboot or app update:
 * 1) Restore prayer alarms from SharedPreferences
 * 2) Reconcile any active silent session
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_LOCKED_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        Log.i(TAG, "Boot/update recovery action=$action")
        val pendingResult = goAsync()
        try {
            val app = context.applicationContext
            val alarmStatus = AlarmScheduler.restoreFromPrefs(app)
            Log.i(TAG, "Alarms restored: $alarmStatus")
            val sessionStatus = SilentSessionManager.getInstance(app).recoverAfterBoot()
            Log.i(TAG, "Session recovered: $sessionStatus")
        } catch (e: Exception) {
            Log.e(TAG, "Restore failed: ${e.message}", e)
        } finally {
            pendingResult.finish()
        }
    }

    companion object {
        private const val TAG = "SalahSilent/Alarm"
    }
}
