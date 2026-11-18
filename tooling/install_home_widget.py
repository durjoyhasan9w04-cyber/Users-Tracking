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
        val ids = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(RECENT_USERS, "")!!.split(",").mapNotNull { it.toLongOrNull() }
        val all = users(context).associateBy { it.id }
        return ids.mapNotNull { all[it] }.take(3)
    }

    fun refresh(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, UserHubWidgetProvider::class.java))
        if (ids.isNotEmpty()) UserHubWidgetProvider().onUpdate(context, manager, ids)
    }

    fun money(value: Double): String {
        val whole = value % 1.0 == 0.0
        return if (whole) String.format(Locale.US, "%,.0f", value) else String.format(Locale.US, "%,.2f", value)
    }
}

class UserHubWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id -> manager.updateAppWidget(id, views(context)) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == WidgetStore.ACTION_REFRESH) WidgetStore.refresh(context)
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
        views.setTextViewText(R.id.widget_user_name, name)
        views.setTextViewText(R.id.widget_status, if (users.isEmpty()) "Add a user in User Hub" else "Today")

        fun activityIntent(action: String, request: Int): PendingIntent {
            val i = Intent(context, WidgetQuickEntryActivity::class.java).setAction(action)
            return PendingIntent.getActivity(context, request, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        views.setOnClickPendingIntent(R.id.widget_add_dp, activityIntent(WidgetStore.ACTION_ADD_DP, 11))
        views.setOnClickPendingIntent(R.id.widget_add_bonus, activityIntent(WidgetStore.ACTION_ADD_BONUS, 12))
        views.setOnClickPendingIntent(R.id.widget_user_name, activityIntent(WidgetStore.ACTION_SELECT, 13))
        views.setOnClickPendingIntent(R.id.widget_quick_add_user, activityIntent(WidgetStore.ACTION_ADD_USER, 15))
        val recent = WidgetStore.recentUsers(context)
        val recentIds = intArrayOf(R.id.widget_recent_1, R.id.widget_recent_2, R.id.widget_recent_3)
        recentIds.forEachIndexed { index, viewId ->
            val user = recent.getOrNull(index)
            views.setTextViewText(viewId, if (user == null) "—" else (if (user.id == userId) "✓ " else "") + user.name.take(9))
            views.setViewVisibility(viewId, if (user == null) android.view.View.GONE else android.view.View.VISIBLE)
            if (user != null) {
                val pick = Intent(context, WidgetQuickEntryActivity::class.java).setAction(WidgetStore.ACTION_SELECT).putExtra("selected_user_id", user.id)
                views.setOnClickPendingIntent(viewId, PendingIntent.getActivity(context, 30 + index, pick, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            }
        }
        val refresh = Intent(context, UserHubWidgetProvider::class.java).setAction(WidgetStore.ACTION_REFRESH)
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
        selectedId = WidgetStore.selectedUserId(this)
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.setDimAmount(0.58f)
        if (action == WidgetStore.ACTION_ADD_USER || users.isEmpty()) { showAddUserForm(); return }
        intent.getLongExtra("selected_user_id", -1L).takeIf { it > 0 }?.let { selectedId = it }
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

    private fun buildForm() {
        val selectOnly = action == WidgetStore.ACTION_SELECT
        val isBonus = action == WidgetStore.ACTION_ADD_BONUS
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
        adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, users.map { it.name + "  ·  " + it.phone })
        list = ListView(this).apply {
            this.adapter = this@WidgetQuickEntryActivity.adapter
            divider = android.graphics.drawable.ColorDrawable(border); dividerHeight = dp(1)
            background = shape(Color.rgb(244, 245, 247), 14)
            setPadding(dp(5), dp(3), dp(5), dp(3))
        }
        panel.addView(list, LinearLayout.LayoutParams(-1, dp(if (selectOnly) 190 else 128)))
        list.setOnItemClickListener { _, _, position, _ ->
            selectedId = filtered[position].id
            search.setText(filtered[position].name)
            search.setSelection(search.text.length)
        }
        search.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                val q = s.toString().trim().lowercase(Locale.ROOT)
                filtered = users.filter { it.name.lowercase(Locale.ROOT).contains(q) || it.phone.lowercase(Locale.ROOT).contains(q) }
                adapter.clear()
                adapter.addAll(filtered.map { it.name + "  ·  " + it.phone })
                list.visibility = if (filtered.isEmpty()) android.view.View.GONE else android.view.View.VISIBLE
            }
            override fun afterTextChanged(s: Editable?) {}
        })

        if (!selectOnly) {
            panel.addView(text("Amount (coins)", 12f, muted).apply { setPadding(0, dp(13), 0, dp(5)) })
            amount = field("Enter amount", true)
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
            if (isBonus) {
                values.put("amount", value)
                values.put("reason", listOf("Other", "Deposit", "Special", "Promotional")[reason.selectedItemPosition])
                values.putNull("related_dp"); values.put("notes", "")
                db.insertOrThrow("bonus_entries", null, values)
            } else {
                values.put("dp1", value); values.put("dp2", 0); values.put("dp3", 0); values.put("dp4", 0); values.put("dp5", 0)
                values.put("total", value); values.put("dp_count", 1); values.put("contacted", 0); values.put("notes", "")
                db.insertOrThrow("dp_entries", null, values)
            }
            WidgetStore.setSelectedUser(this, selectedId); WidgetStore.refresh(this)
            Toast.makeText(this, if (isBonus) "Bonus saved" else "DP saved", Toast.LENGTH_SHORT).show()
            finish()
        } catch (_: Exception) {
            Toast.makeText(this, "Could not save. Open User Hub and try again.", Toast.LENGTH_LONG).show()
        } finally { db.close() }
    }
}
'''.replace("__PACKAGE__", package);

layout = r'''<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent" android:layout_height="match_parent"
    android:orientation="vertical" android:padding="10dp"
    android:background="@drawable/widget_user_hub_background">
    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content"
        android:gravity="center_vertical" android:orientation="horizontal">
        <TextView android:layout_width="0dp" android:layout_height="wrap_content" android:layout_weight="1"
            android:text="UserHub" android:textColor="@color/widget_text_primary" android:textStyle="bold" android:textSize="14sp"/>
        <TextView android:id="@+id/widget_status" android:layout_width="wrap_content" android:layout_height="wrap_content"
            android:text="Today" android:textColor="@color/widget_text_secondary" android:textSize="10sp"/>
        <TextView android:id="@+id/widget_refresh" android:layout_width="28dp" android:layout_height="28dp"
            android:gravity="center" android:text="↻" android:textSize="19sp" android:textColor="@color/widget_text_secondary"/>
    </LinearLayout>
    <LinearLayout android:layout_width="match_parent" android:layout_height="0dp" android:layout_weight="1"
        android:orientation="horizontal" android:paddingTop="5dp">
        <LinearLayout android:layout_width="0dp" android:layout_height="match_parent" android:layout_weight="1"
            android:orientation="vertical" android:padding="7dp" android:layout_marginEnd="7dp" android:background="@drawable/widget_metric_background">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="DP TODAY"
                android:textColor="@color/widget_text_secondary" android:textSize="9sp" android:textStyle="bold"/>
            <TextView android:id="@+id/widget_dp_total" android:layout_width="match_parent" android:layout_height="wrap_content"
                android:text="0 coins" android:textColor="@color/widget_dp_accent" android:textSize="18sp" android:textStyle="bold" android:maxLines="1"/>
        </LinearLayout>
        <LinearLayout android:layout_width="0dp" android:layout_height="match_parent" android:layout_weight="1"
            android:orientation="vertical" android:padding="7dp" android:background="@drawable/widget_metric_background">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="BONUS TODAY"
                android:textColor="@color/widget_text_secondary" android:textSize="9sp" android:textStyle="bold"/>
            <TextView android:id="@+id/widget_bonus_total" android:layout_width="match_parent" android:layout_height="wrap_content"
                android:text="৳0" android:textColor="@color/widget_bonus_accent" android:textSize="18sp" android:textStyle="bold" android:maxLines="1"/>
        </LinearLayout>
    </LinearLayout>
    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:gravity="center_vertical"
        android:orientation="horizontal" android:paddingTop="5dp">
        <TextView android:id="@+id/widget_user_name" android:layout_width="0dp" android:layout_height="wrap_content"
            android:layout_weight="1" android:text="Select user" android:textColor="@color/widget_text_primary"
            android:textSize="11sp" android:textStyle="bold" android:maxLines="1"/>
        <TextView android:id="@+id/widget_add_dp" android:layout_width="wrap_content" android:layout_height="30dp"
            android:gravity="center" android:paddingLeft="9dp" android:paddingRight="9dp" android:layout_marginEnd="5dp" android:text="+ Add DP"
            android:textColor="#FFFFFFFF" android:textSize="10sp" android:textStyle="bold" android:background="@drawable/widget_dp_button"/>
        <TextView android:id="@+id/widget_add_bonus" android:layout_width="wrap_content" android:layout_height="30dp"
            android:gravity="center" android:paddingLeft="9dp" android:paddingRight="9dp" android:text="+ Bonus"
            android:textColor="#FFFFFFFF" android:textSize="10sp" android:textStyle="bold" android:background="@drawable/widget_bonus_button"/>
    </LinearLayout>
    <LinearLayout android:layout_width="match_parent" android:layout_height="wrap_content" android:gravity="center_vertical" android:orientation="horizontal" android:paddingTop="3dp">
        <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="Recent" android:textSize="9sp" android:textColor="@color/widget_text_secondary" android:layout_marginEnd="5dp"/>
        <TextView android:id="@+id/widget_recent_1" android:layout_width="0dp" android:layout_height="24dp" android:layout_weight="1" android:gravity="center" android:textSize="9sp" android:textColor="@color/widget_text_primary" android:background="@drawable/widget_metric_background" android:maxLines="1"/>
        <TextView android:id="@+id/widget_recent_2" android:layout_width="0dp" android:layout_height="24dp" android:layout_weight="1" android:layout_marginStart="4dp" android:gravity="center" android:textSize="9sp" android:textColor="@color/widget_text_primary" android:background="@drawable/widget_metric_background" android:maxLines="1"/>
        <TextView android:id="@+id/widget_recent_3" android:layout_width="0dp" android:layout_height="24dp" android:layout_weight="1" android:layout_marginStart="4dp" android:gravity="center" android:textSize="9sp" android:textColor="@color/widget_text_primary" android:background="@drawable/widget_metric_background" android:maxLines="1"/>
        <TextView android:id="@+id/widget_quick_add_user" android:layout_width="wrap_content" android:layout_height="24dp" android:layout_marginStart="5dp" android:gravity="center" android:text="+ User" android:textSize="9sp" android:textStyle="bold" android:textColor="#FFFFFFFF" android:paddingLeft="7dp" android:paddingRight="7dp" android:background="@drawable/widget_dp_button"/>
    </LinearLayout>
</LinearLayout>
'''

installer_resources = {
    "layout/widget_user_hub.xml": layout,
    "xml/user_hub_widget_info.xml": r'''<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp" android:minHeight="110dp"
    android:targetCellWidth="4" android:targetCellHeight="2"
    android:updatePeriodMillis="0" android:initialLayout="@layout/widget_user_hub"
    android:resizeMode="horizontal|vertical" android:widgetCategory="home_screen"
    android:description="@string/user_hub_widget_description" />
''',
    "drawable/widget_user_hub_background.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android"><solid android:color="@color/widget_background"/><corners android:radius="16dp"/></shape>''',
    "drawable/widget_metric_background.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android"><solid android:color="@color/widget_surface"/><corners android:radius="10dp"/></shape>''',
    "drawable/widget_dp_button.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android"><solid android:color="#F36B21"/><corners android:radius="8dp"/></shape>''',
    "drawable/widget_bonus_button.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android"><solid android:color="#F08A36"/><corners android:radius="8dp"/></shape>''',
    "values/widget_strings.xml": r'''<resources><string name="user_hub_widget_description">Quick DP and bonus entry</string></resources>''',
    "values/widget_colors.xml": r'''<resources>
<color name="widget_background">#FFF4F5F7</color><color name="widget_surface">#FFFFFFFF</color>
<color name="widget_text_primary">#FF18202B</color><color name="widget_text_secondary">#FF7C8490</color>
<color name="widget_dp_accent">#FFF36B21</color><color name="widget_bonus_accent">#FFF08A36</color>
</resources>''',
    "values-night/widget_colors.xml": r'''<resources>
<color name="widget_background">#FFF4F5F7</color><color name="widget_surface">#FFFFFFFF</color>
<color name="widget_text_primary">#FF18202B</color><color name="widget_text_secondary">#FF7C8490</color>
<color name="widget_dp_accent">#FFF36B21</color><color name="widget_bonus_accent">#FFF08A36</color>
</resources>''',
}
src = base / "kotlin" / package_path / "widget"
src.mkdir(parents=True, exist_ok=True)
(src / "UserHubWidgetProvider.kt").write_text(provider)
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
receiver_name = package + ".widget.UserHubWidgetProvider"
activity_name = package + ".widget.WidgetQuickEntryActivity"
if not any(n.tag == "receiver" and n.get(A + "name") == receiver_name for n in app):
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
print("Installed compact 4x2 User Hub home-screen widget for " + package)
