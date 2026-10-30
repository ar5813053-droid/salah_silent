package com.salahsilent.salah_silent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Legacy stub kept for Manifest compatibility.
 * Active prayer alarms use [PrayerAlarmReceiver].
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        // no-op
    }
}
