#!/usr/bin/env python3
"""Install the native Android home-screen widget into Flutter's generated Android project."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

root = Path(".")
gradle = next((p for p in (root / "android/app/build.gradle.kts", root / "android/app/build.gradle") if p.exists()), None)
if gradle is None:
    raise SystemExit("Android app Gradle file not found")
gradle_text = gradle.read_text()
match = re.search(r'namespace\s*(?:=\s*)?["\']([^"\']+)["\']', gradle_text)
if not match:
    raise SystemExit("Could not determine Android namespace")
package = match.group(1)
package_path = Path(*package.split("."))
base = root / "android/app/src/main"
android_ns = "http://schemas.android.com/apk/res/android"
ET.register_namespace("android", android_ns)
A = "{" + android_ns + "}"

# Native widget provider and refresh actions.
provider = r'''package __PACKAGE__.widget

import __PACKAGE__.R

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.widget.RemoteViews
import android.widget.Toast
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object WidgetStore {
    const val PREFS = "user_hub_widget"
    const val SELECTED_USER = "selected_user_id"
    const val ACTION_REFRESH = "com.userhub.widget.REFRESH"
    const val ACTION_ADD_DP = "com.userhub.widget.ADD_DP"
    const val ACTION_ADD_BONUS = "com.userhub.widget.ADD_BONUS"
    const val ACTION_SELECT = "com.userhub.widget.SELECT_USER"
    const val ACTION_ADD_USER = "com.userhub.widget.ADD_USER"
    const val RECENT_USERS = "recent_user_ids"
    const val MODE = "entry_mode"
    const val AMOUNT = "entry_amount"
    const val DAILY_GOAL = "daily_dp_goal"
    const val ACTION_MODE_DP = "com.userhub.widget.MODE_DP"
    const val ACTION_MODE_BONUS = "com.userhub.widget.MODE_BONUS"
    const val ACTION_MINUS = "com.userhub.widget.MINUS"
    const val ACTION_PLUS = "com.userhub.widget.PLUS"
    const val ACTION_PRESET = "com.userhub.widget.PRESET"
    const val ACTION_EDIT_AMOUNT = "com.userhub.widget.EDIT_AMOUNT"
    const val ACTION_EDIT_GOAL = "com.userhub.widget.EDIT_GOAL"
    const val ACTION_UNDO = "com.userhub.widget.UNDO"
    const val LAST_TABLE = "undo_table"
    const val LAST_ROW = "undo_row"
    const val UNDO_UNTIL = "undo_until"

    fun database(context: Context): SQLiteDatabase? {
        val file = context.getDatabasePath("user_hub.db")
        if (!file.exists()) return null
        return try { SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE) }
        catch (_: Exception) { null }
    }

    fun users(context: Context): List<WidgetUser> {
        val db = database(context) ?: return emptyList()
        return try {
            db.rawQuery("SELECT id, name, phone FROM users WHERE archived = 0 ORDER BY name COLLATE NOCASE", null).use { c ->
                buildList { while (c.moveToNext()) add(WidgetUser(c.getLong(0), c.getString(1), c.getString(2))) }
            }
        } catch (_: Exception) { emptyList() } finally { db.close() }
    }

    fun selectedUserId(context: Context): Long {
        val saved = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(SELECTED_USER, -1L)
        val available = users(context)
        return if (available.any { it.id == saved }) saved else available.firstOrNull()?.id ?: -1L
    }

    fun setSelectedUser(context: Context, id: Long) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val recent = prefs.getString(RECENT_USERS, "")!!.split(",").mapNotNull { it.toLongOrNull() }.filter { it != id }
        prefs.edit().putLong(SELECTED_USER, id).putString(RECENT_USERS, (listOf(id) + recent).take(3).joinToString(",")).apply()
    }
    fun recentUsers(context: Context): List<WidgetUser> {
        // Prefer users with the latest real DP/bonus activity, including entries made inside the app.
        val fromEntries = database(context)?.let { db ->
            try {
                db.rawQuery("""
                    SELECT u.id, u.name, u.phone, MAX(a.created_at) AS last_at
                    FROM users u
                    JOIN (
                        SELECT user_id, created_at FROM dp_entries
                        UNION ALL
                        SELECT user_id, created_at FROM bonus_entries
                    ) a ON a.user_id = u.id
                    WHERE u.archived = 0
                    GROUP BY u.id, u.name, u.phone
                    ORDER BY last_at DESC
                    LIMIT 3
                """.trimIndent(), null).use { c ->
                    buildList {
                        while (c.moveToNext()) add(WidgetUser(c.getLong(0), c.getString(1), c.getString(2)))
                    }
                }
            } catch (_: Exception) { emptyList() } finally { db.close() }
        } ?: emptyList()
        val ids = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(RECENT_USERS, "")!!.split(",").mapNotNull { it.toLongOrNull() }
        val all = users(context).associateBy { it.id }
        val fallback = ids.mapNotNull { all[it] }
        val selected = all[selectedUserId(context)]
        return (fromEntries + fallback + listOfNotNull(selected)).distinctBy { it.id }.take(3)
    }

    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, UserHubWidgetProviderV2::class.java))
        if (ids.isNotEmpty()) UserHubWidgetProviderV2().onUpdate(context, manager, ids)
    }

    fun money(value: Double): String {
        val whole = value % 1.0 == 0.0
        return if (whole) String.format(Locale.US, "%,.0f", value) else String.format(Locale.US, "%,.2f", value)
    }
}

class UserHubWidgetProviderV2 : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id -> manager.updateAppWidget(id, views(context)) }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, appWidgetId: Int, newOptions: android.os.Bundle) {
        manager.updateAppWidget(appWidgetId, views(context))
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return
        if (!action.startsWith("com.userhub.widget.")) return
        val pending = goAsync()
        Thread {
            try {
                val prefs = context.getSharedPreferences(WidgetStore.PREFS, Context.MODE_PRIVATE)
                when (action) {
                    WidgetStore.ACTION_MODE_DP -> prefs.edit().putString(WidgetStore.MODE, "DP").apply()
                    WidgetStore.ACTION_MODE_BONUS -> prefs.edit().putString(WidgetStore.MODE, "BONUS").apply()
                    WidgetStore.ACTION_MINUS -> prefs.edit().putFloat(WidgetStore.AMOUNT, (prefs.getFloat(WidgetStore.AMOUNT, 5f) - 1f).coerceAtLeast(0.01f)).apply()
                    WidgetStore.ACTION_PLUS -> prefs.edit().putFloat(WidgetStore.AMOUNT, prefs.getFloat(WidgetStore.AMOUNT, 5f) + 1f).apply()
                    WidgetStore.ACTION_PRESET -> prefs.edit().putFloat(WidgetStore.AMOUNT, intent.getFloatExtra("amount", 5f)).apply()
                    WidgetStore.ACTION_ADD_DP -> addEntry(context, false)
                    WidgetStore.ACTION_ADD_BONUS -> addEntry(context, true)
                    WidgetStore.ACTION_UNDO -> undoLast(context)
                }
                WidgetStore.refresh(context)
            } finally {
                pending.finish()
            }
        }.start()
    }

    private fun showToast(context: Context, message: String, duration: Int) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            showToast(context, message, duration).show()
        }
    }

    private fun addEntry(context: Context, isBonus: Boolean) {
        val prefs = context.getSharedPreferences(WidgetStore.PREFS, Context.MODE_PRIVATE)
        val amount = prefs.getFloat(WidgetStore.AMOUNT, 5f).toDouble()
        val userId = WidgetStore.selectedUserId(context)
        if (!amount.isFinite() || amount <= 0.0 || userId <= 0L) {
            Toast.makeText(context, "Choose a user and enter a valid amount first", Toast.LENGTH_LONG)
            return
        }
        val db = WidgetStore.database(context)
        if (db == null) {
            showToast(context, "Open UserHub once to initialize its database", Toast.LENGTH_LONG)
            return
        }
        try {
            val exists = db.rawQuery("SELECT id FROM users WHERE id=? AND archived=0", arrayOf(userId.toString())).use { it.moveToFirst() }
            if (!exists) {
                showToast(context, "Selected user is no longer available", Toast.LENGTH_LONG)
                return
            }
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val now = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())
            val values = android.content.ContentValues().apply {
                put("user_id", userId); put("entry_date", today); put("created_at", now)
                if (isBonus) {
                    put("amount", amount); put("reason", "Other"); putNull("related_dp"); put("notes", "")
                } else {
                    put("dp1", amount); put("dp2", 0); put("dp3", 0); put("dp4", 0); put("dp5", 0)
                    put("total", amount); put("dp_count", 1); put("contacted", 0); put("notes", "")
                }
            }
            db.beginTransaction()
            val table = if (isBonus) "bonus_entries" else "dp_entries"
            val rowId = db.insertOrThrow(table, null, values)
            db.setTransactionSuccessful()
            db.endTransaction()
            prefs.edit().putString(WidgetStore.LAST_TABLE, table).putLong(WidgetStore.LAST_ROW, rowId)
                .putLong(WidgetStore.UNDO_UNTIL, System.currentTimeMillis() + 8000L).apply()
            WidgetStore.setSelectedUser(context, userId)
            WidgetStore.refresh(context)
            val handler = android.os.Handler(android.os.Looper.getMainLooper())
            val expiresAt = System.currentTimeMillis() + 8000L
            val tick = object : Runnable {
                override fun run() {
                    WidgetStore.refresh(context)
                    if (System.currentTimeMillis() < expiresAt) handler.postDelayed(this, 1000L)
                }
            }
            handler.postDelayed(tick, 1000L)
            showToast(context, (if (isBonus) "Bonus " else "DP ") + WidgetStore.money(amount) + " coins added", Toast.LENGTH_SHORT)
        } catch (_: Exception) {
            try { if (db.inTransaction()) db.endTransaction() } catch (_: Exception) {}
            showToast(context, "Could not save entry. Open UserHub and retry.", Toast.LENGTH_LONG)
        } finally { db.close() }
    }

    private fun undoLast(context: Context) {
        val prefs = context.getSharedPreferences(WidgetStore.PREFS, Context.MODE_PRIVATE)
        val table = prefs.getString(WidgetStore.LAST_TABLE, "") ?: ""
        val row = prefs.getLong(WidgetStore.LAST_ROW, -1L)
        if (System.currentTimeMillis() > prefs.getLong(WidgetStore.UNDO_UNTIL, 0L) || row <= 0L || table !in listOf("dp_entries", "bonus_entries")) {
            showToast(context, "Undo period expired", Toast.LENGTH_SHORT)
        } else {
            val db = WidgetStore.database(context)
            if (db != null) {
                try { db.delete(table, "id=?", arrayOf(row.toString())); showToast(context, "Entry undone", Toast.LENGTH_SHORT) }
                catch (_: Exception) { showToast(context, "Could not undo entry", Toast.LENGTH_LONG) }
                finally { db.close() }
            }
        }
        prefs.edit().remove(WidgetStore.LAST_TABLE).remove(WidgetStore.LAST_ROW).remove(WidgetStore.UNDO_UNTIL).apply()
    }
    private fun views(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_user_hub)
        var dp = 0.0
        var bonus = 0.0
        var name = "Open User Hub once"
        var userId = WidgetStore.selectedUserId(context)
        val db = WidgetStore.database(context)
        if (db != null) {
            try {
                val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
                db.rawQuery("SELECT COALESCE(SUM(total),0) FROM dp_entries WHERE entry_date=?", arrayOf(today)).use { if (it.moveToFirst()) dp = it.getDouble(0) }
                db.rawQuery("SELECT COALESCE(SUM(amount),0) FROM bonus_entries WHERE entry_date=?", arrayOf(today)).use { if (it.moveToFirst()) bonus = it.getDouble(0) }
                db.rawQuery("SELECT name FROM users WHERE id=? AND archived=0", arrayOf(userId.toString())).use { if (it.moveToFirst()) name = it.getString(0) }
            } catch (_: Exception) { name = "Open User Hub once" } finally { db.close() }
        }
        val users = WidgetStore.users(context)
        if (users.isEmpty()) name = "No users yet"
        views.setTextViewText(R.id.widget_dp_total, WidgetStore.money(dp) + " coins")
        views.setTextViewText(R.id.widget_bonus_total, WidgetStore.money(bonus) + " coins")
        views.setTextViewText(R.id.widget_status, SimpleDateFormat("EEE, d MMM", Locale.getDefault()).format(Date()))
        val prefs = context.getSharedPreferences(WidgetStore.PREFS, Context.MODE_PRIVATE)
        val mode = prefs.getString(WidgetStore.MODE, "DP") ?: "DP"
        val amount = prefs.getFloat(WidgetStore.AMOUNT, 5f)
        val goal = prefs.getFloat(WidgetStore.DAILY_GOAL, 50f).coerceAtLeast(0f)
        views.setTextViewText(R.id.widget_amount, WidgetStore.money(amount.toDouble()))
        views.setTextViewText(R.id.widget_amount_unit, if (amount == 1f) "coin" else "coins")
        views.setTextViewText(R.id.widget_goal_text, "DP today · goal " + WidgetStore.money(goal.toDouble()))
        views.setProgressBar(R.id.widget_goal_ring, 100, if (goal > 0) ((dp / goal) * 100).toInt().coerceIn(0, 100) else 0, false)
        views.setTextViewText(R.id.widget_goal_ring_text, WidgetStore.money(dp))
        views.setTextViewText(R.id.widget_add, if (mode == "BONUS") "+ Add Bonus · " + WidgetStore.money(amount.toDouble()) else "+ Add DP · " + WidgetStore.money(amount.toDouble()))
        views.setInt(R.id.widget_add, "setBackgroundResource", if (mode == "BONUS") R.drawable.widget_bonus_button else R.drawable.widget_dp_button)
        views.setInt(R.id.widget_mode_dp, "setBackgroundResource", if (mode == "DP") R.drawable.widget_dp_button else R.drawable.widget_metric_background)
        views.setInt(R.id.widget_mode_bonus, "setBackgroundResource", if (mode == "BONUS") R.drawable.widget_bonus_button else R.drawable.widget_metric_background)
        views.setTextColor(R.id.widget_mode_dp, if (mode == "DP") android.graphics.Color.WHITE else android.graphics.Color.rgb(147, 160, 180))
        views.setTextColor(R.id.widget_mode_bonus, if (mode == "BONUS") android.graphics.Color.WHITE else android.graphics.Color.rgb(147, 160, 180))
        val undoUntil = prefs.getLong(WidgetStore.UNDO_UNTIL, 0L)
        val canUndo = prefs.getLong(WidgetStore.LAST_ROW, -1L) > 0L && System.currentTimeMillis() <= undoUntil
        views.setViewVisibility(R.id.widget_undo, if (canUndo) android.view.View.VISIBLE else android.view.View.GONE)
        if (canUndo) {
            val savedAmount = prefs.getFloat(WidgetStore.AMOUNT, 5f)
            views.setTextViewText(R.id.widget_add, "✓ " + WidgetStore.money(savedAmount.toDouble()) + " coins added")
            views.setInt(R.id.widget_add, "setBackgroundResource", R.drawable.widget_success_button)
            views.setTextViewText(R.id.widget_undo, "Undo · " + (((undoUntil-System.currentTimeMillis()).coerceAtLeast(0)+999)/1000) + "s")
        } else {
            views.setTextViewText(R.id.widget_add, if (mode == "BONUS") "+ Add Bonus · " + WidgetStore.money(amount.toDouble()) else "+ Add DP · " + WidgetStore.money(amount.toDouble()))
            views.setInt(R.id.widget_add, "setBackgroundResource", if (mode == "BONUS") R.drawable.widget_bonus_button else R.drawable.widget_dp_button)
        }

        fun activityIntent(action: String, request: Int): PendingIntent {
            val i = Intent(context, WidgetQuickEntryActivity::class.java).setAction(action)
            return PendingIntent.getActivity(context, request, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        fun broadcastIntent(action: String, request: Int, value: Float? = null): PendingIntent {
            val i = Intent(context, UserHubWidgetProviderV2::class.java).setAction(action)
            if (value != null) i.putExtra("amount", value)
            return PendingIntent.getBroadcast(context, request, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        views.setOnClickPendingIntent(R.id.widget_mode_dp, broadcastIntent(WidgetStore.ACTION_MODE_DP, 41))
        views.setOnClickPendingIntent(R.id.widget_mode_bonus, broadcastIntent(WidgetStore.ACTION_MODE_BONUS, 42))
        views.setOnClickPendingIntent(R.id.widget_minus, broadcastIntent(WidgetStore.ACTION_MINUS, 43))
        views.setOnClickPendingIntent(R.id.widget_plus, broadcastIntent(WidgetStore.ACTION_PLUS, 44))
        views.setOnClickPendingIntent(R.id.widget_preset_1, broadcastIntent(WidgetStore.ACTION_PRESET, 45, 1f))
        views.setOnClickPendingIntent(R.id.widget_preset_5, broadcastIntent(WidgetStore.ACTION_PRESET, 46, 5f))
        views.setOnClickPendingIntent(R.id.widget_preset_10, broadcastIntent(WidgetStore.ACTION_PRESET, 47, 10f))
        views.setOnClickPendingIntent(R.id.widget_preset_25, broadcastIntent(WidgetStore.ACTION_PRESET, 48, 25f))
        views.setOnClickPendingIntent(R.id.widget_amount_group, activityIntent(WidgetStore.ACTION_EDIT_AMOUNT, 49))
        views.setOnClickPendingIntent(R.id.widget_goal_text, activityIntent(WidgetStore.ACTION_EDIT_GOAL, 50))
        views.setOnClickPendingIntent(R.id.widget_add, broadcastIntent(if (canUndo) WidgetStore.ACTION_REFRESH else if (mode == "BONUS") WidgetStore.ACTION_ADD_BONUS else WidgetStore.ACTION_ADD_DP, 51))
        views.setOnClickPendingIntent(R.id.widget_undo, broadcastIntent(WidgetStore.ACTION_UNDO, 52))
        views.setOnClickPendingIntent(R.id.widget_selected_detail, activityIntent(WidgetStore.ACTION_SELECT, 16))
        views.setOnClickPendingIntent(R.id.widget_quick_add_user, activityIntent(WidgetStore.ACTION_SELECT, 15))
        val recent = WidgetStore.recentUsers(context)
        val avatarIds = intArrayOf(R.id.widget_recent_avatar_1, R.id.widget_recent_avatar_2, R.id.widget_recent_avatar_3)
        val nameIds = intArrayOf(R.id.widget_recent_name_1, R.id.widget_recent_name_2, R.id.widget_recent_name_3)
        val badgeIds = intArrayOf(R.id.widget_recent_badge_1, R.id.widget_recent_badge_2, R.id.widget_recent_badge_3)
        recent.indices.take(3).forEach { index ->
            val user = recent[index]
            val avatar = user.name.trim().firstOrNull()?.uppercaseChar()?.toString() ?: "?"
            views.setTextViewText(avatarIds[index], avatar)
            views.setInt(avatarIds[index], "setBackgroundResource", if (user.id == userId) R.drawable.widget_avatar_selected else R.drawable.widget_avatar)
            views.setTextViewText(nameIds[index], user.name.take(10))
            val table = if (mode == "BONUS") "bonus_entries" else "dp_entries"
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val count = WidgetStore.database(context)?.let { d ->
                try {
                    d.rawQuery("SELECT COUNT(*) FROM $table WHERE user_id=? AND entry_date=?", arrayOf(user.id.toString(), today)).use { if (it.moveToFirst()) it.getInt(0) else 0 }
                } catch (_: Exception) { 0 } finally { d.close() }
            } ?: 0
            views.setTextViewText(badgeIds[index], count.toString())
            views.setViewVisibility(avatarIds[index], android.view.View.VISIBLE)
            views.setViewVisibility(nameIds[index], android.view.View.VISIBLE)
            views.setViewVisibility(badgeIds[index], if (count > 0) android.view.View.VISIBLE else android.view.View.GONE)
            val pick = Intent(context, WidgetQuickEntryActivity::class.java).setAction(WidgetStore.ACTION_SELECT).putExtra("selected_user_id", user.id)
            val pending = PendingIntent.getActivity(context, 30 + index, pick, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(avatarIds[index], pending)
            views.setOnClickPendingIntent(nameIds[index], pending)
        }
        for (index in recent.size.coerceAtMost(3)..2) {
            views.setViewVisibility(avatarIds[index], android.view.View.GONE)
            views.setViewVisibility(nameIds[index], android.view.View.GONE)
            views.setViewVisibility(badgeIds[index], android.view.View.GONE)
        }
        val lastTable = if (mode == "BONUS") "bonus_entries" else "dp_entries"
        val lastColumn = if (mode == "BONUS") "amount" else "total"
        val lastLabel = if (mode == "BONUS") "Bonus" else "DP"
        var lastDetail = "For $name · no previous $lastLabel"
        val detailDb = WidgetStore.database(context)
        if (detailDb != null) {
            try {
                detailDb.rawQuery("SELECT $lastColumn, created_at FROM $lastTable WHERE user_id=? ORDER BY entry_date DESC, created_at DESC LIMIT 1", arrayOf(userId.toString())).use { c ->
                    if (c.moveToFirst()) {
                        val coins = WidgetStore.money(c.getDouble(0))
                        val stamp = c.getString(1)
                        val age = try {
                            val parsed = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).parse(stamp)
                            val mins = ((System.currentTimeMillis() - (parsed?.time ?: System.currentTimeMillis())).coerceAtLeast(0L) / 60000L)
                            if (mins < 60) mins.toString() + "m ago" else if (mins < 1440) (mins / 60).toString() + "h ago" else (mins / 1440).toString() + "d ago"
                        } catch (_: Exception) { "" }
                        lastDetail = "For $name · last $lastLabel $coins coins" + if (age.isNotBlank()) " · $age" else ""
                    }
                }
            } catch (_: Exception) { } finally { detailDb.close() }
        }
        views.setTextViewText(R.id.widget_selected_detail, lastDetail)
        val refresh = Intent(context, UserHubWidgetProviderV2::class.java).setAction(WidgetStore.ACTION_REFRESH)
        val refreshPending = PendingIntent.getBroadcast(context, 14, refresh, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_refresh, refreshPending)
        return views
    }
}
'''.replace("__PACKAGE__", package)

activity = r'''package __PACKAGE__.widget

import __PACKAGE__.R
import android.app.Activity
import android.os.Bundle
import android.content.ContentValues
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.text.Editable
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.ArrayAdapter
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ListView
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

data class WidgetUser(val id: Long, val name: String, val phone: String)

class WidgetQuickEntryActivity : Activity() {
    private var action = WidgetStore.ACTION_ADD_DP
    private var users = emptyList<WidgetUser>()
    private var filtered = emptyList<WidgetUser>()
    private var selectedId = -1L
    private lateinit var search: EditText
    private lateinit var list: ListView
    private lateinit var adapter: ArrayAdapter<String>
    private lateinit var amount: EditText
    private lateinit var reason: Spinner
    private val ink = Color.rgb(24, 32, 43)
    private val muted = Color.rgb(124, 132, 144)
    private val orange = Color.rgb(243, 107, 33)
    private val border = Color.rgb(233, 235, 239)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        action = intent.action ?: WidgetStore.ACTION_ADD_DP
        users = WidgetStore.users(this)
        if (action == WidgetStore.ACTION_EDIT_AMOUNT || action == WidgetStore.ACTION_EDIT_GOAL) { showSettingForm(); return }
        selectedId = WidgetStore.selectedUserId(this)
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.setDimAmount(0.58f)
        if (action == WidgetStore.ACTION_ADD_USER || users.isEmpty()) { showAddUserForm(); return }
        // Recent-user chips send an ID: select immediately and close, without showing the picker.
        val tappedRecentUserId = intent.getLongExtra("selected_user_id", -1L)
        if (action == WidgetStore.ACTION_SELECT && tappedRecentUserId > 0L) {
            if (users.any { it.id == tappedRecentUserId }) {
                WidgetStore.setSelectedUser(this, tappedRecentUserId)
                WidgetStore.refresh(this)
                finish()
            } else {
                Toast.makeText(this, "That user is no longer available", Toast.LENGTH_SHORT).show()
                finish()
            }
            return
        }
        buildForm()
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
    private fun shape(color: Int, radius: Int, stroke: Int = 0) = GradientDrawable().apply {
        setColor(color); cornerRadius = dp(radius).toFloat()
        if (stroke != 0) setStroke(dp(1), stroke)
    }
    private fun text(value: String, size: Float, color: Int = ink) = TextView(this).apply {
        text = value; textSize = size; setTextColor(color)
    }
    private fun field(hintText: String, numeric: Boolean = false) = EditText(this).apply {
        hint = hintText; textSize = 15f; setTextColor(ink); setHintTextColor(muted)
        setSingleLine(true); setPadding(dp(15), 0, dp(15), 0); background = shape(Color.WHITE, 15, border)
        if (numeric) inputType = 8194
    }

    private fun showSettingForm() {
        val isGoal = action == WidgetStore.ACTION_EDIT_GOAL
        val prefs = getSharedPreferences(WidgetStore.PREFS, MODE_PRIVATE)
        val mode = prefs.getString(WidgetStore.MODE, "DP") ?: "DP"
        val isBonus = !isGoal && mode == "BONUS"
        val current = if (isGoal) prefs.getFloat(WidgetStore.DAILY_GOAL, 50f) else prefs.getFloat(WidgetStore.AMOUNT, 5f)
        val selected = users.firstOrNull { it.id == WidgetStore.selectedUserId(this) }
        val userName = selected?.name ?: "Select a user"
        val accent = if (isBonus) Color.rgb(96, 165, 250) else Color.rgb(243, 107, 33)
        val navy = Color.rgb(17, 27, 48)
        val surface = Color.rgb(28, 40, 61)
        val secondary = Color.rgb(163, 172, 191)
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(20), dp(20), dp(20))
            background = shape(navy, 34)
        }
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.setDimAmount(0.62f)

        val header = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
        val avatar = TextView(this).apply {
            text = if (isGoal) "◎" else userName.trim().firstOrNull()?.uppercaseChar()?.toString() ?: "?"
            textSize = 25f; gravity = Gravity.CENTER; setTextColor(accent)
            background = shape(Color.rgb(36, 50, 75), 60)
        }
        header.addView(avatar, LinearLayout.LayoutParams(dp(56), dp(56)))
        val heading = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(14), 0, dp(6), 0) }
        heading.addView(text(if (isGoal) "Set daily goal" else if (isBonus) "Add Bonus" else "Add DP", 23f, Color.WHITE).apply { setTypeface(null, Typeface.BOLD) })
        heading.addView(text(if (isGoal) "Daily DP target · UserHub" else "for $userName · enter coins", 13f, secondary))
        header.addView(heading, LinearLayout.LayoutParams(0, -2, 1f))
        val close = TextView(this).apply {
            text = "×"; textSize = 30f; gravity = Gravity.CENTER; setTextColor(secondary)
            background = shape(surface, 50); setOnClickListener { finish() }
        }
        header.addView(close, LinearLayout.LayoutParams(dp(52), dp(52)))
        panel.addView(header)

        val amountCard = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER
            background = shape(surface, 30); setPadding(dp(14), dp(8), dp(14), dp(8))
        }
        val value = EditText(this).apply {
            setTextColor(Color.WHITE); setHintTextColor(secondary); textSize = 52f
            gravity = Gravity.CENTER; setSingleLine(true); inputType = 8194
            setPadding(0, 0, 0, 0); background = android.graphics.drawable.ColorDrawable(Color.TRANSPARENT)
            setSelectAllOnFocus(true)
            setText(if (current % 1f == 0f) current.toInt().toString() else current.toString())
        }
        amountCard.addView(value, LinearLayout.LayoutParams(0, dp(112), 1f))
        amountCard.addView(text("coins", 16f, secondary))
        panel.addView(amountCard, LinearLayout.LayoutParams(-1, dp(132)).apply { topMargin = dp(18) })

        var todayDp = 0.0
        val db = WidgetStore.database(this)
        if (db != null) {
            try {
                val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
                db.rawQuery("SELECT COALESCE(SUM(total),0) FROM dp_entries WHERE entry_date=?", arrayOf(today)).use { if (it.moveToFirst()) todayDp = it.getDouble(0) }
            } catch (_: Exception) { } finally { db.close() }
        }
        val status = text("", 13f, secondary).apply { gravity = Gravity.CENTER; setPadding(0, dp(12), 0, dp(12)) }
        panel.addView(status)
        val presets = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER }
        val presetValues = if (isGoal) listOf(10f, 25f, 50f, 100f) else listOf(1f, 5f, 10f, 25f)
        presetValues.forEachIndexed { index, step ->
            val chip = TextView(this).apply {
                text = "+" + WidgetStore.money(step.toDouble()); textSize = 14f
                gravity = Gravity.CENTER; setTypeface(null, Typeface.BOLD); setTextColor(accent)
                background = shape(surface, 40)
                setOnClickListener {
                    val old = value.text.toString().trim().toFloatOrNull() ?: 0f
                    value.setText(WidgetStore.money((old + step).toDouble()))
                    value.setSelection(value.text.length)
                }
            }
            presets.addView(chip, LinearLayout.LayoutParams(0, dp(52), 1f).apply {
                if (index > 0) marginStart = dp(7)
            })
        }
        val clear = TextView(this).apply {
            text = "Clear"; textSize = 13f; gravity = Gravity.CENTER
            setTextColor(secondary); background = shape(surface, 40)
            setOnClickListener { value.setText(""); value.requestFocus() }
        }
        presets.addView(clear, LinearLayout.LayoutParams(dp(82), dp(52)).apply { marginStart = dp(7) })
        panel.addView(presets)

        val save = TextView(this).apply {
            gravity = Gravity.CENTER; setTextColor(Color.WHITE); textSize = 18f
            setTypeface(null, Typeface.BOLD); background = shape(accent, 60)
            setOnClickListener {
                val parsed = value.text.toString().trim().replace(",", "").toFloatOrNull()
                if (parsed == null || !parsed.isFinite() || parsed < 0f || (!isGoal && parsed <= 0f)) {
                    value.error = "Enter a valid amount"; return@setOnClickListener
                }
                prefs.edit().putFloat(if (isGoal) WidgetStore.DAILY_GOAL else WidgetStore.AMOUNT, parsed).apply()
                WidgetStore.refresh(this@WidgetQuickEntryActivity)
                finish()
            }
        }
        panel.addView(save, LinearLayout.LayoutParams(-1, dp(58)).apply { topMargin = dp(16) })

        fun updatePreview() {
            val parsed = value.text.toString().trim().replace(",", "").toFloatOrNull() ?: 0f
            val amountText = WidgetStore.money(parsed.toDouble())
            status.text = if (isGoal) {
                "DP today  " + WidgetStore.money(todayDp) + "  ·  goal " + amountText
            } else {
                val label = if (isBonus) "Bonus today" else "DP today"
                val before = if (isBonus) {
                    val d = WidgetStore.database(this)
                    var total = 0.0
                    if (d != null) try {
                        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
                        d.rawQuery("SELECT COALESCE(SUM(amount),0) FROM bonus_entries WHERE entry_date=?", arrayOf(today)).use { if (it.moveToFirst()) total = it.getDouble(0) }
                    } catch (_: Exception) { } finally { d.close() }
                    total
                } else todayDp
                "$label  " + WidgetStore.money(before) + "  →  " + amountText + "  ·  goal " + WidgetStore.money(prefs.getFloat(WidgetStore.DAILY_GOAL, 50f).toDouble())
            }
            save.text = if (isGoal) "Save goal  $amountText coins" else "Save  $amountText coins"
        }
        value.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) { updatePreview() }
            override fun afterTextChanged(s: Editable?) {}
        })
        updatePreview()
        setContentView(panel)
        window.setLayout((resources.displayMetrics.widthPixels * .9f).toInt(), WindowManager.LayoutParams.WRAP_CONTENT)
    }

    private fun buildForm() {
        val selectOnly = action == WidgetStore.ACTION_SELECT
        val isBonus = action == WidgetStore.ACTION_ADD_BONUS
        if (selectOnly) { buildUserPickerSheet(); return }
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; setPadding(dp(20), dp(20), dp(20), dp(18))
            background = shape(Color.WHITE, 26)
        }
        panel.addView(text(if (selectOnly) "Choose user" else if (isBonus) "Add bonus" else "Add DP", 20f).apply {
            setTypeface(null, Typeface.BOLD)
        })
        panel.addView(text("Search by user name or phone number", 12f, muted).apply {
            setPadding(0, dp(6), 0, dp(12))
        })
        search = field("Search users")
        search.setCompoundDrawablesWithIntrinsicBounds(android.R.drawable.ic_menu_search, 0, 0, 0)
        search.compoundDrawablePadding = dp(8)
        panel.addView(search, LinearLayout.LayoutParams(-1, dp(50)))

        filtered = users
        adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, users.map { (if (it.id == selectedId) "✓  " else "") + it.name + "  ·  " + it.phone })
        list = ListView(this).apply {
            this.adapter = this@WidgetQuickEntryActivity.adapter
            divider = android.graphics.drawable.ColorDrawable(border); dividerHeight = dp(1)
            background = shape(Color.rgb(244, 245, 247), 14)
            setPadding(dp(5), dp(3), dp(5), dp(3))
        }
        panel.addView(list, LinearLayout.LayoutParams(-1, dp(if (selectOnly) 190 else 128)))
        list.setOnItemClickListener { _, _, position, _ ->
            selectedId = filtered[position].id
            adapter.clear(); adapter.addAll(filtered.map { (if (it.id == selectedId) "✓  " else "") + it.name + "  ·  " + it.phone }); adapter.notifyDataSetChanged()
            search.setText(filtered[position].name)
            search.setSelection(search.text.length)
        }
        search.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                val q = s.toString().trim().lowercase(Locale.ROOT)
                filtered = users.filter { it.name.lowercase(Locale.ROOT).contains(q) || it.phone.lowercase(Locale.ROOT).contains(q) }
                adapter.clear()
                adapter.addAll(filtered.map { (if (it.id == selectedId) "✓  " else "") + it.name + "  ·  " + it.phone })
                list.visibility = if (filtered.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE
            }
            override fun afterTextChanged(s: Editable?) {}
        })

        if (!selectOnly) {
            panel.addView(text("Amount (coins)", 12f, muted).apply { setPadding(0, dp(13), 0, dp(5)) })
            amount = field("Enter amount", true)
            val savedAmount = getSharedPreferences(WidgetStore.PREFS, MODE_PRIVATE).getFloat(WidgetStore.AMOUNT, 5f)
            amount.setText(if (savedAmount % 1f == 0f) savedAmount.toInt().toString() else savedAmount.toString())
            panel.addView(amount, LinearLayout.LayoutParams(-1, dp(52)))
            if (isBonus) {
                panel.addView(text("Reason", 12f, muted).apply { setPadding(0, dp(10), 0, dp(4)) })
                reason = Spinner(this)
                reason.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, listOf("Other", "Deposit", "Special", "Promotional"))
                panel.addView(reason, LinearLayout.LayoutParams(-1, dp(44)))
            }
        }
        val actions = LinearLayout(this).apply { gravity = Gravity.END or Gravity.CENTER_VERTICAL; setPadding(0, dp(15), 0, 0) }
        actions.addView(TextView(this).apply {
            text = "Cancel"; textSize = 13f; setTextColor(muted); gravity = Gravity.CENTER
            setPadding(dp(18), 0, dp(18), 0); setOnClickListener { finish() }
        }, LinearLayout.LayoutParams(-2, dp(48)))
        actions.addView(TextView(this).apply {
            text = if (selectOnly) "Use this user" else "Save"; textSize = 13f
            setTypeface(null, Typeface.BOLD); setTextColor(Color.WHITE); gravity = Gravity.CENTER
            setPadding(dp(22), 0, dp(22), 0); background = shape(orange, 30)
            setOnClickListener { if (selectOnly) saveUser() else saveEntry(isBonus) }
        }, LinearLayout.LayoutParams(-2, dp(48)))
        panel.addView(actions)
        val scroll = android.widget.ScrollView(this).apply { isFillViewport = true; addView(panel) }
        setContentView(scroll)
        window.setLayout((resources.displayMetrics.widthPixels * 0.92f).toInt(), WindowManager.LayoutParams.WRAP_CONTENT)
    }

    // Mirrors the app's AppDropdownSheet: bottom sheet, search, orange selected row and confirm.
    private fun buildUserPickerSheet() {
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(12), dp(20), dp(20))
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadii = floatArrayOf(dp(28).toFloat(), dp(28).toFloat(), dp(28).toFloat(), dp(28).toFloat(), 0f, 0f, 0f, 0f)
            }
        }
        panel.addView(View(this).apply {
            background = shape(Color.rgb(213, 217, 224), 8)
        }, LinearLayout.LayoutParams(dp(42), dp(4)).apply { gravity = Gravity.CENTER; bottomMargin = dp(16) })
        val heading = LinearLayout(this).apply { gravity = Gravity.CENTER_VERTICAL; orientation = LinearLayout.HORIZONTAL }
        heading.addView(text("Select user", 19f).apply { setTypeface(null, Typeface.BOLD) }, LinearLayout.LayoutParams(0, dp(42), 1f))
        heading.addView(TextView(this).apply {
            text = "✕"; textSize = 21f; setTextColor(muted); gravity = Gravity.CENTER
            setOnClickListener { finish() }
        }, LinearLayout.LayoutParams(dp(42), dp(42)))
        panel.addView(heading)
        search = field("Search users")
        search.setCompoundDrawablesWithIntrinsicBounds(android.R.drawable.ic_menu_search, 0, 0, 0)
        search.compoundDrawablePadding = dp(10)
        search.background = shape(Color.rgb(242, 243, 246), 14)
        panel.addView(search, LinearLayout.LayoutParams(-1, dp(52)).apply { topMargin = dp(8); bottomMargin = dp(12) })
        filtered = users
        val rows = object : android.widget.BaseAdapter() {
            override fun getCount() = filtered.size
            override fun getItem(position: Int) = filtered[position]
            override fun getItemId(position: Int) = filtered[position].id
            override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                val user = getItem(position)
                val active = user.id == selectedId
                val row = LinearLayout(this@WidgetQuickEntryActivity).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER_VERTICAL
                    setPadding(dp(12), dp(12), dp(12), dp(12))
                    background = shape(if (active) Color.rgb(255, 240, 231) else Color.TRANSPARENT, 15)
                }
                val label = LinearLayout(this@WidgetQuickEntryActivity).apply { orientation = LinearLayout.VERTICAL }
                label.addView(text(user.name, 15f, if (active) Color.rgb(232, 93, 22) else ink).apply {
                    setTypeface(null, if (active) Typeface.BOLD else Typeface.NORMAL)
                })
                label.addView(text(user.phone, 12f, muted).apply { setPadding(0, dp(3), 0, 0) })
                row.addView(label, LinearLayout.LayoutParams(0, -2, 1f))
                row.addView(TextView(this@WidgetQuickEntryActivity).apply {
                    text = if (active) "✓" else ""
                    textSize = 16f; gravity = Gravity.CENTER; setTextColor(Color.WHITE)
                    background = if (active) shape(orange, 30) else GradientDrawable().apply {
                        setColor(Color.TRANSPARENT); shape = GradientDrawable.OVAL; setStroke(dp(2), Color.rgb(205, 210, 220))
                    }
                }, LinearLayout.LayoutParams(dp(26), dp(26)))
                return row
            }
        }
        list = ListView(this).apply {
            adapter = rows
            divider = null
            isVerticalScrollBarEnabled = false
        }
        panel.addView(list, LinearLayout.LayoutParams(-1, dp(260)))
        list.setOnItemClickListener { _, _, position, _ ->
            selectedId = filtered[position].id
            rows.notifyDataSetChanged()
        }
        search.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                val q = s.toString().trim().lowercase(Locale.ROOT)
                filtered = users.filter { it.name.lowercase(Locale.ROOT).contains(q) || it.phone.lowercase(Locale.ROOT).contains(q) }
                rows.notifyDataSetChanged()
            }
            override fun afterTextChanged(s: Editable?) {}
        })
        panel.addView(TextView(this).apply {
            text = "Confirm"; textSize = 14f; setTypeface(null, Typeface.BOLD)
            setTextColor(Color.WHITE); gravity = Gravity.CENTER
            background = shape(orange, 16)
            setOnClickListener { saveUser() }
        }, LinearLayout.LayoutParams(-1, dp(54)).apply { topMargin = dp(12) })
        setContentView(panel)
        window.setGravity(Gravity.BOTTOM)
        window.setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT)
    }

    private fun showAddUserForm() {
        val panel = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(20), dp(20), dp(20), dp(18)); background = shape(Color.WHITE, 26) }
        panel.addView(text("Quick add user", 20f).apply { setTypeface(null, Typeface.BOLD) })
        panel.addView(text("Add a profile to your existing User Hub database", 12f, muted).apply { setPadding(0, dp(5), 0, dp(14)) })
        val name = field("Full name")
        val phone = field("Phone number")
        panel.addView(name, LinearLayout.LayoutParams(-1, dp(50)))
        panel.addView(phone, LinearLayout.LayoutParams(-1, dp(50)).apply { topMargin = dp(10) })
        panel.addView(TextView(this).apply {
            text = "Save user"; gravity = Gravity.CENTER; setTextColor(Color.WHITE); setTypeface(null, Typeface.BOLD)
            background = shape(orange, 28); setPadding(dp(20), dp(14), dp(20), dp(14))
            setOnClickListener {
                val n = name.text.toString().trim(); val p = phone.text.toString().trim()
                if (n.isBlank()) { name.error = "Enter a name"; return@setOnClickListener }
                if (p.isBlank()) { phone.error = "Enter a phone number"; return@setOnClickListener }
                val db = WidgetStore.database(this@WidgetQuickEntryActivity) ?: run { Toast.makeText(this@WidgetQuickEntryActivity, "Open User Hub once first", Toast.LENGTH_LONG).show(); return@setOnClickListener }
                try {
                    val duplicate = db.rawQuery("SELECT name FROM users WHERE phone=? UNION ALL SELECT name FROM potential_users WHERE phone=? AND status != 'Registered' LIMIT 1", arrayOf(p,p)).use { it.moveToFirst() }
                    if (duplicate) { phone.error = "This number already exists"; return@setOnClickListener }
                    val values = ContentValues().apply { put("name", n); put("phone", p); put("notes", ""); put("do_not_contact", 0); put("preferred_language", ""); put("preferred_contact_method", ""); putNull("previous_dp_at"); put("created_at", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())) }
                    val id = db.insertOrThrow("users", null, values)
                    WidgetStore.setSelectedUser(this@WidgetQuickEntryActivity, id); WidgetStore.refresh(this@WidgetQuickEntryActivity)
                    Toast.makeText(this@WidgetQuickEntryActivity, "User added", Toast.LENGTH_SHORT).show(); finish()
                } catch (_: Exception) { Toast.makeText(this@WidgetQuickEntryActivity, "Could not add user. Check the phone number.", Toast.LENGTH_LONG).show() }
                finally { db.close() }
            }
        }, LinearLayout.LayoutParams(-1, dp(48)).apply { topMargin = dp(16) })
        setContentView(panel)
        window.setLayout((resources.displayMetrics.widthPixels * .9f).toInt(), WindowManager.LayoutParams.WRAP_CONTENT)
    }

    private fun showMessage(message: String) {
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL; setPadding(dp(22), dp(22), dp(22), dp(18))
            background = shape(Color.WHITE, 24)
        }
        panel.addView(text(message, 15f))
        panel.addView(TextView(this).apply {
            text = "Close"; gravity = Gravity.CENTER; setTextColor(Color.WHITE); setTypeface(null, Typeface.BOLD)
            background = shape(orange, 28); setPadding(dp(20), dp(13), dp(20), dp(13))
            setOnClickListener { finish() }
        })
        setContentView(panel)
        window.setLayout((resources.displayMetrics.widthPixels * 0.9f).toInt(), WindowManager.LayoutParams.WRAP_CONTENT)
    }

    private fun saveUser() {
        if (users.none { it.id == selectedId }) { Toast.makeText(this, "Select a user first", Toast.LENGTH_SHORT).show(); return }
        WidgetStore.setSelectedUser(this, selectedId); WidgetStore.refresh(this); finish()
    }

    private fun saveEntry(isBonus: Boolean) {
        val value = amount.text.toString().trim().replace(",", "").toDoubleOrNull()
        if (value == null || !value.isFinite() || value <= 0.0) { amount.error = "Enter an amount greater than zero"; return }
        if (users.none { it.id == selectedId }) { Toast.makeText(this, "Select a user first", Toast.LENGTH_SHORT).show(); return }
        val db = WidgetStore.database(this)
        if (db == null) { Toast.makeText(this, "Open User Hub once before using the widget.", Toast.LENGTH_LONG).show(); finish(); return }
        try {
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val now = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())
            val values = ContentValues().apply { put("user_id", selectedId); put("entry_date", today); put("created_at", now) }
            var insertedId = -1L
            if (isBonus) {
                values.put("amount", value)
                values.put("reason", listOf("Other", "Deposit", "Special", "Promotional")[reason.selectedItemPosition])
                values.putNull("related_dp"); values.put("notes", "")
                insertedId = db.insertOrThrow("bonus_entries", null, values)
            } else {
                values.put("dp1", value); values.put("dp2", 0); values.put("dp3", 0); values.put("dp4", 0); values.put("dp5", 0)
                values.put("total", value); values.put("dp_count", 1); values.put("contacted", 0); values.put("notes", "")
                insertedId = db.insertOrThrow("dp_entries", null, values)
            }
            getSharedPreferences(WidgetStore.PREFS, MODE_PRIVATE).edit()
                .putString(WidgetStore.LAST_TABLE, if (isBonus) "bonus_entries" else "dp_entries")
                .putLong(WidgetStore.LAST_ROW, insertedId)
                .putLong(WidgetStore.UNDO_UNTIL, System.currentTimeMillis() + 8000L).apply()
            WidgetStore.setSelectedUser(this, selectedId); WidgetStore.refresh(this)
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({ WidgetStore.refresh(this) }, 8000L)
            Toast.makeText(this, if (isBonus) "Bonus saved" else "DP saved", Toast.LENGTH_SHORT).show()
            finish()
        } catch (_: Exception) {
            Toast.makeText(this, "Could not save. Open User Hub and try again.", Toast.LENGTH_LONG).show()
        } finally { db.close() }
    }
}
'''.replace("__PACKAGE__", package);

layout = r'''<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android" android:layout_width="match_parent" android:layout_height="match_parent" android:orientation="vertical" android:padding="8dp" android:background="@drawable/widget_user_hub_background">
 <LinearLayout android:layout_width="match_parent" android:layout_height="30dp" android:gravity="center_vertical">
  <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:orientation="horizontal">
   <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="User" android:textColor="@color/widget_text_primary" android:textStyle="bold" android:textSize="16sp"/>
   <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Hub" android:textColor="#FFFF8745" android:textStyle="bold" android:textSize="16sp"/>
  </LinearLayout>
  <TextView android:id="@+id/widget_status" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Today" android:textColor="@color/widget_text_secondary" android:textSize="10sp"/>
  <TextView android:id="@+id/widget_refresh" android:layout_width="36dp" android:layout_height="30dp" android:gravity="center" android:text="↻" android:textSize="16sp" android:textColor="@color/widget_text_secondary"/>
 </LinearLayout>
 <FrameLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1"/>
 <LinearLayout android:layout_width="match_parent" android:layout_height="50dp" android:orientation="horizontal" android:gravity="center_vertical">
  <FrameLayout android:layout_width="48dp" android:layout_height="48dp">
   <ProgressBar android:id="@+id/widget_goal_ring" style="?android:attr/progressBarStyleHorizontal" android:layout_width="match_parent" android:layout_height="match_parent" android:indeterminate="false" android:max="100" android:progress="0" android:progressDrawable="@drawable/widget_ring_progress" android:rotation="-90"/>
   <TextView android:id="@+id/widget_goal_ring_text" android:layout_width="match_parent" android:layout_height="match_parent" android:gravity="center" android:text="0" android:textColor="@color/widget_text_primary" android:textStyle="bold" android:textSize="13sp"/>
  </FrameLayout>
  <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:orientation="vertical" android:paddingStart="6dp">
   <TextView android:id="@+id/widget_goal_text" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="DP today · goal 20" android:textColor="@color/widget_text_secondary" android:textSize="10sp"/>
   <TextView android:id="@+id/widget_dp_total" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="0 coins" android:textColor="@color/widget_text_primary" android:textSize="16sp" android:textStyle="bold"/>
  </LinearLayout>
  <LinearLayout android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1" android:orientation="vertical" android:paddingStart="4dp">
   <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Bonus today" android:textColor="@color/widget_text_secondary" android:textSize="10sp"/>
   <TextView android:id="@+id/widget_bonus_total" android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="0 coins" android:textColor="#FF60A5FA" android:textSize="16sp" android:textStyle="bold"/>
  </LinearLayout>
 </LinearLayout>
 <FrameLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1"/>
 <LinearLayout android:layout_width="match_parent" android:layout_height="42dp" android:orientation="horizontal" android:background="@drawable/widget_metric_background" android:padding="2dp">
  <TextView android:id="@+id/widget_mode_dp" android:layout_width="0dp" android:layout_height="match_parent" android:layout_weight="1" android:gravity="center" android:text="DP" android:textSize="12sp" android:textColor="#FFFFFFFF" android:textStyle="bold" android:background="@drawable/widget_dp_button"/>
  <TextView android:id="@+id/widget_mode_bonus" android:layout_width="0dp" android:layout_height="match_parent" android:layout_weight="1" android:gravity="center" android:text="Bonus" android:textSize="12sp" android:textColor="@color/widget_text_secondary" android:textStyle="bold"/>
 </LinearLayout>
 <FrameLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1"/>
 <LinearLayout android:layout_width="match_parent" android:layout_height="68dp" android:gravity="center_vertical" android:orientation="horizontal">
  <FrameLayout android:layout_width="0dp" android:layout_height="68dp" android:layout_weight="1">
   <TextView android:id="@+id/widget_recent_avatar_1" android:layout_width="48dp" android:layout_height="48dp" android:layout_gravity="center_horizontal" android:gravity="center" android:text="A" android:textColor="@color/widget_text_primary" android:textSize="15sp" android:background="@drawable/widget_avatar_selected"/>
   <TextView android:id="@+id/widget_recent_badge_1" android:layout_width="16dp" android:layout_height="16dp" android:layout_gravity="top|right" android:gravity="center" android:text="2" android:textColor="#FF111B30" android:textSize="9sp" android:textStyle="bold" android:background="@drawable/widget_badge"/>
   <TextView android:id="@+id/widget_recent_name_1" android:layout_width="match_parent" android:layout_height="16dp" android:layout_gravity="bottom" android:gravity="center" android:text="User" android:textColor="@color/widget_text_primary" android:textSize="9sp" android:singleLine="true" android:ellipsize="end"/>
  </FrameLayout>
  <FrameLayout android:layout_width="0dp" android:layout_height="68dp" android:layout_weight="1">
   <TextView android:id="@+id/widget_recent_avatar_2" android:layout_width="48dp" android:layout_height="48dp" android:layout_gravity="center_horizontal" android:gravity="center" android:text="M" android:textColor="@color/widget_text_primary" android:textSize="15sp" android:background="@drawable/widget_avatar"/>
   <TextView android:id="@+id/widget_recent_badge_2" android:layout_width="16dp" android:layout_height="16dp" android:layout_gravity="top|right" android:gravity="center" android:text="1" android:textColor="#FF111B30" android:textSize="9sp" android:textStyle="bold" android:background="@drawable/widget_badge"/>
   <TextView android:id="@+id/widget_recent_name_2" android:layout_width="match_parent" android:layout_height="12dp" android:layout_gravity="bottom" android:gravity="center" android:text="User" android:textColor="@color/widget_text_secondary" android:textSize="9sp" android:singleLine="true" android:ellipsize="end"/>
  </FrameLayout>
  <FrameLayout android:layout_width="0dp" android:layout_height="68dp" android:layout_weight="1">
   <TextView android:id="@+id/widget_recent_avatar_3" android:layout_width="48dp" android:layout_height="48dp" android:layout_gravity="center_horizontal" android:gravity="center" android:text="A" android:textColor="@color/widget_text_primary" android:textSize="15sp" android:background="@drawable/widget_avatar"/>
   <TextView android:id="@+id/widget_recent_badge_3" android:layout_width="16dp" android:layout_height="16dp" android:layout_gravity="top|right" android:gravity="center" android:text="1" android:textColor="#FF111B30" android:textSize="9sp" android:textStyle="bold" android:background="@drawable/widget_badge"/>
   <TextView android:id="@+id/widget_recent_name_3" android:layout_width="match_parent" android:layout_height="12dp" android:layout_gravity="bottom" android:gravity="center" android:text="User" android:textColor="@color/widget_text_secondary" android:textSize="9sp" android:singleLine="true" android:ellipsize="end"/>
  </FrameLayout>
  <FrameLayout android:layout_width="0dp" android:layout_height="68dp" android:layout_weight="1">
   <TextView android:id="@+id/widget_quick_add_user" android:layout_width="48dp" android:layout_height="48dp" android:layout_gravity="center_horizontal" android:gravity="center" android:text="+" android:textColor="@color/widget_text_secondary" android:textSize="20sp" android:background="@drawable/widget_add_user_outline"/>
   <TextView android:layout_width="match_parent" android:layout_height="12dp" android:layout_gravity="bottom" android:gravity="center" android:text="User" android:textColor="@color/widget_text_secondary" android:textSize="9sp"/>
  </FrameLayout>
 </LinearLayout>
 <FrameLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1"/>
 <TextView android:id="@+id/widget_selected_detail" android:layout_width="match_parent" android:layout_height="20dp" android:gravity="center" android:text="For selected user · last DP 5 coins · 2h ago" android:textColor="@color/widget_text_secondary" android:textSize="9sp" android:singleLine="true" android:ellipsize="end"/>
 <FrameLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1"/>
 <LinearLayout android:layout_width="match_parent" android:layout_height="48dp" android:gravity="center_vertical" android:orientation="horizontal">
  <TextView android:id="@+id/widget_minus" android:layout_width="48dp" android:layout_height="48dp" android:gravity="center" android:text="−" android:textColor="@color/widget_text_primary" android:textSize="20sp" android:background="@drawable/widget_metric_background"/>
  <LinearLayout android:id="@+id/widget_amount_group" android:layout_width="0dp" android:layout_height="32dp" android:layout_weight="1" android:gravity="center" android:orientation="horizontal">
   <TextView android:id="@+id/widget_amount" android:layout_width="wrap_content" android:layout_height="match_parent" android:gravity="center" android:text="5" android:textColor="@color/widget_text_primary" android:textSize="30sp" android:textStyle="bold"/>
   <TextView android:id="@+id/widget_amount_unit" android:layout_width="wrap_content" android:layout_height="match_parent" android:gravity="center_vertical" android:paddingStart="4dp" android:text="coins" android:textColor="@color/widget_text_secondary" android:textSize="11sp"/>
  </LinearLayout>
  <TextView android:id="@+id/widget_plus" android:layout_width="48dp" android:layout_height="48dp" android:gravity="center" android:text="+" android:textColor="@color/widget_text_primary" android:textSize="20sp" android:background="@drawable/widget_metric_background"/>
 </LinearLayout>
 <FrameLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1"/>
 <LinearLayout android:layout_width="match_parent" android:layout_height="50dp" android:orientation="horizontal">
  <TextView android:id="@+id/widget_preset_1" android:layout_width="0dp" android:layout_height="match_parent" android:layout_weight="1" android:gravity="center" android:text="1" android:textSize="11sp" android:textColor="@color/widget_text_primary" android:background="@drawable/widget_metric_background"/>
  <TextView android:id="@+id/widget_preset_5" android:layout_width="0dp" android:layout_height="match_parent" android:layout_weight="1" android:layout_marginStart="4dp" android:gravity="center" android:text="5" android:textSize="11sp" android:textColor="@color/widget_text_primary" android:background="@drawable/widget_metric_background"/>
  <TextView android:id="@+id/widget_preset_10" android:layout_width="0dp" android:layout_height="match_parent" android:layout_weight="1" android:layout_marginStart="4dp" android:gravity="center" android:text="10" android:textSize="11sp" android:textColor="@color/widget_text_primary" android:background="@drawable/widget_metric_background"/>
  <TextView android:id="@+id/widget_preset_25" android:layout_width="0dp" android:layout_height="match_parent" android:layout_weight="1" android:layout_marginStart="4dp" android:gravity="center" android:text="25" android:textSize="11sp" android:textColor="@color/widget_text_primary" android:background="@drawable/widget_metric_background"/>
 </LinearLayout>
 <FrameLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1"/>
 <LinearLayout android:layout_width="match_parent" android:layout_height="50dp" android:orientation="horizontal" android:padding="2dp">
  <TextView android:id="@+id/widget_add" android:layout_width="0dp" android:layout_weight="1" android:layout_height="match_parent" android:layout_margin="2dp" android:gravity="center" android:text="+ Add DP · 5 coins" android:textColor="#FFFFFFFF" android:textStyle="bold" android:textSize="13sp" android:background="@drawable/widget_dp_button"/>
  <TextView android:id="@+id/widget_undo" android:layout_width="110dp" android:layout_height="match_parent" android:layout_marginStart="4dp" android:layout_marginTop="2dp" android:layout_marginBottom="2dp" android:gravity="center" android:text="Undo · 8s" android:textColor="#FFFFFFFF" android:textStyle="bold" android:textSize="11sp" android:background="@drawable/widget_bonus_button" android:visibility="gone"/>
 </LinearLayout>
</LinearLayout>
'''

installer_resources = {
    "layout/widget_user_hub.xml": layout,
    "xml/user_hub_widget_info.xml": r'''<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp" android:minHeight="350dp"
    android:minResizeWidth="250dp" android:minResizeHeight="350dp"
    android:targetCellWidth="4" android:targetCellHeight="5"
    android:updatePeriodMillis="0" android:initialLayout="@layout/widget_user_hub"
    android:resizeMode="horizontal|vertical" android:widgetCategory="home_screen"
    android:description="@string/user_hub_widget_description" />
''',
    "drawable/widget_user_hub_background.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android"><solid android:color="@color/widget_background"/><corners android:radius="28dp"/></shape>''',
    "drawable/widget_metric_background.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android"><solid android:color="@color/widget_surface"/><corners android:radius="10dp"/></shape>''',
    "drawable/widget_dp_button.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android"><solid android:color="#DE5010"/><corners android:radius="8dp"/></shape>''',
    "drawable/widget_bonus_button.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android"><solid android:color="#2563EB"/><corners android:radius="8dp"/></shape>''',
    "drawable/widget_success_button.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android"><solid android:color="#15803D"/><corners android:radius="8dp"/></shape>''',
    "drawable/widget_ring_progress.xml": r'''<layer-list xmlns:android="http://schemas.android.com/apk/res/android"><item android:id="@android:id/background"><shape android:shape="ring" android:innerRadiusRatio="3" android:thickness="5dp" android:useLevel="false"><solid android:color="#FF25324A"/></shape></item><item android:id="@android:id/progress"><shape android:shape="ring" android:innerRadiusRatio="3" android:thickness="5dp" android:useLevel="true"><solid android:color="#FFFF8A4C"/></shape></item></layer-list>''',
    "drawable/widget_avatar.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#FF25324A"/></shape>''',
    "drawable/widget_avatar_selected.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#FF25324A"/><stroke android:width="2dp" android:color="#FFFF8A4C"/></shape>''',
    "drawable/widget_badge.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#FFFFFFFF"/></shape>''',
    "drawable/widget_add_user_outline.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#00111B30"/><stroke android:width="1dp" android:color="#FF8994A8" android:dashWidth="3dp" android:dashGap="2dp"/></shape>''',
    "drawable/widget_success_button.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android"><solid android:color="#15803D"/><corners android:radius="8dp"/></shape>''',
    "drawable/widget_ring_progress.xml": r'''<layer-list xmlns:android="http://schemas.android.com/apk/res/android"><item android:id="@android:id/background"><shape android:shape="ring" android:innerRadiusRatio="3" android:thickness="5dp" android:useLevel="false"><solid android:color="#FF293650"/></shape></item><item android:id="@android:id/progress"><clip android:clipOrientation="horizontal" android:gravity="center"><shape android:shape="ring" android:innerRadiusRatio="3" android:thickness="5dp" android:useLevel="true"><solid android:color="#FFF36B21"/></shape></clip></item></layer-list>''',
    "drawable/widget_avatar.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#FF202D46"/></shape>''',
    "drawable/widget_avatar_selected.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#FF263550"/><stroke android:width="2dp" android:color="#FFF36B21"/></shape>''',
    "drawable/widget_badge.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#FFFFFFFF"/></shape>''',
    "drawable/widget_add_user_outline.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="oval"><solid android:color="#00111B30"/><stroke android:width="1dp" android:color="#FF8994A8" android:dashWidth="3dp" android:dashGap="2dp"/></shape>''',
    "values/widget_strings.xml": r'''<resources><string name="user_hub_widget_description">Quick DP and bonus entry</string></resources>''',
    "values/widget_colors.xml": r'''<resources>
<color name="widget_background">#FF111B2D</color><color name="widget_surface">#FF1A2538</color>
<color name="widget_text_primary">#FFFFFFFF</color><color name="widget_text_secondary">#FFA3ACBF</color>
<color name="widget_dp_accent">#FFDE5010</color><color name="widget_bonus_accent">#FF60A5FA</color>
</resources>''',
    "values-night/widget_colors.xml": r'''<resources>
<color name="widget_background">#FF111B2D</color><color name="widget_surface">#FF1A2538</color>
<color name="widget_text_primary">#FFFFFFFF</color><color name="widget_text_secondary">#FFA3ACBF</color>
<color name="widget_dp_accent">#FFDE5010</color><color name="widget_bonus_accent">#FF60A5FA</color>
</resources>''',
}
src = base / "kotlin" / package_path / "widget"
src.mkdir(parents=True, exist_ok=True)
(src / "UserHubWidgetProviderV2.kt").write_text(provider)
(src / "WidgetQuickEntryActivity.kt").write_text(activity)
for relative, content in installer_resources.items():
    path = base / "res" / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)

manifest = base / "AndroidManifest.xml"
tree = ET.parse(manifest)
app = tree.getroot().find("application")
if app is None:
    raise SystemExit("Android application element missing")
receiver_name = package + ".widget.UserHubWidgetProviderV2"
activity_name = package + ".widget.WidgetQuickEntryActivity"
# Retire the previous compact provider so the launcher cannot keep offering its 4x2 definition.
for node in list(app):
    if node.tag == "receiver" and node.get(A + "name") in {
        package + ".widget.UserHubWidgetProvider",
        receiver_name,
    }:
        app.remove(node)
receiver = ET.SubElement(app, "receiver", {A+"name": receiver_name, A+"exported": "true", A+"label": "User Hub"})
filt = ET.SubElement(receiver, "intent-filter")
ET.SubElement(filt, "action", {A+"name": "android.appwidget.action.APPWIDGET_UPDATE"})
ET.SubElement(receiver, "meta-data", {A+"name": "android.appwidget.provider", A+"resource": "@xml/user_hub_widget_info"})
if not any(n.tag == "activity" and n.get(A + "name") == activity_name for n in app):
    ET.SubElement(app, "activity", {
        A+"name": activity_name, A+"exported": "false",
        A+"excludeFromRecents": "true", A+"theme": "@android:style/Theme.Material.Light.Dialog.Alert",
        A+"windowSoftInputMode": "adjustResize"
    })
tree.write(manifest, encoding="utf-8", xml_declaration=True)
print("Installed full PDF Design B UserHub home-screen widget for " + package)