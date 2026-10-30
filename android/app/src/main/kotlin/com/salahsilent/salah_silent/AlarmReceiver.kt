package com.salahsilent.salah_silent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Handles exact start-silent and end-silent alarms.
 * Delegates all logic to SilentSessionManager.
 * Implementation in Milestone 3.
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        // val action = intent?.action
        // SilentSessionManager.getInstance(context).onAlarmTriggered(action, intent)
    }
}
