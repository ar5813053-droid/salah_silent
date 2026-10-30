package com.salahsilent.salah_silent

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * Detects call-related notifications during an active silent session.
 * Does not use READ_CALL_LOG or default dialer.
 */
class CallNotificationListener : NotificationListenerService() {

    override fun onListenerConnected() {
        Log.i(TAG, "Notification listener connected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        if (sbn.isOngoing == false && !looksLikeCall(sbn)) return
        if (!looksLikeCall(sbn)) return

        val app = applicationContext
        val active = SilentSessionManager.getInstance(app).getActiveSession()
        val duringSilent = active != null
        if (!duringSilent) {
            // Only record/notify when silent session active
            return
        }

        val n = sbn.notification ?: return
        val extras = n.extras
        val title = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val text = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim().orEmpty()
        val caller = when {
            title.isNotBlank() && !title.equals("Incoming call", true) -> title
            text.isNotBlank() -> text
            else -> "Unknown Caller"
        }
        val callType = when {
            text.contains("missed", true) || title.contains("missed", true) -> "missed"
            sbn.isOngoing -> "incoming"
            else -> "incoming"
        }
        val key = "${sbn.packageName}:${sbn.id}:${sbn.tag}:${sbn.postTime}"
        val prayer = active?.prayerName ?: ""

        val added = CallHistoryStore.add(
            context = app,
            caller = sanitizeCaller(caller),
            callType = callType,
            prayerName = prayer,
            duringSilent = true,
            notifKey = key,
            timestamp = sbn.postTime.takeIf { it > 0 } ?: System.currentTimeMillis(),
        )
        if (added) {
            NotificationHelper.notifyCallDuringSalah(app, prayer, sanitizeCaller(caller), key)
            MainActivity.emitAlarmEvent(
                mapOf(
                    "type" to "call_during_salah",
                    "prayerName" to prayer,
                    "callType" to callType,
                )
            )
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Intentionally minimal — no extra noise
    }

    private fun looksLikeCall(sbn: StatusBarNotification): Boolean {
        val pkg = sbn.packageName?.lowercase() ?: return false
        val dialerHints = listOf(
            "telecom", "dialer", "phone", "call", "incall",
            "com.android.server.telecom", "com.google.android.dialer",
            "com.android.phone", "com.android.incallui",
            "com.miui.telephony", "com.android.contacts",
        )
        if (dialerHints.any { pkg.contains(it) }) return true
        val cat = sbn.notification?.category
        if (cat == Notification.CATEGORY_CALL) return true
        val title = sbn.notification?.extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = sbn.notification?.extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val blob = "$title $text".lowercase()
        return blob.contains("incoming call") ||
            blob.contains("missed call") ||
            blob.contains("calling")
    }

    private fun sanitizeCaller(raw: String): String {
        val t = raw.trim()
        if (t.isEmpty()) return "Unknown Caller"
        // Avoid dumping long notification bodies
        return if (t.length > 40) t.take(40) + "…" else t
    }

    companion object {
        private const val TAG = "SalahSilent/CallDetection"
    }
}
