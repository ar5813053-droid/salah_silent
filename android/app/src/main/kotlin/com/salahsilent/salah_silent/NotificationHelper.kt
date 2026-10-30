package com.salahsilent.salah_silent

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log

object NotificationHelper {
    private const val TAG = "SalahSilent/Notifications"

    const val CH_SILENT_SESSION = "silent_session_channel"
    const val CH_CALL_DURING = "call_during_salah_channel"
    const val CH_SESSION_RESTORE = "session_restore_channel"
    const val CH_PERMISSION = "permission_warning_channel"

    private const val PREFS = "salah_silent_notif_prefs"
    private const val ID_ACTIVATED = 3001
    private const val ID_RESTORE = 3002
    private const val ID_RESTORE_SKIP = 3003
    private const val ID_PERMISSION = 3004
    private const val ID_CALL_BASE = 3100

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        fun ch(id: String, name: String, desc: String, importance: Int) {
            val c = NotificationChannel(id, name, importance).apply {
                description = desc
                setSound(null, null)
                enableVibration(false)
                setShowBadge(true)
            }
            nm.createNotificationChannel(c)
        }
        ch(CH_SILENT_SESSION, "Silent sessions", "When Salah silent mode starts", NotificationManager.IMPORTANCE_DEFAULT)
        ch(CH_CALL_DURING, "Calls during Salah", "Call notifications while silent", NotificationManager.IMPORTANCE_DEFAULT)
        ch(CH_SESSION_RESTORE, "Session restore", "When sound is restored after Salah", NotificationManager.IMPORTANCE_DEFAULT)
        ch(CH_PERMISSION, "Permission warnings", "When a required permission is missing", NotificationManager.IMPORTANCE_LOW)
    }

    fun isEnabled(context: Context, key: String, default: Boolean = true): Boolean =
        prefs(context).getBoolean(key, default)

    fun getAllPrefs(context: Context): Map<String, Any?> = mapOf(
        "silentActivated" to isEnabled(context, "pref_silent_activated"),
        "callDuringSalah" to isEnabled(context, "pref_call_during"),
        "sessionRestore" to isEnabled(context, "pref_session_restore"),
        "permissionWarning" to isEnabled(context, "pref_permission_warning"),
    )

    fun setPrefs(context: Context, map: Map<*, *>) {
        val e = prefs(context).edit()
        (map["silentActivated"] as? Boolean)?.let { e.putBoolean("pref_silent_activated", it) }
        (map["callDuringSalah"] as? Boolean)?.let { e.putBoolean("pref_call_during", it) }
        (map["sessionRestore"] as? Boolean)?.let { e.putBoolean("pref_session_restore", it) }
        (map["permissionWarning"] as? Boolean)?.let { e.putBoolean("pref_permission_warning", it) }
        e.apply()
    }

    private fun canPost(context: Context): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= 33) {
                context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
                    android.content.pm.PackageManager.PERMISSION_GRANTED
            } else true
        } catch (_: Exception) {
            true
        }
    }

    private fun launchPi(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent()
        return PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun notifySilentActivated(context: Context, prayerName: String, durationMinutes: Int) {
        ensureChannels(context)
        if (!isEnabled(context, "pref_silent_activated")) return
        if (!canPost(context)) {
            Log.i(TAG, "POST_NOTIFICATIONS denied — skip activation notif")
            return
        }
        post(
            context, ID_ACTIVATED, CH_SILENT_SESSION, "Salah Silent Activated",
            "Your phone is now in Silent mode for $prayerName. Duration: $durationMinutes minutes.",
        )
    }

    fun notifyRestored(context: Context, prayerName: String) {
        ensureChannels(context)
        if (!isEnabled(context, "pref_session_restore")) return
        if (!canPost(context)) return
        post(
            context, ID_RESTORE, CH_SESSION_RESTORE, "Sound Restored",
            "Your $prayerName silent session has ended. Your previous sound setting has been restored.",
        )
    }

    fun notifyRestoreSkipped(context: Context, prayerName: String) {
        ensureChannels(context)
        if (!isEnabled(context, "pref_session_restore")) return
        if (!canPost(context)) return
        post(
            context, ID_RESTORE_SKIP, CH_SESSION_RESTORE, "Silent session ended",
            "Your $prayerName session ended. Sound was not changed because the ringer was modified during the session.",
        )
    }

    fun notifyCallDuringSalah(context: Context, prayerName: String, callerLabel: String, notifKey: String) {
        ensureChannels(context)
        if (!isEnabled(context, "pref_call_during")) return
        if (!canPost(context)) return
        val id = ID_CALL_BASE + (notifKey.hashCode() and 0x0FFF)
        val body = if (callerLabel.isBlank() || callerLabel == "Unknown Caller") {
            "A call notification was detected during your $prayerName silent session."
        } else {
            "Call notification ($callerLabel) during your $prayerName silent session."
        }
        post(context, id, CH_CALL_DURING, "Call received during Salah", body, privateLock = true)
    }

    fun notifyPermissionWarning(context: Context, message: String) {
        ensureChannels(context)
        if (!isEnabled(context, "pref_permission_warning")) return
        if (!canPost(context)) return
        val last = prefs(context).getLong("last_perm_warn", 0L)
        if (System.currentTimeMillis() - last < 6 * 60 * 60 * 1000L) return
        prefs(context).edit().putLong("last_perm_warn", System.currentTimeMillis()).apply()
        post(context, ID_PERMISSION, CH_PERMISSION, "Permission needed", message)
    }

    private fun post(
        context: Context,
        id: Int,
        channel: String,
        title: String,
        body: String,
        privateLock: Boolean = false,
    ) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, channel)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            builder.setSmallIcon(android.R.drawable.ic_lock_silent_mode)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(Notification.BigTextStyle().bigText(body))
                .setContentIntent(launchPi(context))
                .setAutoCancel(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                builder.setVisibility(
                    if (privateLock) Notification.VISIBILITY_PRIVATE else Notification.VISIBILITY_PUBLIC,
                )
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                @Suppress("DEPRECATION")
                builder.setSound(null)
            }
            nm.notify(id, builder.build())
            Log.i(TAG, "Posted id=$id title=$title")
        } catch (e: Exception) {
            Log.e(TAG, "post failed: ${e.message}", e)
        }
    }
}
