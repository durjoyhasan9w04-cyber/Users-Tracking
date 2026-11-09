package com.userhub.tracker

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.time.LocalDate

class TrackerDb(context: Context) : SQLiteOpenHelper(context, "tracker.db", null, 1) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, number TEXT NOT NULL DEFAULT '', first_added TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', do_not_contact INTEGER NOT NULL DEFAULT 0, onboarding_type TEXT NOT NULL DEFAULT 'previous')")
        db.execSQL("CREATE TABLE dp_records (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, record_date TEXT NOT NULL, dp1 REAL, dp2 REAL, dp3 REAL, dp4 REAL, dp5 REAL, contact_checked INTEGER NOT NULL DEFAULT 0, contact_notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id))")
        db.execSQL("CREATE TABLE bonuses (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, bonus_date TEXT NOT NULL, amount REAL NOT NULL, related_dp REAL, reason TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', FOREIGN KEY(user_id) REFERENCES users(id))")
        db.execSQL("CREATE TABLE contacts (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, contact_date TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'Contacted', notes TEXT NOT NULL DEFAULT '', reason TEXT NOT NULL DEFAULT 'General support', channel TEXT NOT NULL DEFAULT 'WhatsApp', follow_up_date TEXT NOT NULL DEFAULT '', FOREIGN KEY(user_id) REFERENCES users(id))")
        db.execSQL("CREATE TABLE user_preferences (user_id INTEGER PRIMARY KEY, sports TEXT NOT NULL DEFAULT '', teams TEXT NOT NULL DEFAULT '', players TEXT NOT NULL DEFAULT '', competitions TEXT NOT NULL DEFAULT '', language TEXT NOT NULL DEFAULT 'Bangla', contact_channel TEXT NOT NULL DEFAULT 'WhatsApp', contact_window TEXT NOT NULL DEFAULT '', contact_opt_in INTEGER NOT NULL DEFAULT 0, event_updates_opt_in INTEGER NOT NULL DEFAULT 0, contact_frequency TEXT NOT NULL DEFAULT 'Only when I request', updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)")
        db.execSQL("CREATE TABLE match_events (id INTEGER PRIMARY KEY AUTOINCREMENT, sport TEXT NOT NULL, competition TEXT NOT NULL DEFAULT '', home_name TEXT NOT NULL, away_name TEXT NOT NULL DEFAULT '', event_date TEXT NOT NULL, event_time TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, source_id TEXT, source TEXT NOT NULL DEFAULT 'manual')")
        db.execSQL("CREATE INDEX idx_dp_date ON dp_records(record_date)")
        db.execSQL("CREATE INDEX idx_dp_user ON dp_records(user_id)")
        db.execSQL("CREATE INDEX idx_bonus_date ON bonuses(bonus_date)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {}

    fun users(): List<User> {
        val out = mutableListOf<User>(); readableDatabase.rawQuery("SELECT id,name,number,first_added,notes FROM users ORDER BY name COLLATE NOCASE", null).use { c ->
            while (c.moveToNext()) out += User(c.getLong(0), c.getString(1), c.getString(2), c.getString(3), c.getString(4))
        }; return out
    }
    fun addUser(name: String, number: String, notes: String): Long {
        val v = ContentValues().apply { put("name", name.trim()); put("number", number.trim()); put("first_added", LocalDate.now().toString()); put("notes", notes) }
        return writableDatabase.insert("users", null, v)
    }
    fun addDp(userId: Long, values: List<Double?>, contacted: Boolean, notes: String) {
        val v = ContentValues().apply { put("user_id", userId); put("record_date", LocalDate.now().toString()); values.forEachIndexed { i, n -> if (n != null) put("dp${i+1}", n) }; put("contact_checked", if (contacted) 1 else 0); put("contact_notes", notes) }
        writableDatabase.insert("dp_records", null, v)
    }
    fun addBonus(userId: Long, amount: Double, reason: String, notes: String) {
        val v = ContentValues().apply { put("user_id", userId); put("bonus_date", LocalDate.now().toString()); put("amount", amount); put("reason", reason); put("notes", notes) }
        writableDatabase.insert("bonuses", null, v)
    }
    fun totalDp(): Double = readableDatabase.rawQuery("SELECT COALESCE(SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)),0) FROM dp_records", null).use { if (it.moveToFirst()) it.getDouble(0) else 0.0 }
    fun todayDp(): Double = readableDatabase.rawQuery("SELECT COALESCE(SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)),0) FROM dp_records WHERE record_date=?", arrayOf(LocalDate.now().toString())).use { if (it.moveToFirst()) it.getDouble(0) else 0.0 }
    fun todayBonus(): Double = readableDatabase.rawQuery("SELECT COALESCE(SUM(amount),0) FROM bonuses WHERE bonus_date=?", arrayOf(LocalDate.now().toString())).use { if (it.moveToFirst()) it.getDouble(0) else 0.0 }
    fun dpCountToday(): Int = readableDatabase.rawQuery("SELECT COUNT(*) FROM dp_records WHERE record_date=?", arrayOf(LocalDate.now().toString())).use { if (it.moveToFirst()) it.getInt(0) else 0 }
    fun profileTotals(id: Long): Pair<Double, Double> {
        val dp = readableDatabase.rawQuery("SELECT COALESCE(SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)),0) FROM dp_records WHERE user_id=?", arrayOf(id.toString())).use { if(it.moveToFirst()) it.getDouble(0) else 0.0 }
        val b = readableDatabase.rawQuery("SELECT COALESCE(SUM(amount),0) FROM bonuses WHERE user_id=?", arrayOf(id.toString())).use { if(it.moveToFirst()) it.getDouble(0) else 0.0 }
        return dp to b
    }
}
data class User(val id: Long, val name: String, val number: String, val firstAdded: String, val notes: String)
