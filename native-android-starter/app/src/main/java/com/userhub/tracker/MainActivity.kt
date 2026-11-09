package com.userhub.tracker

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import java.util.Locale

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); val db = TrackerDb(this); setContent { MaterialTheme(colorScheme = darkColorScheme()) { UserHub(db) } } }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun UserHub(db: TrackerDb) {
    var tab by remember { mutableStateOf("Dashboard") }; var refresh by remember { mutableIntStateOf(0) }
    var users by remember { mutableStateOf(db.users()) }; var selected by remember { mutableStateOf<User?>(null) }
    fun reload() { users = db.users(); refresh++ }
    Scaffold(topBar = { TopAppBar(title = { Text("USER HUB · DP TRACKER") }) }) { pad ->
        Column(Modifier.padding(pad).fillMaxSize()) {
            ScrollableTabRow(selectedTabIndex = listOf("Dashboard","Users","Add User","Daily DP","Bonus","More").indexOf(tab).coerceAtLeast(0)) {
                listOf("Dashboard","Users","Add User","Daily DP","Bonus","More").forEach { t -> Tab(selected = tab==t, onClick={tab=t; selected=null}, text={Text(t)}) }
            }
            when(tab) {
                "Dashboard" -> Dashboard(db, users.size, refresh)
                "Users" -> UsersScreen(users, db, selected, { selected=it }, refresh)
                "Add User" -> AddUserScreen(db) { reload(); tab="Users" }
                "Daily DP" -> EntryScreen(users, "DP", { id, vals, checked, notes -> db.addDp(id, vals, checked, notes); reload() })
                "Bonus" -> BonusScreen(users, db) { reload() }
                else -> MoreScreen(users, refresh)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable fun Dashboard(db: TrackerDb, count: Int, refresh: Int) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement=Arrangement.spacedBy(12.dp)) {
        Text("Daily overview", style=MaterialTheme.typography.headlineMedium)
        Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) { Metric("Total users", count.toString(), Modifier.weight(1f)); Metric("Today's DP", money(db.todayDp()), Modifier.weight(1f)) }
        Row(horizontalArrangement=Arrangement.spacedBy(8.dp)) { Metric("DP entries today", db.dpCountToday().toString(), Modifier.weight(1f)); Metric("Today's bonus", money(db.todayBonus()), Modifier.weight(1f)) }
        Metric("All-time DP", money(db.totalDp()), Modifier.fillMaxWidth())
        Text("Your data is stored locally on this phone.", color=MaterialTheme.colorScheme.secondary)
    }
}
@Composable fun Metric(label:String, value:String, modifier:Modifier=Modifier) { Card(modifier) { Column(Modifier.padding(16.dp)) { Text(label, style=MaterialTheme.typography.labelMedium); Text(value, style=MaterialTheme.typography.headlineSmall) } } }
@Composable fun AddUserScreen(db:TrackerDb, done:()->Unit) {
    var name by remember { mutableStateOf("") }; var number by remember { mutableStateOf("") }; var notes by remember { mutableStateOf("") }; var error by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement=Arrangement.spacedBy(12.dp)) {
        Text("Add user", style=MaterialTheme.typography.headlineMedium)
        OutlinedTextField(name,{name=it},label={Text("Name *")},modifier=Modifier.fillMaxWidth())
        OutlinedTextField(number,{number=it},label={Text("Phone number")},modifier=Modifier.fillMaxWidth())
        OutlinedTextField(notes,{notes=it},label={Text("Notes")},modifier=Modifier.fillMaxWidth())
        if(error.isNotBlank()) Text(error,color=MaterialTheme.colorScheme.error)
        Button(onClick={ if(name.isBlank()) error="Enter a name" else { db.addUser(name,number,notes); done() } },modifier=Modifier.fillMaxWidth()) { Text("Save user") }
    }
}
@Composable fun UsersScreen(users:List<User>, db:TrackerDb, selected:User?, choose:(User?)->Unit, refresh:Int) {
    var query by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().padding(12.dp)) {
        OutlinedTextField(query,{query=it},label={Text("Search name or number")},modifier=Modifier.fillMaxWidth())
        if(selected!=null) { val totals=db.profileTotals(selected.id); Text(selected.name,style=MaterialTheme.typography.headlineSmall); Text(selected.number); Text("First added: ${selected.firstAdded}"); Text("Historical DP: ${money(totals.first)}"); Text("Historical bonus: ${money(totals.second)}"); Text(selected.notes); TextButton(onClick={choose(null)}){Text("Back to users")} }
        else LazyColumn { items(users.filter { it.name.contains(query,true)||it.number.contains(query,true) }) { u -> Card(Modifier.fillMaxWidth().padding(vertical=4.dp),onClick={choose(u)}) { Column(Modifier.padding(14.dp)) { Text(u.name,style=MaterialTheme.typography.titleMedium); Text(u.number,color=MaterialTheme.colorScheme.secondary) } } } }
    }
}
@Composable fun EntryScreen(users:List<User>, label:String, save:(Long,List<Double?>,Boolean,String)->Unit) {
    var uid by remember { mutableStateOf(users.firstOrNull()?.id?.toString() ?: "") }; var amount by remember { mutableStateOf(List(5){""}) }; var contacted by remember { mutableStateOf(false) }; var notes by remember { mutableStateOf("") }; var message by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
        Text("Daily DP entry",style=MaterialTheme.typography.headlineMedium)
        if(users.isEmpty()) Text("Add a user first.") else {
            var expanded by remember { mutableStateOf(false) }; val chosen=users.firstOrNull{it.id.toString()==uid} ?: users.first()
            ExposedDropdownMenuBox(expanded=expanded,onExpandedChange={expanded=it}) { OutlinedTextField(value=chosen.name,onValueChange={},readOnly=true,label={Text("User")},modifier=Modifier.menuAnchor().fillMaxWidth()); ExposedDropdownMenu(expanded=expanded,onDismissRequest={expanded=false}) { users.forEach { DropdownMenuItem(text={Text(it.name)},onClick={uid=it.id.toString();expanded=false}) } } }
            amount.forEachIndexed { i,v -> OutlinedTextField(v,{s->amount=amount.toMutableList().also{it[i]=s}},label={Text("DP ${i+1} (coins)")},modifier=Modifier.fillMaxWidth()) }
            Row { Checkbox(contacted,{contacted=it}); Text("Contacted today",Modifier.padding(top=12.dp)) }
            OutlinedTextField(notes,{notes=it},label={Text("Contact notes")},modifier=Modifier.fillMaxWidth())
            Button(onClick={ val parsed=amount.map{it.trim().takeIf(String::isNotEmpty)?.toDoubleOrNull()}; if(parsed.any{it!=null && it<0}) message="Amounts cannot be negative" else if(parsed.all{it==null}) message="Enter at least one DP amount" else { save(chosen.id,parsed,contacted,notes); message="DP saved"; amount=List(5){""}; notes="" } },modifier=Modifier.fillMaxWidth()) { Text("Save DP entry") }
            Text(message)
        }
    }
}
@Composable fun BonusScreen(users:List<User>, db:TrackerDb, done:()->Unit) {
    var uid by remember { mutableStateOf(users.firstOrNull()?.id?.toString() ?: "") }; var amount by remember { mutableStateOf("") }; var reason by remember { mutableStateOf("Deposit") }; var notes by remember { mutableStateOf("") }; var message by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) {
        Text("Add bonus",style=MaterialTheme.typography.headlineMedium)
        if(users.isEmpty()) Text("Add a user first.") else {
            var expanded by remember { mutableStateOf(false) }; val chosen=users.firstOrNull{it.id.toString()==uid} ?: users.first()
            ExposedDropdownMenuBox(expanded=expanded,onExpandedChange={expanded=it}) { OutlinedTextField(value=chosen.name,onValueChange={},readOnly=true,label={Text("User")},modifier=Modifier.menuAnchor().fillMaxWidth()); ExposedDropdownMenu(expanded=expanded,onDismissRequest={expanded=false}) { users.forEach { DropdownMenuItem(text={Text(it.name)},onClick={uid=it.id.toString();expanded=false}) } } }
            OutlinedTextField(amount,{amount=it},label={Text("Bonus amount")},modifier=Modifier.fillMaxWidth())
            var reasonOpen by remember { mutableStateOf(false) }; ExposedDropdownMenuBox(expanded=reasonOpen,onExpandedChange={reasonOpen=it}) { OutlinedTextField(value=reason,onValueChange={},readOnly=true,label={Text("Reason")},modifier=Modifier.menuAnchor().fillMaxWidth()); ExposedDropdownMenu(expanded=reasonOpen,onDismissRequest={reasonOpen=false}) { listOf("Deposit","Special","Promotional","Other").forEach{DropdownMenuItem(text={Text(it)},onClick={reason=it;reasonOpen=false})} } }
            OutlinedTextField(notes,{notes=it},label={Text("Notes")},modifier=Modifier.fillMaxWidth())
            Button(onClick={val n=amount.toDoubleOrNull(); if(n==null||n<0) message="Enter a valid amount" else {db.addBonus(chosen.id,n,reason,notes);message="Bonus saved";amount="";notes="";done()}},modifier=Modifier.fillMaxWidth()){Text("Save bonus")}; Text(message)
        }
    }
}
@Composable fun MoreScreen(users:List<User>, refresh:Int) { Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),verticalArrangement=Arrangement.spacedBy(10.dp)) { Text("More features",style=MaterialTheme.typography.headlineMedium); listOf("DP & bonus history","Contact log and follow-ups","Sports interests and preferences","Match calendar and manual reminders","Monthly reports and CSV export","Database backup and restore").forEach { Card(Modifier.fillMaxWidth()) { Text(it+" · planned for next build",Modifier.padding(16.dp)) } }; Text("These sections are not implemented in this first native build. Keep using your existing web app for these workflows until the next release.",color=MaterialTheme.colorScheme.error) } }
fun money(v:Double) = "${String.format(Locale.US,"%.2f",v)} coins"
