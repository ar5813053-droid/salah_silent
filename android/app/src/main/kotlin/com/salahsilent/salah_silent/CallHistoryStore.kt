package com.salahsilent.salah_silent

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/** Persist call-during-Salah records in SharedPreferences (JSON). */
object CallHistoryStore {
    private const val TAG = "SalahSilent/CallDetection"
    private const val PREFS = "salah_silent_call_history"
    private const val KEY = "records"
    private const val KEY_SEEN = "seen_keys"
    private const val MAX = 200

    fun add(
        context: Context,
        caller: String,
        callType: String,
        prayerName: String?,
        duringSilent: Boolean,
        notifKey: String,
        timestamp: Long = System.currentTimeMillis(),
    ): Boolean {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val seen = prefs.getStringSet(KEY_SEEN, mutableSetOf())?.toMutableSet() ?: mutableSetOf()
        if (seen.contains(notifKey)) {
            Log.i(TAG, "Duplicate skipped key=$notifKey")
            return false
        }
        seen.add(notifKey)
        // Cap seen set
        if (seen.size > 500) {
            val trimmed = seen.toList().takeLast(300).toMutableSet()
            seen.clear()
            seen.addAll(trimmed)
        }

        val arr = try {
            JSONArray(prefs.getString(KEY, "[]"))
        } catch (_: Exception) {
            JSONArray()
        }
        val obj = JSONObject().apply {
            put("id", "$timestamp-${notifKey.hashCode()}")
            put("caller", caller.ifBlank { "Unknown Caller" })
            put("callType", callType)
            put("prayerName", prayerName ?: "")
            put("duringSilent", duringSilent)
            put("timestamp", timestamp)
            put("notifKey", notifKey)
        }
        // Newest first
        val out = JSONArray()
        out.put(obj)
        for (i in 0 until arr.length()) {
            if (out.length() >= MAX) break
            out.put(arr.getJSONObject(i))
        }
        prefs.edit().putString(KEY, out.toString()).putStringSet(KEY_SEEN, seen).apply()
        Log.i(TAG, "Stored call type=$callType duringSilent=$duringSilent")
        return true
    }

    fun list(context: Context): List<Map<String, Any?>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = try {
            JSONArray(prefs.getString(KEY, "[]"))
        } catch (_: Exception) {
            return emptyList()
        }
        val list = mutableListOf<Map<String, Any?>>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            list.add(
                mapOf(
                    "id" to o.optString("id"),
                    "caller" to o.optString("caller", "Unknown Caller"),
                    "callType" to o.optString("callType", "incoming"),
                    "prayerName" to o.optString("prayerName", ""),
                    "duringSilent" to o.optBoolean("duringSilent", false),
                    "timestamp" to o.optLong("timestamp", 0L),
                )
            )
        }
        return list
    }

    fun delete(context: Context, id: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = try {
            JSONArray(prefs.getString(KEY, "[]"))
        } catch (_: Exception) {
            return
        }
        val out = JSONArray()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.optString("id") != id) out.put(o)
        }
        prefs.edit().putString(KEY, out.toString()).apply()
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, "[]").putStringSet(KEY_SEEN, emptySet()).apply()
    }
}
