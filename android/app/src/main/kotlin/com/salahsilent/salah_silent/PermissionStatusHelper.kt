package com.salahsilent.salah_silent

import android.app.AlarmManager
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log

/**
 * Accurate permission / reliability status for the Flutter dashboard.
 * Never invents granted status.
 */
object PermissionStatusHelper {
    private const val TAG = "SalahSilent/Permissions"
    private const val TAG_BG = "SalahSilent/Background"
    private const val TAG_DEV = "SalahSilent/Device"

    private const val LISTENER_CLASS =
        "com.salahsilent.salah_silent.CallNotificationListener"

    fun getAllStatuses(context: Context): Map<String, Any?> {
        return mapOf(
            "exactAlarm" to exactAlarmStatus(context),
            "notificationPolicy" to notificationPolicyStatus(context),
            "notificationListener" to notificationListenerStatus(context),
            "postNotifications" to postNotificationsStatus(context),
            "batteryOptimization" to batteryOptimizationStatus(context),
            "device" to deviceInfo(),
            "readiness" to readiness(context),
        )
    }

    fun exactAlarmStatus(context: Context): Map<String, Any?> {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                am.canScheduleExactAlarms()
            } catch (e: Exception) {
                Log.w(TAG, "canScheduleExactAlarms: ${e.message}")
                false
            }
        } else {
            true
        }
        return mapOf(
            "id" to "exact_alarm",
            "status" to if (granted) "enabled" else "not_enabled",
            "granted" to granted,
            "applicable" to true,
            "sdkInt" to Build.VERSION.SDK_INT,
        )
    }

    fun notificationPolicyStatus(context: Context): Map<String, Any?> {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                nm.isNotificationPolicyAccessGranted
            } catch (e: Exception) {
                Log.w(TAG, "isNotificationPolicyAccessGranted: ${e.message}")
                false
            }
        } else {
            true
        }
        return mapOf(
            "id" to "notification_policy",
            "status" to if (granted) "enabled" else "not_enabled",
            "granted" to granted,
            "applicable" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M),
        )
    }

    fun notificationListenerStatus(context: Context): Map<String, Any?> {
        val enabled = isOurListenerEnabled(context)
        return mapOf(
            "id" to "notification_listener",
            "status" to if (enabled) "enabled" else "not_enabled",
            "granted" to enabled,
            "applicable" to true,
            "component" to LISTENER_CLASS,
        )
    }

    private fun isOurListenerEnabled(context: Context): Boolean {
        return try {
            val flat = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners",
            ) ?: return false
            val pkg = context.packageName
            flat.split(':').any { entry ->
                val cn = ComponentName.unflattenFromString(entry)
                if (cn != null) {
                    cn.packageName == pkg &&
                        (cn.className == LISTENER_CLASS ||
                            cn.className.endsWith(".CallNotificationListener"))
                } else {
                    entry.contains(pkg)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "listener check: ${e.message}")
            false
        }
    }

    fun postNotificationsStatus(context: Context): Map<String, Any?> {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT < 33) {
            val enabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                nm.areNotificationsEnabled()
            } else {
                true
            }
            return mapOf(
                "id" to "post_notifications",
                "status" to if (enabled) "enabled" else "not_enabled",
                "granted" to enabled,
                "applicable" to true,
                "runtimePermission" to false,
            )
        }
        val granted = context.checkSelfPermission(
            android.Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
        val channelEnabled = nm.areNotificationsEnabled()
        val overall = granted && channelEnabled
        return mapOf(
            "id" to "post_notifications",
            "status" to when {
                overall -> "enabled"
                !granted -> "not_enabled"
                else -> "restricted"
            },
            "granted" to overall,
            "runtimeGranted" to granted,
            "notificationsEnabled" to channelEnabled,
            "applicable" to true,
            "runtimePermission" to true,
        )
    }

    fun batteryOptimizationStatus(context: Context): Map<String, Any?> {
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return try {
            val ignoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                pm.isIgnoringBatteryOptimizations(context.packageName)
            } else {
                true
            }
            mapOf(
                "id" to "battery_optimization",
                "status" to if (ignoring) "unrestricted" else "optimized",
                "ignoringOptimizations" to ignoring,
                "checkable" to true,
                "note" to if (ignoring) {
                    "App is not restricted by standard battery optimization"
                } else {
                    "Android may defer work; open battery settings to allow unrestricted if available"
                },
            )
        } catch (e: Exception) {
            Log.w(TAG_BG, "battery check: ${e.message}")
            mapOf(
                "id" to "battery_optimization",
                "status" to "unknown",
                "checkable" to false,
                "note" to "Could not query battery optimization state",
            )
        }
    }

    fun deviceInfo(): Map<String, Any?> {
        val manufacturer = Build.MANUFACTURER ?: "unknown"
        val brand = Build.BRAND ?: "unknown"
        val model = Build.MODEL ?: "unknown"
        val isXiaomiFamily = listOf("xiaomi", "poco", "redmi", "blackshark")
            .any {
                manufacturer.contains(it, ignoreCase = true) ||
                    brand.contains(it, ignoreCase = true)
            }
        Log.i(TAG_DEV, "manufacturer=$manufacturer brand=$brand model=$model xiaomiFamily=$isXiaomiFamily")
        return mapOf(
            "manufacturer" to manufacturer,
            "brand" to brand,
            "model" to model,
            "device" to (Build.DEVICE ?: ""),
            "sdkInt" to Build.VERSION.SDK_INT,
            "release" to (Build.VERSION.RELEASE ?: ""),
            "isXiaomiFamily" to isXiaomiFamily,
        )
    }

    fun readiness(context: Context): Map<String, Any?> {
        val exact = exactAlarmStatus(context)["granted"] == true
        val dnd = notificationPolicyStatus(context)["granted"] == true
        val listener = notificationListenerStatus(context)["granted"] == true
        val essentialOk = exact && dnd
        val battery = batteryOptimizationStatus(context)
        val restrictedBg = battery["ignoringOptimizations"] == false

        val level = when {
            !essentialOk -> "action_required"
            restrictedBg -> "limited_reliability"
            else -> "ready"
        }
        val missing = mutableListOf<String>()
        if (!exact) missing.add("exact_alarm")
        if (!dnd) missing.add("notification_policy")
        if (!listener) missing.add("notification_listener")

        return mapOf(
            "level" to level,
            "essentialOk" to essentialOk,
            "exactAlarmOk" to exact,
            "dndOk" to dnd,
            "listenerOk" to listener,
            "missing" to missing,
            "batteryMayRestrict" to restrictedBg,
        )
    }

    fun openExactAlarmSettings(context: Context): Map<String, Any?> {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(intent)
                mapOf("opened" to true, "action" to "ACTION_REQUEST_SCHEDULE_EXACT_ALARM")
            } else {
                openAppDetails(context)
            }
        } catch (e: Exception) {
            Log.w(TAG, "openExactAlarmSettings: ${e.message}")
            openAppDetails(context)
        }
    }

    fun openNotificationPolicySettings(context: Context): Map<String, Any?> {
        return try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            mapOf("opened" to true, "action" to "ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS")
        } catch (e: Exception) {
            Log.w(TAG, "openNotificationPolicySettings: ${e.message}")
            openAppDetails(context)
        }
    }

    fun openNotificationListenerSettings(context: Context): Map<String, Any?> {
        return try {
            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            mapOf("opened" to true, "action" to "ACTION_NOTIFICATION_LISTENER_SETTINGS")
        } catch (e: Exception) {
            Log.w(TAG, "openNotificationListenerSettings: ${e.message}")
            openAppDetails(context)
        }
    }

    fun openAppNotificationSettings(context: Context): Map<String, Any?> {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:${context.packageName}")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }
            context.startActivity(intent)
            mapOf("opened" to true, "action" to "APP_NOTIFICATION_SETTINGS")
        } catch (e: Exception) {
            Log.w(TAG, "openAppNotificationSettings: ${e.message}")
            openAppDetails(context)
        }
    }

    fun openBatterySettings(context: Context): Map<String, Any?> {
        return try {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            mapOf("opened" to true, "action" to "IGNORE_BATTERY_OPTIMIZATION_SETTINGS")
        } catch (e: Exception) {
            Log.w(TAG_BG, "openBatterySettings: ${e.message}")
            openAppDetails(context)
        }
    }

    fun openAppDetails(context: Context): Map<String, Any?> {
        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
            mapOf("opened" to true, "action" to "APPLICATION_DETAILS_SETTINGS")
        } catch (e: Exception) {
            Log.e(TAG, "openAppDetails failed: ${e.message}")
            mapOf("opened" to false, "error" to (e.message ?: "unknown"))
        }
    }
}
