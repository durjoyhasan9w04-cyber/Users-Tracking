package com.userhub.tracker

import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.Instant
import java.time.LocalDate
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZoneOffset\nimport android.os.Handler\nimport android.os.Looper
import java.time.format.DateTimeFormatter

object FixtureSync {
    private val lock=Any()
    @Volatile private var running=false
    private val bdZone=ZoneId.of("Asia/Dhaka")
    private val sports=mapOf("Cricket" to "cricket","Football" to "football","Tennis" to "tennis")
    private val openLiga=listOf("bl1","pl","es1","it1","fr1","cl","el")

    fun start(db:TrackerDb,onFinished:(String,String)->Unit={}){
        synchronized(lock){if(running){onFinished("running","A fixture refresh is already running");return};running=true}
        db.saveSyncState("running","Worldwide fixture refresh started")
        Thread{
            var total=0
            try{
                val selected=db.users().mapNotNull{db.preferences(it.id)}.flatMap{it.sports.split(",")}.map{it.trim().lowercase()}.toSet()
                val today=LocalDate.now(bdZone)
                val days=(0..7).map{today.plusDays(it.toLong())}
                for((label,slug) in sports){
                    if(label.lowercase() !in selected)continue
                    for(day in days){
                        if(db.isFixtureCached(slug,day.toString(),"sportscore",8))continue
                        try{
                            val query="sport=$slug&date=$day&status=upcoming&limit=200"
                            val root=JSONObject(get("https://sportscore.com/api/v1/fixtures/?$query"))
                            val rows=root.optJSONArray("fixtures")?:root.optJSONArray("data")?:root.optJSONArray("matches")?:JSONArray()
                            for(i in 0 until rows.length()){
                                val f=rows.optJSONObject(i)?:continue
                                val dt=parseDate(value(f,"startsAt","startTime","dateTime","strTimestamp","timestamp"))?:continue
                                if(dt.toLocalDate()<today)continue
                                val status=value(f,"status","state").orEmpty().lowercase()
                                if(listOf("finished","complete","cancel","postponed").any{status.contains(it)})continue
                                val home=team(valueObject(f,"home","homeTeam","teamHome")?:f.opt("home"))?: "TBA"
                                val away=team(valueObject(f,"away","awayTeam","teamAway")?:f.opt("away")).orEmpty()
                                val comp=team(valueObject(f,"competition","tournament","league"))?:value(f,"competitionName","leagueName").orEmpty()
                                val id=value(f,"id","fixtureId","matchId")?:continue
                                db.addMatch(label,comp,home,away,dt.toLocalDate().toString(),dt.format(DateTimeFormatter.ofPattern("HH:mm")),"Worldwide fixture feed · SportScore","sportscore","sportscore:$id")
                                total++
                            }
                            db.markFixtureCached(slug,day.toString(),"sportscore")
                        }catch(e:Exception){db.saveSyncState("running","SportScore $label $day: ${e.message?.take(100)?: "provider unavailable"}")}
                        Thread.sleep(350)
                    }
                }
                total+=importOpenLiga(db,today)
                total+=importTeamEvents(db,today)
                db.saveSyncState("done","Refresh finished · $total fixtures added or updated. Provider coverage is best-effort; verify important fixtures.")
                Handler(Looper.getMainLooper()).post{onFinished("done","Refresh finished · $total fixtures added or updated")}
            }catch(e:Exception){
                val msg="Fixture refresh stopped: ${e.message?.take(180)?: "network error"}"
                db.saveSyncState("error",msg);Handler(Looper.getMainLooper()).post{onFinished("error",msg)}
            }finally{synchronized(lock){running=false}}
        }.start()
    }

    private fun importOpenLiga(db:TrackerDb,today:LocalDate):Int{
        var total=0
        val year=today.year
        for(league in openLiga){
            try{
                val rows=JSONArray(get("https://api.openligadb.de/getmatches/$league/$year"))
                for(i in 0 until rows.length()){
                    val f=rows.optJSONObject(i)?:continue
                    val dt=parseDate(f.optString("matchDateTimeUTC"))?:continue
                    if(dt.toLocalDate()<today||dt.toLocalDate()>today.plusDays(7))continue
                    val home=f.optJSONObject("team1")?.optString("teamName").orEmpty().ifBlank{"TBA"}
                    val away=f.optJSONObject("team2")?.optString("teamName").orEmpty().ifBlank{"TBA"}
                    val id=f.optString("matchID");if(id.isBlank())continue
                    db.addMatch("Football",f.optString("leagueName",league),home,away,dt.toLocalDate().toString(),dt.format(DateTimeFormatter.ofPattern("HH:mm")),"Fixture from OpenLigaDB · Bangladesh time","openligadb","openligadb:$id")
                    total++
                }
            }catch(_:Exception){}
        }
        return total
    }

    private fun importTeamEvents(db:TrackerDb,today:LocalDate):Int{
        var total=0
        val teams=linkedMapOf<String,String>()
        db.users().forEach{u->val p=db.preferences(u.id)?:return@forEach
            if(p.sports.split(",").any{it.trim().equals("football",true)||it.trim().equals("cricket",true)||it.trim().equals("tennis",true)})
                p.teams.split(",").map{it.trim()}.filter{it.isNotBlank()}.forEach{teams.putIfAbsent(it,p.sports.split(",").firstOrNull()?.trim()?: "Football")}
        }
        for((name,sport) in teams.entries.take(30)){
            if(db.isFixtureCached(name.lowercase(),"team","thesportsdb",12))continue
            try{
                Thread.sleep(2100)
                val search=JSONObject(get("https://www.thesportsdb.com/api/v1/json/123/searchteams.php?t="+enc(name)))
                val list=search.optJSONArray("teams")?:continue
                val teamId=list.optJSONObject(0)?.optString("idTeam")?.takeIf{it.isNotBlank()}?:continue
                Thread.sleep(2100)
                val next=JSONObject(get("https://www.thesportsdb.com/api/v1/json/123/eventsnext.php?id=$teamId"))
                val events=next.optJSONArray("events")?:JSONArray()
                for(i in 0 until events.length()){
                    val f=events.optJSONObject(i)?:continue
                    val raw=f.optString("dateEvent").takeIf{it.isNotBlank()}?.let{d->f.optString("strTime").takeIf{it.isNotBlank()}?.let{t->"${d}T${t}Z"}?:d}?:continue
                    val dt=parseDate(raw)?:continue
                    if(dt.toLocalDate()<today)continue
                    val home=f.optString("strHomeTeam").ifBlank{"TBA"}
                    val away=f.optString("strAwayTeam")
                    val id=f.optString("idEvent");if(id.isBlank())continue
                    db.addMatch(sport,f.optString("strLeague"),home,away,dt.toLocalDate().toString(),dt.format(DateTimeFormatter.ofPattern("HH:mm")),"Fixture from TheSportsDB · Bangladesh time","thesportsdb","thesportsdb:$id")
                    total++
                }
                db.markFixtureCached(name.lowercase(),"team","thesportsdb")
            }catch(_:Exception){}
        }
        return total
    }

    private fun get(url:String):String{
        val connection=URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout=18000;connection.readTimeout=25000
        connection.setRequestProperty("Accept","application/json")
        connection.setRequestProperty("User-Agent","UserHubNative/2.0")
        return try{if(connection.responseCode !in 200..299)throw IllegalStateException("HTTP ${connection.responseCode}");connection.inputStream.bufferedReader().use{it.readText()}}finally{connection.disconnect()}
    }
    private fun enc(s:String)=URLEncoder.encode(s,"UTF-8")
    private fun value(o:JSONObject,vararg keys:String):String?{
        for(k in keys){val v=o.opt(k);if(v!=null&&v!=JSONObject.NULL){if(v is JSONObject){val nested=value(v,"name","title","shortName");if(!nested.isNullOrBlank())return nested}else if(v !is JSONArray){val s=v.toString();if(s.isNotBlank()&&s!="0")return s}}}
        return null
    }
    private fun valueObject(o:JSONObject,vararg keys:String):JSONObject?{for(k in keys){val v=o.optJSONObject(k);if(v!=null)return v};return null}
    private fun team(v:Any?):String?=when(v){is JSONObject->value(v,"name","title","shortName");is String->v.takeIf{it.isNotBlank()};else->null}
    private fun parseDate(raw:String?):java.time.ZonedDateTime?{
        if(raw.isNullOrBlank())return null
        return try{
            if(raw.all{it.isDigit()})Instant.ofEpochSecond(raw.toLong()).atZone(bdZone)
            else try{OffsetDateTime.parse(raw).atZoneSameInstant(bdZone)}catch(_:Exception){try{Instant.parse(raw).atZone(bdZone)}catch(_:Exception){LocalDate.parse(raw.take(10)).atStartOfDay(bdZone)}}
        }catch(_:Exception){null}
    }
}
