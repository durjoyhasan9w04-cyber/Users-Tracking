package com.userhub.tracker

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.time.LocalDate
import java.time.temporal.ChronoUnit

class TrackerDb(context: Context) : SQLiteOpenHelper(context, "tracker.db", null, 3) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, number TEXT NOT NULL DEFAULT '', first_added TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', do_not_contact INTEGER NOT NULL DEFAULT 0, onboarding_type TEXT NOT NULL DEFAULT 'previous')")
        db.execSQL("CREATE TABLE dp_records (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, record_date TEXT NOT NULL, dp1 REAL, dp2 REAL, dp3 REAL, dp4 REAL, dp5 REAL, contact_checked INTEGER NOT NULL DEFAULT 0, contact_notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id))")
        db.execSQL("CREATE TABLE bonuses (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, bonus_date TEXT NOT NULL, amount REAL NOT NULL, related_dp REAL, reason TEXT NOT NULL, notes TEXT NOT NULL DEFAULT '', FOREIGN KEY(user_id) REFERENCES users(id))")
        db.execSQL("CREATE TABLE contacts (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, contact_date TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'Contacted', notes TEXT NOT NULL DEFAULT '', reason TEXT NOT NULL DEFAULT 'General support', channel TEXT NOT NULL DEFAULT 'WhatsApp', follow_up_date TEXT NOT NULL DEFAULT '', FOREIGN KEY(user_id) REFERENCES users(id))")
        db.execSQL("CREATE TABLE user_preferences (user_id INTEGER PRIMARY KEY, sports TEXT NOT NULL DEFAULT '', teams TEXT NOT NULL DEFAULT '', players TEXT NOT NULL DEFAULT '', competitions TEXT NOT NULL DEFAULT '', language TEXT NOT NULL DEFAULT 'Bangla', contact_channel TEXT NOT NULL DEFAULT 'WhatsApp', contact_window TEXT NOT NULL DEFAULT '', contact_opt_in INTEGER NOT NULL DEFAULT 0, event_updates_opt_in INTEGER NOT NULL DEFAULT 0, contact_frequency TEXT NOT NULL DEFAULT 'Only when I request', updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)")
        db.execSQL("CREATE TABLE match_events (id INTEGER PRIMARY KEY AUTOINCREMENT, sport TEXT NOT NULL, competition TEXT NOT NULL DEFAULT '', home_name TEXT NOT NULL, away_name TEXT NOT NULL DEFAULT '', event_date TEXT NOT NULL, event_time TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, source_id TEXT, source TEXT NOT NULL DEFAULT 'manual')")
        db.execSQL("CREATE TABLE fixture_sync_state (id INTEGER PRIMARY KEY CHECK(id=1), status TEXT NOT NULL DEFAULT 'idle', message TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL DEFAULT '')")
        db.execSQL("INSERT OR IGNORE INTO fixture_sync_state(id,status,message,updated_at) VALUES(1,'idle','Not checked yet','')")
        db.execSQL("CREATE TABLE fixture_sync_cache (sport TEXT NOT NULL,event_date TEXT NOT NULL,synced_at TEXT NOT NULL,provider TEXT NOT NULL,PRIMARY KEY(sport,event_date,provider))")
        createIndexes(db)
    }
    private fun createIndexes(db: SQLiteDatabase) {
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_dp_date ON dp_records(record_date)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_dp_user ON dp_records(user_id)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_bonus_date ON bonuses(bonus_date)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_contacts_date ON contacts(contact_date)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_match_date ON match_events(event_date)")
        db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS idx_match_source_id ON match_events(source_id) WHERE source_id IS NOT NULL")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL("CREATE TABLE IF NOT EXISTS contacts (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, contact_date TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'Contacted', notes TEXT NOT NULL DEFAULT '', reason TEXT NOT NULL DEFAULT 'General support', channel TEXT NOT NULL DEFAULT 'WhatsApp', follow_up_date TEXT NOT NULL DEFAULT '', FOREIGN KEY(user_id) REFERENCES users(id))")
            db.execSQL("CREATE TABLE IF NOT EXISTS user_preferences (user_id INTEGER PRIMARY KEY, sports TEXT NOT NULL DEFAULT '', teams TEXT NOT NULL DEFAULT '', players TEXT NOT NULL DEFAULT '', competitions TEXT NOT NULL DEFAULT '', language TEXT NOT NULL DEFAULT 'Bangla', contact_channel TEXT NOT NULL DEFAULT 'WhatsApp', contact_window TEXT NOT NULL DEFAULT '', contact_opt_in INTEGER NOT NULL DEFAULT 0, event_updates_opt_in INTEGER NOT NULL DEFAULT 0, contact_frequency TEXT NOT NULL DEFAULT 'Only when I request', updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE)")
            db.execSQL("CREATE TABLE IF NOT EXISTS match_events (id INTEGER PRIMARY KEY AUTOINCREMENT, sport TEXT NOT NULL, competition TEXT NOT NULL DEFAULT '', home_name TEXT NOT NULL, away_name TEXT NOT NULL DEFAULT '', event_date TEXT NOT NULL, event_time TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, source_id TEXT, source TEXT NOT NULL DEFAULT 'manual')")
        }
        if (oldVersion < 3) {
            val cc = db.rawQuery("PRAGMA table_info(contacts)", null).use { c -> buildSet { while(c.moveToNext()) add(c.getString(1)) } }
            listOf("reason" to "TEXT NOT NULL DEFAULT 'General support'", "channel" to "TEXT NOT NULL DEFAULT 'WhatsApp'", "follow_up_date" to "TEXT NOT NULL DEFAULT ''").forEach { (n,d) -> if(n !in cc) db.execSQL("ALTER TABLE contacts ADD COLUMN $n $d") }
            val mc = db.rawQuery("PRAGMA table_info(match_events)", null).use { c -> buildSet { while(c.moveToNext()) add(c.getString(1)) } }
            if("source_id" !in mc) db.execSQL("ALTER TABLE match_events ADD COLUMN source_id TEXT")
            if("source" !in mc) db.execSQL("ALTER TABLE match_events ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'")
            db.execSQL("CREATE TABLE IF NOT EXISTS fixture_sync_state (id INTEGER PRIMARY KEY CHECK(id=1), status TEXT NOT NULL DEFAULT 'idle', message TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL DEFAULT '')")
            db.execSQL("INSERT OR IGNORE INTO fixture_sync_state(id,status,message,updated_at) VALUES(1,'idle','Not checked yet','')")
            db.execSQL("CREATE TABLE IF NOT EXISTS fixture_sync_cache (sport TEXT NOT NULL,event_date TEXT NOT NULL,synced_at TEXT NOT NULL,provider TEXT NOT NULL,PRIMARY KEY(sport,event_date,provider))")
        }
        createIndexes(db)
    }

    fun users(): List<User> {
        val out=mutableListOf<User>()
        readableDatabase.rawQuery("SELECT id,name,number,first_added,notes,do_not_contact,onboarding_type FROM users ORDER BY name COLLATE NOCASE",null).use { c ->
            while(c.moveToNext()) {
                val id=c.getLong(0); val last=lastDp(id); val days=last?.let{ChronoUnit.DAYS.between(LocalDate.parse(it),LocalDate.now()).toInt()}
                val life=when { last!=null -> "ACTIVE"; c.getString(6)=="new" && ChronoUnit.DAYS.between(LocalDate.parse(c.getString(3)),LocalDate.now())>=30 -> "NEVER DP"; c.getString(6)=="new" -> "NEW"; else -> "ACTIVE" }
                val totals=profileTotals(id)
                out += User(id,c.getString(1),c.getString(2),c.getString(3),c.getString(4),c.getInt(5)!=0,c.getString(6),last,days,dpStatus(days),life,totals.first,totals.second)
            }
        }
        return out
    }
    fun addUser(name:String,number:String,notes:String,onboarding:String="new"):Long {
        val clean=number.trim()
        if(clean.isNotEmpty()) readableDatabase.rawQuery("SELECT id FROM users WHERE number=? LIMIT 1",arrayOf(clean)).use { if(it.moveToFirst()) return -1L }
        val v=ContentValues().apply { put("name",name.trim());put("number",clean);put("first_added",today());put("notes",notes.trim());put("onboarding_type",if(onboarding=="previous") "previous" else "new") }
        return writableDatabase.insert("users",null,v)
    }
    fun toggleDoNotContact(id:Long) {
        writableDatabase.execSQL("UPDATE users SET do_not_contact=CASE do_not_contact WHEN 0 THEN 1 ELSE 0 END WHERE id=?",arrayOf(id))
    }
    fun addDp(userId:Long,values:List<Double?>) {
        val v=ContentValues().apply { put("user_id",userId);put("record_date",today());values.forEachIndexed{i,n->if(n!=null)put("dp${i+1}",n)} }
        writableDatabase.insert("dp_records",null,v)
    }
    fun addBonus(userId:Long,amount:Double,related:Double?,reason:String,notes:String) {
        val v=ContentValues().apply { put("user_id",userId);put("bonus_date",today());put("amount",amount);if(related!=null)put("related_dp",related);put("reason",reason);put("notes",notes) }
        writableDatabase.insert("bonuses",null,v)
    }
    fun addContact(userId:Long,status:String,reason:String,channel:String,followUp:String,notes:String) {
        val v=ContentValues().apply { put("user_id",userId);put("contact_date",today());put("status",status);put("reason",reason);put("channel",channel);put("follow_up_date",followUp);put("notes",notes) }
        writableDatabase.insert("contacts",null,v)
    }
    fun savePreferences(userId:Long,sports:String,teams:String,players:String,competitions:String,language:String,channel:String,window:String,frequency:String,contactOpt:Boolean,eventOpt:Boolean) {
        val v=ContentValues().apply { put("user_id",userId);put("sports",sports);put("teams",teams);put("players",players);put("competitions",competitions);put("language",language);put("contact_channel",channel);put("contact_window",window);put("contact_frequency",frequency);put("contact_opt_in",if(contactOpt)1 else 0);put("event_updates_opt_in",if(eventOpt)1 else 0);put("updated_at",java.time.LocalDateTime.now().toString()) }
        writableDatabase.insertWithOnConflict("user_preferences",null,v,SQLiteDatabase.CONFLICT_REPLACE)
    }
    fun preferences(id:Long):Preferences? = readableDatabase.rawQuery("SELECT sports,teams,players,competitions,language,contact_channel,contact_window,contact_frequency,contact_opt_in,event_updates_opt_in FROM user_preferences WHERE user_id=?",arrayOf(id.toString())).use { c ->
        if(!c.moveToFirst()) null else Preferences(c.getString(0),c.getString(1),c.getString(2),c.getString(3),c.getString(4),c.getString(5),c.getString(6),c.getString(7),c.getInt(8)!=0,c.getInt(9)!=0)
    }
    fun addMatch(sport:String,competition:String,home:String,away:String,date:String,time:String,notes:String,source:String="manual",sourceId:String?=null) {
        val v=ContentValues().apply { put("sport",sport);put("competition",competition);put("home_name",home);put("away_name",away);put("event_date",date);put("event_time",time);put("notes",notes);put("source",source);if(sourceId!=null)put("source_id",sourceId) }
        if(sourceId==null) writableDatabase.insert("match_events",null,v) else writableDatabase.insertWithOnConflict("match_events",null,v,SQLiteDatabase.CONFLICT_REPLACE)
    }
    fun deleteMatch(id:Long){writableDatabase.delete("match_events","id=?",arrayOf(id.toString()))}
    fun totalDp():Double=scalar("SELECT COALESCE(SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)),0) FROM dp_records")
    fun todayDp():Double=scalar("SELECT COALESCE(SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)),0) FROM dp_records WHERE record_date=?",arrayOf(today()))
    fun todayBonus():Double=scalar("SELECT COALESCE(SUM(amount),0) FROM bonuses WHERE bonus_date=?",arrayOf(today()))
    fun monthDp(month:String=today().take(7)):Double=scalar("SELECT COALESCE(SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)),0) FROM dp_records WHERE substr(record_date,1,7)=?",arrayOf(month))
    fun monthBonus(month:String=today().take(7)):Double=scalar("SELECT COALESCE(SUM(amount),0) FROM bonuses WHERE substr(bonus_date,1,7)=?",arrayOf(month))
    fun dpCountToday():Int=count("SELECT COALESCE(SUM((dp1>0)+(dp2>0)+(dp3>0)+(dp4>0)+(dp5>0)),0) FROM dp_records WHERE record_date=?",arrayOf(today()))
    fun todayDpUsers():Int=count("SELECT COUNT(DISTINCT user_id) FROM dp_records WHERE record_date=? AND (COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0))>0",arrayOf(today()))
    fun contactedToday():Int=count("SELECT COUNT(DISTINCT user_id) FROM contacts WHERE contact_date=? AND status='Contacted'",arrayOf(today()))
    fun usersWithMultipleDpToday():Int=count("SELECT COUNT(*) FROM (SELECT user_id FROM dp_records WHERE record_date=? GROUP BY user_id HAVING SUM((dp1>0)+(dp2>0)+(dp3>0)+(dp4>0)+(dp5>0))>=2)",arrayOf(today()))
    fun activeMonthUsers(month:String=today().take(7)):Int=count("SELECT COUNT(DISTINCT user_id) FROM dp_records WHERE substr(record_date,1,7)=? AND (COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0))>0",arrayOf(month))
    fun noDpThisMonth(month:String=today().take(7)):Int=count("SELECT COUNT(*) FROM users u WHERE NOT EXISTS (SELECT 1 FROM dp_records d WHERE d.user_id=u.id AND substr(d.record_date,1,7)=? AND (COALESCE(d.dp1,0)+COALESCE(d.dp2,0)+COALESCE(d.dp3,0)+COALESCE(d.dp4,0)+COALESCE(d.dp5,0))>0)",arrayOf(month))
    fun profileTotals(id:Long):Pair<Double,Double> = scalar("SELECT COALESCE(SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)),0) FROM dp_records WHERE user_id=?",arrayOf(id.toString())) to scalar("SELECT COALESCE(SUM(amount),0) FROM bonuses WHERE user_id=?",arrayOf(id.toString()))
    fun lastDp(id:Long):String?=readableDatabase.rawQuery("SELECT MAX(record_date) FROM dp_records WHERE user_id=? AND (COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0))>0",arrayOf(id.toString())).use{if(it.moveToFirst()&&!it.isNull(0))it.getString(0)else null}
    fun followUpUsers():List<Pair<User,String>>=users().mapNotNull{u-> if(u.activityStatus=="ACTIVE") null else u to u.activityStatus}
    fun dpHistory(userId:Long):List<DpRecord> {
        val out=mutableListOf<DpRecord>()
        readableDatabase.rawQuery("SELECT id,record_date,dp1,dp2,dp3,dp4,dp5 FROM dp_records WHERE user_id=? ORDER BY record_date DESC,id DESC",arrayOf(userId.toString())).use{c->while(c.moveToNext())out+=DpRecord(c.getLong(0),c.getString(1),(1..5).map{i->if(c.isNull(i+1))null else c.getDouble(i+1)})}
        return out
    }
    fun bonusHistory(userId:Long?=null,month:String?=null):List<BonusRecord> {
        val out=mutableListOf<BonusRecord>();val where=mutableListOf<String>();val args=mutableListOf<String>()
        if(userId!=null){where+="user_id=?";args+=userId.toString()};if(month!=null){where+="substr(bonus_date,1,7)=?";args+=month}
        val sql="SELECT b.id,b.user_id,u.name,b.bonus_date,b.amount,b.related_dp,b.reason,b.notes FROM bonuses b JOIN users u ON u.id=b.user_id"+(if(where.isEmpty())"" else " WHERE "+where.joinToString(" AND "))+" ORDER BY b.bonus_date DESC,b.id DESC"
        readableDatabase.rawQuery(sql,args.toTypedArray()).use{c->while(c.moveToNext())out+=BonusRecord(c.getLong(0),c.getLong(1),c.getString(2),c.getString(3),c.getDouble(4),if(c.isNull(5))null else c.getDouble(5),c.getString(6),c.getString(7))}
        return out
    }
    fun contactHistory(userId:Long?=null):List<ContactRecord> {
        val out=mutableListOf<ContactRecord>();val args=if(userId==null)emptyArray() else arrayOf(userId.toString());val where=if(userId==null)"" else " WHERE ct.user_id=?"
        readableDatabase.rawQuery("SELECT ct.id,ct.user_id,u.name,ct.contact_date,ct.status,ct.reason,ct.channel,ct.follow_up_date,ct.notes FROM contacts ct JOIN users u ON u.id=ct.user_id$where ORDER BY ct.contact_date DESC,ct.id DESC",args).use{c->while(c.moveToNext())out+=ContactRecord(c.getLong(0),c.getLong(1),c.getString(2),c.getString(3),c.getString(4),c.getString(5),c.getString(6),c.getString(7),c.getString(8))}
        return out
    }
    fun monthSummary(month:String=today().take(7)):List<SummaryRow> {
        val rows=mutableListOf<SummaryRow>()
        readableDatabase.rawQuery("SELECT record_date,SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)),SUM((dp1>0)+(dp2>0)+(dp3>0)+(dp4>0)+(dp5>0)),COUNT(DISTINCT user_id) FROM dp_records WHERE substr(record_date,1,7)=? GROUP BY record_date ORDER BY record_date DESC",arrayOf(month)).use{c->while(c.moveToNext())rows+=SummaryRow(c.getString(0),c.getDouble(1),c.getInt(2),c.getInt(3))}
        return rows
    }
    fun reportUsers(month:String):List<ReportUser> {
        val out=mutableListOf<ReportUser>()
        for(u in users()) {
            val dp=scalar("SELECT COALESCE(SUM(COALESCE(dp1,0)+COALESCE(dp2,0)+COALESCE(dp3,0)+COALESCE(dp4,0)+COALESCE(dp5,0)),0) FROM dp_records WHERE user_id=? AND substr(record_date,1,7)=?",arrayOf(u.id.toString(),month))
            val count=count("SELECT COALESCE(SUM((dp1>0)+(dp2>0)+(dp3>0)+(dp4>0)+(dp5>0)),0) FROM dp_records WHERE user_id=? AND substr(record_date,1,7)=?",arrayOf(u.id.toString(),month))
            val bonus=scalar("SELECT COALESCE(SUM(amount),0) FROM bonuses WHERE user_id=? AND substr(bonus_date,1,7)=?",arrayOf(u.id.toString(),month))
            out+=ReportUser(u,dp,count,bonus,profileTotals(u.id).first>0)
        }
        return out
    }
    fun dpCalendar(month:String):List<SummaryRow> = monthSummary(month)
    fun upcomingMatches():List<MatchEvent> {
        val rows=mutableListOf<MatchEvent>()
        readableDatabase.rawQuery("SELECT id,sport,competition,home_name,away_name,event_date,event_time,notes,source FROM match_events WHERE event_date>=? ORDER BY event_date,event_time LIMIT 100",arrayOf(today())).use{c->while(c.moveToNext())rows+=MatchEvent(c.getLong(0),c.getString(1),c.getString(2),c.getString(3),c.getString(4),c.getString(5),c.getString(6),c.getString(7),c.getString(8))}
        return rows
    }
    fun matchingReminders():List<ReminderGroup> {
        val events=upcomingMatches().filter{it.date<=LocalDate.now().plusDays(14).toString()}
        val opted=users().filter{u->!u.doNotContact}.mapNotNull{u->preferences(u.id)?.takeIf{it.contactOptIn&&it.eventOptIn}?.let{u to it}}
        val groups=mutableListOf<ReminderGroup>()
        events.forEach{ev->
            val searchable="${ev.home} ${ev.away} ${ev.competition}".lowercase()
            val matched=opted.filter{(u,p)->
                val sports=p.sports.split(",").map{it.trim().lowercase()}
                val interests=(p.teams+","+p.players+","+p.competitions).split(",").map{it.trim().lowercase()}.filter{it.isNotBlank()}
                ev.sport.lowercase() in sports && interests.any{searchable.contains(it)}
            }.map{it.first}
            if(matched.isNotEmpty())groups+=ReminderGroup(ev,matched)
        }
        return groups
    }
    fun saveSyncState(status:String,message:String) { val v=ContentValues().apply{put("id",1);put("status",status);put("message",message);put("updated_at",java.time.LocalDateTime.now().toString())};writableDatabase.insertWithOnConflict("fixture_sync_state",null,v,SQLiteDatabase.CONFLICT_REPLACE) }
    fun syncState():Pair<String,String> = readableDatabase.rawQuery("SELECT status,message FROM fixture_sync_state WHERE id=1",null).use{if(it.moveToFirst())it.getString(0) to it.getString(1) else "idle" to "Not checked yet"}
    fun syncFresh(hours:Int=8):Boolean=readableDatabase.rawQuery("SELECT updated_at FROM fixture_sync_state WHERE id=1",null).use{c->if(!c.moveToFirst()||c.getString(0).isNullOrBlank())false else try{java.time.Duration.between(java.time.LocalDateTime.parse(c.getString(0)),java.time.LocalDateTime.now()).toHours()<hours}catch(_:Exception){false}}
    fun isFixtureCached(sport:String,day:String,provider:String,maxHours:Int):Boolean=readableDatabase.rawQuery("SELECT synced_at FROM fixture_sync_cache WHERE sport=? AND event_date=? AND provider=?",arrayOf(sport,day,provider)).use{c->if(!c.moveToFirst())false else try{java.time.Duration.between(java.time.LocalDateTime.parse(c.getString(0)),java.time.LocalDateTime.now()).toHours()<maxHours}catch(_:Exception){false}}
    fun markFixtureCached(sport:String,day:String,provider:String){val v=ContentValues().apply{put("sport",sport);put("event_date",day);put("provider",provider);put("synced_at",java.time.LocalDateTime.now().toString())};writableDatabase.insertWithOnConflict("fixture_sync_cache",null,v,SQLiteDatabase.CONFLICT_REPLACE)}
    fun allUsersCsv():String { val b=StringBuilder("ID,Name,Number,First Added,Notes,Do Not Contact\\n");users().forEach{b.append("${it.id},\\"${csv(it.name)}\\",\\"${csv(it.number)}\\",${it.firstAdded},\\"${csv(it.notes)}\\",${it.doNotContact}\\n")};return b.toString() }
    fun dpCsv():String {val b=StringBuilder("ID,User,Number,Date,DP1,DP2,DP3,DP4,DP5\\n");readableDatabase.rawQuery("SELECT d.id,u.name,u.number,d.record_date,d.dp1,d.dp2,d.dp3,d.dp4,d.dp5 FROM dp_records d JOIN users u ON u.id=d.user_id ORDER BY d.record_date,d.id",null).use{c->while(c.moveToNext())b.append((0..8).joinToString(","){i->if(c.isNull(i))"" else if(i==1||i==2)"\\"${csv(c.getString(i))}\\"" else c.getString(i)}).append("\\n")};return b.toString()}
    fun bonusesCsv():String {val b=StringBuilder("ID,User,Number,Date,Amount,Related DP,Reason,Notes\\n");readableDatabase.rawQuery("SELECT b.id,u.name,u.number,b.bonus_date,b.amount,b.related_dp,b.reason,b.notes FROM bonuses b JOIN users u ON u.id=b.user_id ORDER BY b.bonus_date,b.id",null).use{c->while(c.moveToNext())b.append((0..7).joinToString(","){i->if(c.isNull(i))"" else if(i==1||i==2||i==6||i==7)"\\"${csv(c.getString(i))}\\"" else c.getString(i)}).append("\\n")};return b.toString()}
    private fun scalar(sql:String,args:Array<String> = emptyArray()):Double=readableDatabase.rawQuery(sql,args).use{if(it.moveToFirst())it.getDouble(0)else 0.0}
    private fun count(sql:String,args:Array<String> = emptyArray()):Int=readableDatabase.rawQuery(sql,args).use{if(it.moveToFirst())it.getInt(0)else 0}
    private fun today()=LocalDate.now().toString()
    private fun csv(s:String)=s.replace("\"","\"\"")
    private fun dpStatus(days:Int?)=when{days==null->"NEVER DP";days<=3->"ACTIVE";days<=7->"FOLLOW-UP";days<=14->"INACTIVE";days<=29->"LONG INACTIVE";else->"VERY LONG INACTIVE"}
}
data class User(val id:Long,val name:String,val number:String,val firstAdded:String,val notes:String,val doNotContact:Boolean=false,val onboardingType:String="previous",val lastDp:String?=null,val daysSince:Int?=null,val activityStatus:String="NEVER DP",val lifecycleStatus:String="ACTIVE",val totalDp:Double=0.0,val totalBonus:Double=0.0)
data class Preferences(val sports:String,val teams:String,val players:String,val competitions:String,val language:String,val channel:String,val window:String,val frequency:String,val contactOptIn:Boolean,val eventOptIn:Boolean)
data class DpRecord(val id:Long,val date:String,val amounts:List<Double?>)
data class BonusRecord(val id:Long,val userId:Long,val userName:String,val date:String,val amount:Double,val relatedDp:Double?,val reason:String,val notes:String)
data class ContactRecord(val id:Long,val userId:Long,val userName:String,val date:String,val status:String,val reason:String,val channel:String,val followUp:String,val notes:String)
data class SummaryRow(val date:String,val total:Double,val entries:Int,val users:Int)
data class ReportUser(val user:User,val dp:Double,val count:Int,val bonus:Double,val everDp:Boolean)
data class MatchEvent(val id:Long,val sport:String,val competition:String,val home:String,val away:String,val date:String,val time:String,val notes:String,val source:String="manual")
data class ReminderGroup(val event:MatchEvent,val users:List<User>)
