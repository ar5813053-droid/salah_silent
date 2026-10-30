package com.salahsilent.salah_silent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-schedules all prayer alarms and recovers any interrupted silent session
 * after device reboot, timezone change or manual time change.
 * Implementation in Milestone 2 / 3.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        // Will call SilentSessionManager.getInstance(context).recoverAfterBoot()
    }
}
