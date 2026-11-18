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

    fun database(context: Context): SQLiteDatabase? {
        val file = context.getDatabasePath("user_hub.db")
        if (!file.exists()) return null
        return try { SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE) }
        catch (_: Exception) { null }
    }

    fun users(context: Context): List<Pair<Long, String>> {
        val db = database(context) ?: return emptyList()
        return try {
            db.rawQuery("SELECT id, name FROM users WHERE archived = 0 ORDER BY name COLLATE NOCASE", null).use { c ->
                buildList { while (c.moveToNext()) add(c.getLong(0) to c.getString(1)) }
            }
        } catch (_: Exception) { emptyList() } finally { db.close() }
    }

    fun selectedUserId(context: Context): Long {
        val saved = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong(SELECTED_USER, -1L)
        val available = users(context)
        return if (available.any { it.first == saved }) saved else available.firstOrNull()?.first ?: -1L
    }

    fun setSelectedUser(context: Context, id: Long) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong(SELECTED_USER, id).apply()
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
        views.setTextViewText(R.id.widget_dp_total, "৳" + WidgetStore.money(dp))
        views.setTextViewText(R.id.widget_bonus_total, "৳" + WidgetStore.money(bonus))
        views.setTextViewText(R.id.widget_user_name, name)
        views.setTextViewText(R.id.widget_status, if (users.isEmpty()) "Add a user in User Hub" else "Today")

        fun activityIntent(action: String, request: Int): PendingIntent {
            val i = Intent(context, WidgetQuickEntryActivity::class.java).setAction(action)
            return PendingIntent.getActivity(context, request, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        views.setOnClickPendingIntent(R.id.widget_add_dp, activityIntent(WidgetStore.ACTION_ADD_DP, 11))
        views.setOnClickPendingIntent(R.id.widget_add_bonus, activityIntent(WidgetStore.ACTION_ADD_BONUS, 12))
        views.setOnClickPendingIntent(R.id.widget_user_name, activityIntent(WidgetStore.ACTION_SELECT, 13))
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
import android.database.sqlite.SQLiteDatabase
import android.graphics.Color
import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.view.Window
import android.view.WindowManager
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class WidgetQuickEntryActivity : Activity() {
    private var action = WidgetStore.ACTION_ADD_DP
    private var users = emptyList<Pair<Long, String>>()
    private lateinit var userSpinner: Spinner
    private lateinit var amount: EditText
    private lateinit var reasonSpinner: Spinner

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        action = intent.action ?: WidgetStore.ACTION_ADD_DP
        users = WidgetStore.users(this)
        window.requestFeature(Window.FEATURE_NO_TITLE)
        window.setBackgroundDrawableResource(android.R.color.transparent)
        window.setLayout(WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.WRAP_CONTENT)
        if (users.isEmpty()) {
            showMessage("No users found. Open User Hub and add a user first.")
            return
        }
        buildForm()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
    private fun label(text: String, size: Float = 14f): TextView = TextView(this).apply {
        this.text = text; textSize = size; setTextColor(Color.rgb(31, 41, 55))
    }
    private fun buildForm() {
        val isSelect = action == WidgetStore.ACTION_SELECT
        val isBonus = action == WidgetStore.ACTION_ADD_BONUS
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(18), dp(22), dp(18))
            setBackgroundColor(Color.WHITE)
        }
        panel.addView(label(if (isSelect) "Choose user" else if (isBonus) "Add bonus" else "Add DP", 19f).apply { setTypeface(null, Typeface.BOLD) })
        panel.addView(label("User", 12f).apply { setPadding(0, dp(14), 0, dp(5)) })
        userSpinner = Spinner(this)
        val names = users.map { it.second }
        userSpinner.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, names)
        val selected = WidgetStore.selectedUserId(this)
        userSpinner.setSelection(users.indexOfFirst { it.first == selected }.coerceAtLeast(0))
        panel.addView(userSpinner, LinearLayout.LayoutParams(-1, dp(48)))

        if (!isSelect) {
            panel.addView(label("Amount (৳)", 12f).apply { setPadding(0, dp(12), 0, dp(5)) })
            amount = EditText(this).apply {
                hint = "Enter amount"; inputType = 8194
                textSize = 18f; setSingleLine(true)
            }
            panel.addView(amount, LinearLayout.LayoutParams(-1, dp(52)))
            if (isBonus) {
                panel.addView(label("Reason", 12f).apply { setPadding(0, dp(10), 0, dp(4)) })
                reasonSpinner = Spinner(this)
                reasonSpinner.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, listOf("Other", "Deposit", "Special", "Promotional"))
                panel.addView(reasonSpinner, LinearLayout.LayoutParams(-1, dp(44)))
            }
        }
        val buttons = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.END; setPadding(0, dp(16), 0, 0) }
        val cancel = Button(this).apply { text = "Cancel"; setOnClickListener { finish() } }
        val save = Button(this).apply {
            text = if (isSelect) "Use this user" else "Save"
            setOnClickListener { if (isSelect) saveUser() else saveEntry(isBonus) }
        }
        buttons.addView(cancel)
        buttons.addView(save)
        panel.addView(buttons)
        setContentView(panel)
        window.setLayout(dp(330), WindowManager.LayoutParams.WRAP_CONTENT)
    }

    private fun showMessage(message: String) {
        val panel = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding(dp(22), dp(20), dp(22), dp(18)); setBackgroundColor(Color.WHITE) }
        panel.addView(label(message))
        panel.addView(Button(this).apply { text = "Close"; setOnClickListener { finish() } })
        setContentView(panel)
        window.setLayout(dp(330), WindowManager.LayoutParams.WRAP_CONTENT)
    }

    private fun saveUser() {
        WidgetStore.setSelectedUser(this, users[userSpinner.selectedItemPosition].first)
        WidgetStore.refresh(this)
        finish()
    }

    private fun saveEntry(isBonus: Boolean) {
        val value = amount.text.toString().trim().replace(",", "").toDoubleOrNull()
        if (value == null || !value.isFinite() || value <= 0.0) {
            amount.error = "Enter an amount greater than zero"; return
        }
        val userId = users[userSpinner.selectedItemPosition].first
        val db = WidgetStore.database(this)
        if (db == null) {
            Toast.makeText(this, "Open User Hub once before using the widget.", Toast.LENGTH_LONG).show()
            finish(); return
        }
        try {
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val now = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date())
            val values = ContentValues().apply {
                put("user_id", userId); put("entry_date", today); put("created_at", now)
            }
            if (isBonus) {
                values.put("amount", value)
                values.put("reason", listOf("Other", "Deposit", "Special", "Promotional")[reasonSpinner.selectedItemPosition])
                values.putNull("related_dp"); values.put("notes", "")
                db.insertOrThrow("bonus_entries", null, values)
            } else {
                values.put("dp1", value); values.put("dp2", 0); values.put("dp3", 0); values.put("dp4", 0); values.put("dp5", 0)
                values.put("total", value); values.put("dp_count", 1); values.put("contacted", 0); values.put("notes", "")
                db.insertOrThrow("dp_entries", null, values)
            }
            WidgetStore.setSelectedUser(this, userId)
            WidgetStore.refresh(this)
            Toast.makeText(this, if (isBonus) "Bonus saved" else "DP saved", Toast.LENGTH_SHORT).show()
            finish()
        } catch (_: Exception) {
            Toast.makeText(this, "Could not save. Open User Hub and try again.", Toast.LENGTH_LONG).show()
        } finally { db.close() }
    }
}
'''.replace("__PACKAGE__", package)

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
            android:orientation="vertical" android:padding="7dp" android:background="@drawable/widget_metric_background">
            <TextView android:layout_width="wrap_content" android:layout_height="wrap_content" android:text="DP TODAY"
                android:textColor="@color/widget_text_secondary" android:textSize="9sp" android:textStyle="bold"/>
            <TextView android:id="@+id/widget_dp_total" android:layout_width="match_parent" android:layout_height="wrap_content"
                android:text="৳0" android:textColor="@color/widget_dp_accent" android:textSize="18sp" android:textStyle="bold" android:maxLines="1"/>
        </LinearLayout>
        <View android:layout_width="7dp" android:layout_height="1dp"/>
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
            android:gravity="center" android:paddingLeft="9dp" android:paddingRight="9dp" android:text="+ Add DP"
            android:textColor="#FFFFFFFF" android:textSize="10sp" android:textStyle="bold" android:background="@drawable/widget_dp_button"/>
        <View android:layout_width="5dp" android:layout_height="1dp"/>
        <TextView android:id="@+id/widget_add_bonus" android:layout_width="wrap_content" android:layout_height="30dp"
            android:gravity="center" android:paddingLeft="9dp" android:paddingRight="9dp" android:text="+ Bonus"
            android:textColor="#FFFFFFFF" android:textSize="10sp" android:textStyle="bold" android:background="@drawable/widget_bonus_button"/>
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
    "drawable/widget_dp_button.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android"><solid android:color="#176B50"/><corners android:radius="8dp"/></shape>''',
    "drawable/widget_bonus_button.xml": r'''<shape xmlns:android="http://schemas.android.com/apk/res/android"><solid android:color="#315D9A"/><corners android:radius="8dp"/></shape>''',
    "values/widget_strings.xml": r'''<resources><string name="user_hub_widget_description">Quick DP and bonus entry</string></resources>''',
    "values/widget_colors.xml": r'''<resources>
<color name="widget_background">#FFFFFFFF</color><color name="widget_surface">#FFF1F4F7</color>
<color name="widget_text_primary">#FF18202B</color><color name="widget_text_secondary">#FF687385</color>
<color name="widget_dp_accent">#FF176B50</color><color name="widget_bonus_accent">#FF315D9A</color>
</resources>''',
    "values-night/widget_colors.xml": r'''<resources>
<color name="widget_background">#FF171C24</color><color name="widget_surface">#FF252D38</color>
<color name="widget_text_primary">#FFF2F5F8</color><color name="widget_text_secondary">#FFABB6C4</color>
<color name="widget_dp_accent">#FF70D6AF</color><color name="widget_bonus_accent">#FF91B9F5</color>
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
        A+"excludeFromRecents": "true", A+"theme": "@android:style/Theme.Material.DayNight.Dialog.Alert",
        A+"windowSoftInputMode": "adjustResize"
    })
tree.write(manifest, encoding="utf-8", xml_declaration=True)
print("Installed compact 4x2 User Hub home-screen widget for " + package)
