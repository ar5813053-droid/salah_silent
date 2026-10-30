package com.salahsilent.salah_silent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * After reboot or app update, restore all enabled Salah exact alarms
 * without requiring the Flutter UI to be open.
 *
 * Limitation: if the user force-stops the app, Android may not deliver
 * BOOT_COMPLETED until the user opens the app again.
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
            val status = AlarmScheduler.restoreFromPrefs(context.applicationContext)
            Log.i(TAG, "Restore complete: $status")
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
