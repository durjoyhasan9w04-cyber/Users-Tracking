package com.userhub.tracker

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.time.LocalDate
import java.time.temporal.ChronoUnit

class TrackerDb(context: Context) : SQLiteOpenHelper(context, "tracker.db", null, 2) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, number TEXT NOT NULL DEFAULT '', first_added TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', do_not_contact INTEGER NOT NULL DEFAULT 0, onboarding_type TEXT NOT NULL DEFAULT 'previous')")
        db.execSQL("CREATE TABLE dp_records (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, record_date TEXT NOT NULL, dp1 REAL, dp2 REAL, dp3 REAL, dp4 REAL, dp5 REAL, contact_checked INTEGER NOT NULL DEFAULT 0, contact_notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id))")
        db.execSQL("CREATE TABLE bonuses (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, bonus_date TEXT NOT NULL, amount REAL NOT NULL, related_dp REAL, reason TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', FOREIGN KEY(user_id) REFERENCES users(id))")
        db.execSQL("CREATE TABLE contacts (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, contact_date TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'Contacted', notes TEXT NOT NULL DEFAULT '', reason TEXT NOT NULL DEFAULT 'General', channel TEXT NOT NULL DEFAULT 'WhatsApp', follow_up_date TEXT NOT NULL DEFAULT '', FOREIGN KEY(user_id) REFERENCES users(id))")
        db.execSQL("CREATE TABLE user_preferences (user_id INTEGER PRIMARY KEY, sports TEXT NOT NULL DEFAULT '', teams TEXT NOT NULL DEFAULT '', players TEXT NOT NULL DEFAULT '', competitions TEXT NOT NULL DEFAULT '', language TEXT NOT NULL DEFAULT 'Bangla', contact_channel TEXT NOT NULL DEFAULT 'WhatsApp', contact_window TEXT NOT NULL DEFAULT '', contact_opt_in INTEGER NOT NULL DEFAULT 0, event_updates_opt_in INTEGER NOT NULL DEFAULT 0, contact_frequency TEXT NOT NULL DEFAULT 'Only when I request', updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)")
        db.execSQL("CREATE TABLE match_events (id INTEGER PRIMARY KEY AUTOINCREMENT, sport TEXT NOT NULL, competition TEXT NOT NULL DEFAULT '', home_name TEXT NOT NULL, away_name TEXT NOT NULL DEFAULT '', event_date TEXT NOT NULL, event_time TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, source_id TEXT, source TEXT NOT NULL DEFAULT 'manual')")
        db.execSQL("CREATE INDEX idx_dp_date ON dp_records(record_date)")
        db.execSQL("CREATE INDEX idx_dp_user ON dp_records(user_id)")
        db.execSQL("CREATE INDEX idx_bonus_date ON bonuses(bonus_date)")
        db.execSQL("CREATE INDEX idx_contacts_date ON contacts(contact_date)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL("CREATE TABLE IF NOT EXISTS contacts (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, contact_date TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'Contacted', notes TEXT NOT NULL DEFAULT '', reason TEXT NOT NULL DEFAULT 'General', channel TEXT NOT NULL DEFAULT 'WhatsApp', follow_up_date TEXT NOT NULL DEFAULT '', FOREIGN KEY(user_id) REFERENCES users(id))")
            db.execSQL("CREATE TABLE IF NOT EXISTS user_preferences (user_id INTEGER PRIMARY KEY, sports TEXT NOT NULL DEFAULT '', teams TEXT NOT NULL DEFAULT '', players TEXT NOT NULL DEFAULT '', competitions TEXT NOT NULL DEFAULT '', language TEXT NOT NULL DEFAULT 'Bangla', contact_channel TEXT NOT NULL DEFAULT 'WhatsApp', contact_window TEXT NOT NULL DEFAULT '', contact_opt_in INTEGER NOT NULL DEFAULT 0, event_updates_opt_in INTEGER NOT NULL DEFAULT 0, contact_frequency TEXT NOT NULL DEFAULT 'Only when I request', updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)")
            db.execSQL("CREATE TABLE IF NOT EXISTS match_events (id INTEGER PRIMARY KEY AUTOINCREMENT, sport TEXT NOT NULL, competition TEXT NOT NULL DEFAULT '', home_name TEXT NOT NULL, away_name TEXT NOT NULL DEFAULT '', event_date TEXT NOT NULL, event_time TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, source_id TEXT, source TEXT NOT NULL DEFAULT 'manual')")
            db.execSQL("CREATE INDEX IF NOT EXISTS idx_contacts_date ON contacts(contact_date)")
        }
    }

    fun users(): List<User> {
        val out = mutableListOf<User>()
        readableDatabase.rawQuery("SELECT id,name,number,first_added,notes FROM users ORDER BY name COLLATE NOCASE", null).use { c ->
            while (c.moveToNext()) out += User(c.getLong(0), c.getString(1), c.getString(2), c.getString(3), c.getString(4))
        }
        return out
    }
    fun addUser(name: String, number: String, notes: String): Long {
        val cleanNumber = number.trim()
        if (cleanNumber.isNotEmpty()) {
            readableDatabase.rawQuery("SELECT id FROM users WHERE number=? LIMIT 1", arrayOf(cleanNumber)).use { if (it.moveToFirst()) return -1L }
        }
        val v = ContentValues().apply { put("name", name.trim()); put("number", cleanNumber); put("first_added", LocalDate.now().toString()); put("notes", notes.trim()) }
        return writableDatabase.insert("users", null, v)
    }
    fun addDp(userId: Long, values: List<Double?>, contacted: Boolean, notes: String) {
        val v = ContentValues().apply {
            put("user_id", userId); put("record_date", LocalDate.now().toString())
            values.forEachIndexed { i, n -> if (n != null) put("dp${i+1}", n) }
            put("contact_checked", if (contacted) 1 else 0); put("contact_notes", notes)
        }
        writableDatabase.insert("dp_records", null, v)
    }
    fun addBonus(userId: Long, amount: Double, reason: String, notes: String) {
        val v = ContentValues().apply { put("user_id", userId); put("bonus_date", LocalDate.now().toString()); put("amount", amount); put("reason", reason); put("notes", notes) }
        writableDatabase.insert("bonuses", null, v)
    }
    fun addContact(userId: Long, notes: String, channel: String = "WhatsApp") {
        val v = ContentValues().apply { put("user_id", userId); put("contact_date", LocalDate.now().toString()); put("notes", notes); put("channel", channel) }
        writableDatabase.insert("contacts", null, v)
    }
    fun savePreferences(userId: Long, sports: String, teams: String, competitions: String, language: String) {
        val v = ContentValues().apply { put("user_id", userId); put("sports", sports); put("teams", teams); put("competitions", competitions); put("language", language); put("updated_at", LocalDate.now().toString()) }
        writableDatabase.insertWithOnConflict("user_preferences", null, v, SQLiteDatabase.CONFLICT_REPLACE)
    }
    fun addMatch(sport: String, competition: String, home: String, away: String, date: String, time: String, notes: String) {
        val v = ContentValues().apply { put("sport", sport); put("competition", competition); put("home_name", home); put("away_name", away); put("event_date", date); put("event_time", time); put("notes", notes); put("source", "manual") }
        writableDatabase.insert("match_events", null, v)
    }
    fun totalDp(): Double = scalar("SELECT COALESCE(SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)),0) FROM dp_records")
    fun todayDp(): Double = scalar("SELECT COALESCE(SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)),0) FROM dp_records WHERE record_date=?", arrayOf(today()))
    fun todayBonus(): Double = scalar("SELECT COALESCE(SUM(amount),0) FROM bonuses WHERE bonus_date=?", arrayOf(today()))
    fun monthDp(): Double = scalar("SELECT COALESCE(SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)),0) FROM dp_records WHERE substr(record_date,1,7)=?", arrayOf(today().take(7)))
    fun monthBonus(): Double = scalar("SELECT COALESCE(SUM(amount),0) FROM bonuses WHERE substr(bonus_date,1,7)=?", arrayOf(today().take(7)))
    fun dpCountToday(): Int = count("SELECT COUNT(*) FROM dp_records WHERE record_date=?", arrayOf(today()))
    fun contactedToday(): Int = count("SELECT COUNT(DISTINCT user_id) FROM dp_records WHERE record_date=? AND contact_checked=1", arrayOf(today()))
    fun usersWithMultipleDpToday(): Int = count("SELECT COUNT(*) FROM (SELECT user_id FROM dp_records WHERE record_date=? AND ((dp1 IS NOT NULL)+(dp2 IS NOT NULL)+(dp3 IS NOT NULL)+(dp4 IS NOT NULL)+(dp5 IS NOT NULL))>1 GROUP BY user_id)", arrayOf(today()))
    fun profileTotals(id: Long): Pair<Double, Double> {
        val dp = scalar("SELECT COALESCE(SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)),0) FROM dp_records WHERE user_id=?", arrayOf(id.toString()))
        val b = scalar("SELECT COALESCE(SUM(amount),0) FROM bonuses WHERE user_id=?", arrayOf(id.toString()))
        return dp to b
    }
    fun lastDp(id: Long): String? = readableDatabase.rawQuery("SELECT MAX(record_date) FROM dp_records WHERE user_id=?", arrayOf(id.toString())).use { if(it.moveToFirst() && !it.isNull(0)) it.getString(0) else null }
    fun followUpUsers(): List<Pair<User, String>> = users().mapNotNull { u ->
        val last = lastDp(u.id)
        val days = if (last == null) null else ChronoUnit.DAYS.between(LocalDate.parse(last), LocalDate.now()).toInt()
        val status = when { days == null -> "Never DP"; days <= 3 -> "Active"; days <= 7 -> "Follow-up · 4–7d"; days <= 14 -> "Inactive · 8–14d"; days <= 30 -> "Long inactive · 15–30d"; else -> "Very long inactive · 31+d" }
        if (status == "Active") null else u to status
    }
    fun monthSummary(): List<SummaryRow> {
        val rows = mutableListOf<SummaryRow>()
        readableDatabase.rawQuery("SELECT record_date, SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)), COUNT(*) FROM dp_records WHERE substr(record_date,1,7)=? GROUP BY record_date ORDER BY record_date DESC", arrayOf(today().take(7))).use { c ->
            while(c.moveToNext()) rows += SummaryRow(c.getString(0), c.getDouble(1), c.getInt(2))
        }
        return rows
    }
    fun upcomingMatches(): List<MatchEvent> {
        val rows = mutableListOf<MatchEvent>()
        readableDatabase.rawQuery("SELECT id,sport,competition,home_name,away_name,event_date,event_time,notes FROM match_events WHERE event_date>=? ORDER BY event_date,event_time LIMIT 30", arrayOf(today())).use { c ->
            while(c.moveToNext()) rows += MatchEvent(c.getLong(0),c.getString(1),c.getString(2),c.getString(3),c.getString(4),c.getString(5),c.getString(6),c.getString(7))
        }
        return rows
    }
    fun contactUserIdsToday(): Set<Long> {
        val ids = mutableSetOf<Long>()
        readableDatabase.rawQuery("SELECT DISTINCT user_id FROM contacts WHERE contact_date=?", arrayOf(today())).use { c -> while(c.moveToNext()) ids += c.getLong(0) }
        return ids
    }
    private fun scalar(sql: String, args: Array<String> = emptyArray()): Double = readableDatabase.rawQuery(sql,args).use { if(it.moveToFirst()) it.getDouble(0) else 0.0 }
    private fun count(sql: String, args: Array<String> = emptyArray()): Int = readableDatabase.rawQuery(sql,args).use { if(it.moveToFirst()) it.getInt(0) else 0 }
    private fun today() = LocalDate.now().toString()
}
data class User(val id: Long, val name: String, val number: String, val firstAdded: String, val notes: String)
data class SummaryRow(val date: String, val total: Double, val entries: Int)
data class MatchEvent(val id: Long, val sport: String, val competition: String, val home: String, val away: String, val date: String, val time: String, val notes: String)
