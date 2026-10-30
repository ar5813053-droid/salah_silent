package com.salahsilent.salah_silent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/** Fires when a silent session end alarm is due. */
class SilentSessionEndReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != SilentSessionManager.ACTION_END_SESSION) return
        val sessionId = intent.getStringExtra(SilentSessionManager.EXTRA_SESSION_ID)
        val endEpoch = intent.getLongExtra(SilentSessionManager.EXTRA_END_EPOCH, -1L)
        Log.i(TAG, "End alarm sessionId=$sessionId endEpoch=$endEpoch")
        val pending = goAsync()
        try {
            SilentSessionManager.getInstance(context).endSession(
                sessionId = sessionId,
                expectedEndEpoch = if (endEpoch > 0) endEpoch else null,
                manual = false,
            )
        } catch (e: Exception) {
            Log.e(TAG, "endSession error: ${e.message}", e)
        } finally {
            pending.finish()
        }
    }

    companion object {
        private const val TAG = "SalahSilent/Restore"
    }
}
