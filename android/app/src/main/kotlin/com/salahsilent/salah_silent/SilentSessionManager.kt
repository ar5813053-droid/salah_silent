package com.salahsilent.salah_silent

import android.content.Context

/**
 * Centralized manager for all silent sessions.
 * Owns session IDs, overlap handling, start/end alarms and safe restoration.
 *
 * Design rules (Milestone 0 contract):
 * - Prefer exact start/end alarms over foreground service.
 * - Foreground service only if technically required under Android 13/14.
 * - Never overwrite sound/DND changes made manually by the user during a session.
 * - One source of truth for active session and restoration timers.
 *
 * Full implementation in Milestone 3.
 */
class SilentSessionManager private constructor(private val context: Context) {

    companion object {
        @Volatile
        private var INSTANCE: SilentSessionManager? = null

        fun getInstance(context: Context): SilentSessionManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: SilentSessionManager(context.applicationContext).also { INSTANCE = it }
            }
        }
    }

    // Future public API (will be fully implemented later):
    // fun startSession(prayerName: String, durationMinutes: Int): String
    // fun endSession(sessionId: String)
    // fun handleOverlap(...)
    // fun recoverAfterBoot()
    // fun isSessionActive(): Boolean
    // fun getActiveSessionId(): String?
}
