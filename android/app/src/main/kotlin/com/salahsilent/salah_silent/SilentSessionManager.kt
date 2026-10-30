package com.salahsilent.salah_silent

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.media.AudioManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import org.json.JSONObject
import java.util.UUID

/**
 * Single source of truth for Salah silent sessions.
 *
 * Silent strategy (Android 13 / MIUI):
 * - Prefer AudioManager.RINGER_MODE_SILENT to mute ringer + notification sounds.
 * - Does NOT change STREAM_MUSIC or STREAM_ALARM volumes.
 * - Does NOT force full DND (INTERRUPTION_FILTER_NONE) unless ringer alone is insufficient.
 * - On MIUI/HyperOS, ACCESS_NOTIFICATION_POLICY is still required for reliable mute
 *   of notification channels; we request it and use RINGER_MODE_SILENT primarily.
 *
 * Overlap policy (extend window):
 * - Original pre-silent ringer/DND snapshot is kept from the FIRST session that
 *   actually changed the sound state.
 * - A later overlapping prayer extends endEpoch to max(currentEnd, newEnd).
 * - Only the final end alarm restores sound; intermediate end alarms are ignored
 *   when sessionId / endEpoch do not match the active session.
 *
 * Safe restore:
 * - Restore only if current ringer still equals the mode we applied.
 * - If user/system changed ringer during the session, skip restore and mark
 *   restoration_status = skipped_user_changed.
 * - We cannot perfectly attribute "who" changed the state on Android; matching
 *   applied mode is the practical heuristic.
 */
class SilentSessionManager private constructor(private val appContext: Context) {

    private val prefs: SharedPreferences =
        appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val audioManager =
        appContext.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val notificationManager =
        appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    data class SessionSnapshot(
        val sessionId: String,
        val prayerName: String,
        val startEpoch: Long,
        val endEpoch: Long,
        val previousRingerMode: Int,
        val previousDndFilter: Int,
        val appliedRingerMode: Int,
        val ownedByApp: Boolean,
        val status: String, // active | completed | skipped_user_changed | cancelled
    )

    companion object {
        private const val TAG = "SalahSilent/Session"
        private const val TAG_SILENT = "SalahSilent/Silent"
        private const val TAG_RESTORE = "SalahSilent/Restore"
        private const val PREFS = "salah_silent_session"
        private const val KEY_ACTIVE = "active_session_json"
        private const val END_REQUEST_CODE = 2001
        const val ACTION_END_SESSION = "com.salahsilent.salah_silent.ACTION_END_SESSION"
        const val EXTRA_SESSION_ID = "session_id"
        const val EXTRA_END_EPOCH = "end_epoch"

        @Volatile
        private var INSTANCE: SilentSessionManager? = null

        fun getInstance(context: Context): SilentSessionManager {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: SilentSessionManager(context.applicationContext).also { INSTANCE = it }
            }
        }
    }

    fun isSilentModeActive(): Boolean {
        val s = loadActive() ?: return false
        return s.status == "active" && s.endEpoch > System.currentTimeMillis()
    }

    fun getActiveSession(): SessionSnapshot? {
        val s = loadActive() ?: return null
        if (s.status != "active") return null
        return s
    }

    fun getRemainingMillis(): Long {
        val s = getActiveSession() ?: return 0L
        return (s.endEpoch - System.currentTimeMillis()).coerceAtLeast(0L)
    }

    fun hasNotificationPolicyAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            notificationManager.isNotificationPolicyAccessGranted
        } else true
    }

    fun openNotificationPolicySettings() {
        try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            appContext.startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "openNotificationPolicySettings: ${e.message}")
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:${appContext.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            appContext.startActivity(intent)
        }
    }

    /**
     * Start or extend a silent session for [prayerName].
     */
    @Synchronized
    fun startSession(prayerName: String, durationMinutes: Int): Map<String, Any?> {
        val durationMs = durationMinutes.coerceIn(1, 180) * 60_000L
        val now = System.currentTimeMillis()
        val newEnd = now + durationMs

        val existing = loadActive()
        if (existing != null && existing.status == "active" && existing.endEpoch > now) {
            // Overlap: keep original snapshot; extend end if needed
            val end = maxOf(existing.endEpoch, newEnd)
            val updated = existing.copy(
                prayerName = "$prayerName (extended from ${existing.prayerName})",
                endEpoch = end,
            )
            // Prefer showing the latest prayer name clearly
            val merged = existing.copy(
                prayerName = prayerName,
                endEpoch = end,
            )
            saveActive(merged)
            scheduleEndAlarm(merged.sessionId, end)
            Log.i(TAG, "Extended session ${merged.sessionId} to $end for $prayerName")
            emit(
                mapOf(
                    "type" to "session_extended",
                    "sessionId" to merged.sessionId,
                    "prayerName" to prayerName,
                    "endEpoch" to end,
                )
            )
            return statusMap(merged, "extended")
        }

        if (!hasNotificationPolicyAccess() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Log.w(TAG_SILENT, "Notification policy access missing — attempting ringer silent only")
        }

        val prevRinger = audioManager.ringerMode
        val prevDnd = currentInterruptionFilter()
        val applied = AudioManager.RINGER_MODE_SILENT

        // If already silent, we still track ownership of "applied" as silent so
        // restore will leave silent (safe) rather than forcing NORMAL.
        val changed = try {
            if (prevRinger != AudioManager.RINGER_MODE_SILENT) {
                audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                Log.i(TAG_SILENT, "Applied RINGER_MODE_SILENT (was $prevRinger)")
                true
            } else {
                Log.i(TAG_SILENT, "Already silent — session owns applied silent state")
                true
            }
        } catch (e: SecurityException) {
            Log.e(TAG_SILENT, "Cannot set ringer mode: ${e.message}")
            emit(
                mapOf(
                    "type" to "permission_missing",
                    "permission" to "ACCESS_NOTIFICATION_POLICY",
                    "message" to (e.message ?: "SecurityException"),
                )
            )
            return mapOf(
                "ok" to false,
                "error" to "Cannot change ringer mode. Grant Do Not Disturb access.",
                "active" to false,
            )
        }

        val session = SessionSnapshot(
            sessionId = UUID.randomUUID().toString(),
            prayerName = prayerName,
            startEpoch = now,
            endEpoch = newEnd,
            previousRingerMode = prevRinger,
            previousDndFilter = prevDnd,
            appliedRingerMode = applied,
            ownedByApp = changed,
            status = "active",
        )
        saveActive(session)
        scheduleEndAlarm(session.sessionId, session.endEpoch)
        Log.i(TAG, "Started session ${session.sessionId} prayer=$prayerName until $newEnd")
        emit(
            mapOf(
                "type" to "silent_activated",
                "sessionId" to session.sessionId,
                "prayerName" to prayerName,
                "startEpoch" to now,
                "endEpoch" to newEnd,
                "previousRingerMode" to prevRinger,
            )
        )
        NotificationHelper.notifySilentActivated(appContext, prayerName, durationMinutes)
        return statusMap(session, "started")
    }

    /** End alarm callback or manual restore. */
    @Synchronized
    fun endSession(
        sessionId: String?,
        expectedEndEpoch: Long? = null,
        manual: Boolean = false,
    ): Map<String, Any?> {
        val active = loadActive()
        if (active == null || active.status != "active") {
            Log.i(TAG_RESTORE, "No active session to end")
            cancelEndAlarm()
            return mapOf("ok" to true, "active" to false, "message" to "no_active_session")
        }

        // Stale end alarm for an older session → ignore
        if (sessionId != null && sessionId != active.sessionId) {
            Log.i(TAG_RESTORE, "Ignoring stale end alarm sessionId=$sessionId active=${active.sessionId}")
            return mapOf("ok" to true, "active" to true, "message" to "stale_session_ignored")
        }

        // End alarm for an extended session with newer endEpoch → ignore if still future
        if (expectedEndEpoch != null && expectedEndEpoch < active.endEpoch - 2_000L) {
            Log.i(TAG_RESTORE, "Ignoring early end alarm expected=$expectedEndEpoch activeEnd=${active.endEpoch}")
            return mapOf("ok" to true, "active" to true, "message" to "early_end_ignored")
        }

        // If natural end but session was extended past now, keep active
        if (!manual && System.currentTimeMillis() < active.endEpoch - 2_000L) {
            Log.i(TAG_RESTORE, "End too early; reschedule")
            scheduleEndAlarm(active.sessionId, active.endEpoch)
            return mapOf("ok" to true, "active" to true, "message" to "rescheduled")
        }

        return restoreAndComplete(active, manual)
    }

    @Synchronized
    fun cancelSilentSession(): Map<String, Any?> {
        return endSession(loadActive()?.sessionId, manual = true)
    }

    /** Boot / time-change recovery. */
    @Synchronized
    fun recoverAfterBoot(): Map<String, Any?> {
        val active = loadActive() ?: return mapOf("ok" to true, "message" to "no_session")
        if (active.status != "active") {
            clearActive()
            return mapOf("ok" to true, "message" to "cleared_inactive")
        }
        val now = System.currentTimeMillis()
        return if (now >= active.endEpoch) {
            Log.i(TAG, "Session expired during downtime — restoring")
            restoreAndComplete(active, manual = false)
        } else {
            // Re-apply silent if we still own it and ringer drifted? Only re-apply if still active owned
            try {
                if (active.ownedByApp && audioManager.ringerMode != active.appliedRingerMode) {
                    // User may have changed during reboot window — do not force if different
                    Log.i(TAG_SILENT, "Ringer differs after boot; not forcing silent")
                } else if (active.ownedByApp && audioManager.ringerMode != AudioManager.RINGER_MODE_SILENT) {
                    audioManager.ringerMode = AudioManager.RINGER_MODE_SILENT
                }
            } catch (e: Exception) {
                Log.w(TAG_SILENT, "recover ringer: ${e.message}")
            }
            scheduleEndAlarm(active.sessionId, active.endEpoch)
            Log.i(TAG, "Session still active until ${active.endEpoch}; end alarm re-registered")
            statusMap(active, "recovered")
        }
    }

    fun getStatus(): Map<String, Any?> {
        val active = getActiveSession()
        return if (active == null) {
            mapOf(
                "active" to false,
                "notificationPolicyAccess" to hasNotificationPolicyAccess(),
                "currentRingerMode" to audioManager.ringerMode,
            )
        } else {
            statusMap(active, "active")
        }
    }

    fun getPreviousSoundState(): Map<String, Any?> {
        val s = loadActive() ?: return mapOf("available" to false)
        return mapOf(
            "available" to true,
            "previousRingerMode" to s.previousRingerMode,
            "previousDndFilter" to s.previousDndFilter,
            "appliedRingerMode" to s.appliedRingerMode,
        )
    }

    fun reconcileSilentSession(): Map<String, Any?> = recoverAfterBoot()

    // ─── restore ─────────────────────────────────────────────────────────

    private fun restoreAndComplete(session: SessionSnapshot, manual: Boolean): Map<String, Any?> {
        cancelEndAlarm()
        val current = try {
            audioManager.ringerMode
        } catch (e: Exception) {
            -1
        }

        val canRestore = current == session.appliedRingerMode ||
            current == AudioManager.RINGER_MODE_SILENT && session.appliedRingerMode == AudioManager.RINGER_MODE_SILENT

        if (canRestore) {
            try {
                // Only restore if different
                if (current != session.previousRingerMode) {
                    audioManager.ringerMode = session.previousRingerMode
                    Log.i(TAG_RESTORE, "Restored ringer to ${session.previousRingerMode}")
                } else {
                    Log.i(TAG_RESTORE, "Ringer already at previous ${session.previousRingerMode}")
                }
                val completed = session.copy(status = if (manual) "cancelled" else "completed")
                // Clear active after restore
                clearActive()
                // Keep last completed summary briefly
                prefs.edit().putString("last_completed_json", toJson(completed)).apply()
                emit(
                    mapOf(
                        "type" to "silent_restored",
                        "sessionId" to session.sessionId,
                        "prayerName" to session.prayerName,
                        "previousRingerMode" to session.previousRingerMode,
                        "manual" to manual,
                    )
                )
                if (!manual) {
                    NotificationHelper.notifyRestored(appContext, session.prayerName)
                }
                return mapOf(
                    "ok" to true,
                    "active" to false,
                    "restored" to true,
                    "restorationStatus" to completed.status,
                    "previousRingerMode" to session.previousRingerMode,
                )
            } catch (e: SecurityException) {
                Log.e(TAG_RESTORE, "Restore failed: ${e.message}")
                emit(mapOf("type" to "session_error", "message" to (e.message ?: "restore_failed")))
                return mapOf("ok" to false, "error" to e.message, "active" to true)
            }
        } else {
            Log.i(
                TAG_RESTORE,
                "Skip restore: current=$current applied=${session.appliedRingerMode} prev=${session.previousRingerMode}",
            )
            clearActive()
            emit(
                mapOf(
                    "type" to "restoration_skipped",
                    "sessionId" to session.sessionId,
                    "reason" to "user_or_system_changed_ringer",
                    "currentRingerMode" to current,
                    "appliedRingerMode" to session.appliedRingerMode,
                )
            )
            NotificationHelper.notifyRestoreSkipped(appContext, session.prayerName)
            return mapOf(
                "ok" to true,
                "active" to false,
                "restored" to false,
                "restorationStatus" to "skipped_user_changed",
                "currentRingerMode" to current,
            )
        }
    }

    // ─── end alarm ───────────────────────────────────────────────────────

    private fun scheduleEndAlarm(sessionId: String, endEpoch: Long) {
        val am = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = endPendingIntent(sessionId, endEpoch)
        val exact = AlarmScheduler.canScheduleExactAlarms(appContext)
        try {
            if (exact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endEpoch, pi)
            } else if (exact) {
                am.setExact(AlarmManager.RTC_WAKEUP, endEpoch, pi)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endEpoch, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, endEpoch, pi)
            }
            Log.i(TAG, "End alarm at $endEpoch exact=$exact session=$sessionId")
        } catch (e: Exception) {
            Log.e(TAG, "scheduleEndAlarm failed: ${e.message}", e)
        }
    }

    private fun cancelEndAlarm() {
        val am = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(appContext, SilentSessionEndReceiver::class.java).apply {
            action = ACTION_END_SESSION
        }
        val pi = PendingIntent.getBroadcast(
            appContext,
            END_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        am.cancel(pi)
        pi.cancel()
    }

    private fun endPendingIntent(sessionId: String, endEpoch: Long): PendingIntent {
        val intent = Intent(appContext, SilentSessionEndReceiver::class.java).apply {
            action = ACTION_END_SESSION
            putExtra(EXTRA_SESSION_ID, sessionId)
            putExtra(EXTRA_END_EPOCH, endEpoch)
        }
        return PendingIntent.getBroadcast(
            appContext,
            END_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // ─── persistence ─────────────────────────────────────────────────────

    private fun saveActive(session: SessionSnapshot) {
        prefs.edit().putString(KEY_ACTIVE, toJson(session)).apply()
    }

    private fun clearActive() {
        prefs.edit().remove(KEY_ACTIVE).apply()
    }

    private fun loadActive(): SessionSnapshot? {
        val raw = prefs.getString(KEY_ACTIVE, null) ?: return null
        return try {
            fromJson(raw)
        } catch (e: Exception) {
            Log.e(TAG, "loadActive parse: ${e.message}")
            null
        }
    }

    private fun toJson(s: SessionSnapshot): String {
        return JSONObject().apply {
            put("sessionId", s.sessionId)
            put("prayerName", s.prayerName)
            put("startEpoch", s.startEpoch)
            put("endEpoch", s.endEpoch)
            put("previousRingerMode", s.previousRingerMode)
            put("previousDndFilter", s.previousDndFilter)
            put("appliedRingerMode", s.appliedRingerMode)
            put("ownedByApp", s.ownedByApp)
            put("status", s.status)
        }.toString()
    }

    private fun fromJson(raw: String): SessionSnapshot {
        val o = JSONObject(raw)
        return SessionSnapshot(
            sessionId = o.getString("sessionId"),
            prayerName = o.getString("prayerName"),
            startEpoch = o.getLong("startEpoch"),
            endEpoch = o.getLong("endEpoch"),
            previousRingerMode = o.getInt("previousRingerMode"),
            previousDndFilter = o.optInt("previousDndFilter", NotificationManager.INTERRUPTION_FILTER_ALL),
            appliedRingerMode = o.getInt("appliedRingerMode"),
            ownedByApp = o.optBoolean("ownedByApp", true),
            status = o.getString("status"),
        )
    }

    private fun currentInterruptionFilter(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                notificationManager.currentInterruptionFilter
            } catch (_: Exception) {
                NotificationManager.INTERRUPTION_FILTER_ALL
            }
        } else {
            NotificationManager.INTERRUPTION_FILTER_ALL
        }
    }

    private fun statusMap(session: SessionSnapshot, action: String): Map<String, Any?> {
        return mapOf(
            "ok" to true,
            "active" to (session.status == "active"),
            "action" to action,
            "sessionId" to session.sessionId,
            "prayerName" to session.prayerName,
            "startEpoch" to session.startEpoch,
            "endEpoch" to session.endEpoch,
            "remainingMillis" to (session.endEpoch - System.currentTimeMillis()).coerceAtLeast(0L),
            "previousRingerMode" to session.previousRingerMode,
            "appliedRingerMode" to session.appliedRingerMode,
            "notificationPolicyAccess" to hasNotificationPolicyAccess(),
            "currentRingerMode" to try { audioManager.ringerMode } catch (_: Exception) { -1 },
        )
    }

    private fun emit(payload: Map<String, Any?>) {
        MainActivity.emitAlarmEvent(payload)
    }
}
