package com.userhub.tracker

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.Locale

private val Ink = Color(0xFF080D1B)
private val Panel = Color(0xFF151D31)
private val PanelLight = Color(0xFF202B45)
private val Cyan = Color(0xFF68E1E8)
private val Violet = Color(0xFF9B8CFF)
private val Muted = Color(0xFF9AA8C2)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val db = TrackerDb(this)
        window.statusBarColor = android.graphics.Color.rgb(8,13,27)
        window.navigationBarColor = android.graphics.Color.rgb(8,13,27)
        setContent { UserHubApp(db) }
    }
}

@Composable
fun UserHubApp(db: TrackerDb) {
    var tab by remember { mutableStateOf("Home") }
    var refresh by remember { mutableIntStateOf(0) }
    var users by remember { mutableStateOf(db.users()) }
    var selectedUser by remember { mutableStateOf<User?>(null) }
    fun reload() { users = db.users(); refresh++ }
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Cyan, secondary = Violet, background = Ink, surface = Panel,
            onBackground = Color.White, onSurface = Color.White, onPrimary = Ink
        )
    ) {
        Scaffold(
            containerColor = Ink,
            topBar = {
                Row(Modifier.fillMaxWidth().background(Ink).padding(horizontal = 20.dp, vertical = 15.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(38.dp).clip(RoundedCornerShape(13.dp)).background(Brush.linearGradient(listOf(Cyan, Violet))), contentAlignment = Alignment.Center) {
                        Icon(Icons.Outlined.Hub, null, tint = Ink)
                    }
                    Spacer(Modifier.width(11.dp))
                    Column(Modifier.weight(1f)) {
                        Text("USER HUB", fontWeight = FontWeight.ExtraBold, letterSpacing = 2.sp, fontSize = 15.sp)
                        Text("DP MANAGEMENT", color = Muted, fontSize = 10.sp, letterSpacing = 1.5.sp)
                    }
                    Box(Modifier.size(36.dp).clip(CircleShape).background(PanelLight), contentAlignment = Alignment.Center) {
                        Icon(Icons.Outlined.Person, null, tint = Cyan, modifier = Modifier.size(19.dp))
                    }
                }
            },
            bottomBar = {
                NavigationBar(containerColor = Color(0xFF10182A), contentColor = Muted) {
                    val items = listOf(Triple("Home", Icons.Outlined.SpaceDashboard, "Home"), Triple("Users", Icons.Outlined.Groups, "Users"), Triple("DP", Icons.Outlined.AddCircle, "DP"), Triple("Bonus", Icons.Outlined.CardGiftcard, "Bonus"), Triple("More", Icons.Outlined.GridView, "More"))
                    items.forEach { (label, icon, value) ->
                        NavigationBarItem(selected = tab == value, onClick = { tab = value; selectedUser = null }, icon = { Icon(icon, null) }, label = { Text(label, fontSize = 10.sp) }, colors = NavigationBarItemDefaults.colors(selectedIconColor = Cyan, selectedTextColor = Cyan, indicatorColor = Color(0xFF26364B), unselectedIconColor = Muted, unselectedTextColor = Muted))
                    }
                }
            }
        ) { padding ->
            Box(Modifier.fillMaxSize().padding(padding)) {
                when (tab) {
                    "Home" -> DashboardScreen(db, users.size, refresh, onGo = { tab = it })
                    "Users" -> UsersPage(users, db, selectedUser, { selectedUser = it }, refresh, onChanged = { reload() })
                    "DP" -> DpPage(users, db) { reload() }
                    "Bonus" -> BonusPage(users, db) { reload() }
                    else -> MorePage(users, db, refresh, onChanged = { reload() }, onGo = { tab = it })
                }
            }
        }
    }
}

@Composable
fun GlassCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier.clip(RoundedCornerShape(22.dp)).background(Brush.linearGradient(listOf(Color(0xFF1B2941), Color(0xFF111A2D)))).border(1.dp, Color(0xFF34425B).copy(alpha=.65f), RoundedCornerShape(22.dp)).padding(16.dp), content = content)
}
@Composable
fun PageTitle(title: String, subtitle: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(title, fontSize = 25.sp, fontWeight = FontWeight.Bold, color = Color.White)
        Text(subtitle, fontSize = 12.sp, color = Muted)
    }
}
@Composable
fun MetricTile(label: String, value: String, icon: androidx.compose.ui.graphics.vector.ImageVector, accent: Color, modifier: Modifier = Modifier) {
    GlassCard(modifier) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(34.dp).clip(RoundedCornerShape(11.dp)).background(accent.copy(alpha=.15f)), contentAlignment = Alignment.Center) { Icon(icon, null, tint = accent, modifier = Modifier.size(18.dp)) }
            Spacer(Modifier.width(8.dp))
            Text(label, color = Muted, fontSize = 11.sp)
        }
        Spacer(Modifier.height(12.dp))
        Text(value, fontSize = 21.sp, fontWeight = FontWeight.Bold, color = Color.White)
    }
}
@Composable
fun DashboardScreen(db: TrackerDb, count: Int, refresh: Int, onGo: (String) -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(18.dp), verticalArrangement = Arrangement.spacedBy(15.dp)) {
        PageTitle("Good day, Operator", "Your workspace at a glance")
        GlassCard(Modifier.fillMaxWidth()) {
            Text("TODAY'S PERFORMANCE", color = Cyan, fontSize = 10.sp, letterSpacing = 1.5.sp, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(8.dp))
            Text(money(db.todayDp()), fontSize = 32.sp, fontWeight = FontWeight.ExtraBold)
            Text("DP recorded today", color = Muted, fontSize = 12.sp)
            Spacer(Modifier.height(14.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                MiniStat("DP entries", db.dpCountToday().toString())
                MiniStat("Multi-DP users", db.usersWithMultipleDpToday().toString())
                MiniStat("Contacted", db.contactedToday().toString())
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            MetricTile("Total users", count.toString(), Icons.Outlined.Groups, Cyan, Modifier.weight(1f))
            MetricTile("Today's bonus", money(db.todayBonus()), Icons.Outlined.CardGiftcard, Violet, Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            MetricTile("This month DP", money(db.monthDp()), Icons.Outlined.TrendingUp, Color(0xFF77D6A5), Modifier.weight(1f))
            MetricTile("This month bonus", money(db.monthBonus()), Icons.Outlined.Stars, Color(0xFFFFC778), Modifier.weight(1f))
        }
        Text("QUICK ACTIONS", color = Muted, fontSize = 10.sp, letterSpacing = 1.5.sp, fontWeight = FontWeight.Bold)
        Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
            QuickAction("Add user", Icons.Outlined.PersonAdd, Cyan) { onGo("Users") }
            QuickAction("Daily DP", Icons.Outlined.AddCircle, Violet) { onGo("DP") }
            QuickAction("Add bonus", Icons.Outlined.CardGiftcard, Color(0xFFFFC778)) { onGo("Bonus") }
        }
        GlassCard(Modifier.fillMaxWidth()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) { Text("Follow-up queue", fontWeight = FontWeight.SemiBold); Text("Users who may need review", color = Muted, fontSize = 11.sp) }
                TextButton(onClick = { onGo("Follow-ups") }) { Text("View all", color = Cyan) }
            }
            val follow = db.followUpUsers().take(3)
            if (follow.isEmpty()) Text("No follow-ups right now.", color = Muted, fontSize = 12.sp)
            follow.forEach { (u,s) -> Row(Modifier.fillMaxWidth().padding(vertical=5.dp), verticalAlignment = Alignment.CenterVertically) { Text(u.name, Modifier.weight(1f), fontWeight = FontWeight.Medium); Text(s, color = Violet, fontSize = 10.sp) } }
        }
        Text("Stored privately on this device · SQLite", color = Muted, fontSize = 10.sp)
    }
}
@Composable
fun MiniStat(label: String, value: String) { Column { Text(value, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 17.sp); Text(label, color = Muted, fontSize = 10.sp) } }
@Composable
fun QuickAction(label: String, icon: androidx.compose.ui.graphics.vector.ImageVector, color: Color, click: () -> Unit) {
    Column(Modifier.width(100.dp).clip(RoundedCornerShape(18.dp)).background(Panel).border(1.dp, Color(0xFF34425B), RoundedCornerShape(18.dp)).clickable { click() }.padding(vertical=15.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Icon(icon, null, tint = color, modifier = Modifier.size(22.dp)); Spacer(Modifier.height(7.dp)); Text(label, fontSize = 10.sp, color = Color.White, fontWeight = FontWeight.Medium)
    }
}

@Composable
fun UsersPage(users: List<User>, db: TrackerDb, selected: User?, choose: (User?) -> Unit, refresh: Int, onChanged: () -> Unit) {
    var query by remember { mutableStateOf("") }
    var addOpen by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().padding(17.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (selected != null) {
            TextButton(onClick = { choose(null) }) { Icon(Icons.Outlined.ArrowBack, null); Text("  All users") }
            PageTitle(selected.name, selected.number.ifBlank { "No phone number" })
            val totals = db.profileTotals(selected.id)
            Row(horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                MetricTile("Lifetime DP", money(totals.first), Icons.Outlined.TrendingUp, Cyan, Modifier.weight(1f))
                MetricTile("Lifetime bonus", money(totals.second), Icons.Outlined.CardGiftcard, Violet, Modifier.weight(1f))
            }
            GlassCard(Modifier.fillMaxWidth()) {
                Text("PROFILE DETAILS", color = Cyan, fontSize = 10.sp, fontWeight = FontWeight.Bold)
                ProfileLine("First added", selected.firstAdded)
                ProfileLine("Last DP", db.lastDp(selected.id) ?: "Never")
                ProfileLine("Notes", selected.notes.ifBlank { "No notes" })
            }
            Text("DP & bonus totals are calculated from local transaction history.", color = Muted, fontSize = 11.sp)
        } else {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) { PageTitle("Users", "${users.size} profiles in your workspace") }
                Button(onClick = { addOpen = true }, colors = ButtonDefaults.buttonColors(containerColor = Cyan, contentColor = Ink), shape = RoundedCornerShape(14.dp)) { Icon(Icons.Outlined.Add, null); Text(" Add") }
            }
            OutlinedTextField(query, { query = it }, modifier = Modifier.fillMaxWidth(), placeholder = { Text("Search name or phone") }, leadingIcon = { Icon(Icons.Outlined.Search, null) }, singleLine = true, shape = RoundedCornerShape(16.dp), colors = fieldColors())
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(users.filter { it.name.contains(query,true) || it.number.contains(query,true) }) { u ->
                    GlassCard(Modifier.fillMaxWidth().clickable { choose(u) }) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(Modifier.size(40.dp).clip(CircleShape).background(Color(0xFF283953)), contentAlignment = Alignment.Center) { Text(u.name.take(1).uppercase(), color = Cyan, fontWeight = FontWeight.Bold) }
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) { Text(u.name, fontWeight = FontWeight.SemiBold); Text(u.number.ifBlank { "No number" }, color = Muted, fontSize = 11.sp) }
                            Icon(Icons.Outlined.ChevronRight, null, tint = Muted)
                        }
                    }
                }
            }
        }
    }
    if (addOpen) AddUserDialog(onDismiss = { addOpen = false }, onSave = { n,p,note -> val id=db.addUser(n,p,note); addOpen=false; onChanged(); if(id==-1L) Unit })
}
@Composable
fun ProfileLine(label: String, value: String) { Row(Modifier.fillMaxWidth().padding(top=10.dp), horizontalArrangement = Arrangement.SpaceBetween) { Text(label, color=Muted, fontSize=12.sp); Text(value, color=Color.White, fontSize=12.sp) } }
@Composable
fun AddUserDialog(onDismiss: () -> Unit, onSave: (String,String,String) -> Unit) {
    var name by remember { mutableStateOf("") }; var phone by remember { mutableStateOf("") }; var notes by remember { mutableStateOf("") }
    AlertDialog(onDismissRequest=onDismiss, containerColor=Panel, title={ Text("Add new user") }, text={
        Column(verticalArrangement=Arrangement.spacedBy(9.dp)) {
            OutlinedTextField(name,{name=it},label={Text("Name *")},singleLine=true,colors=fieldColors())
            OutlinedTextField(phone,{phone=it},label={Text("Phone number")},singleLine=true,colors=fieldColors())
            OutlinedTextField(notes,{notes=it},label={Text("Notes")},colors=fieldColors())
        }
    }, confirmButton={ TextButton(onClick={ if(name.isNotBlank()) onSave(name,phone,notes) }) { Text("Save",color=Cyan) } }, dismissButton={ TextButton(onClick=onDismiss) { Text("Cancel") } })
}

@Composable
fun DpPage(users: List<User>, db: TrackerDb, onSaved: () -> Unit) {
    var userId by remember { mutableStateOf(users.firstOrNull()?.id?.toString() ?: "") }
    var amounts by remember { mutableStateOf(List(5){""}) }
    var contacted by remember { mutableStateOf(false) }; var notes by remember { mutableStateOf("") }; var message by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(17.dp), verticalArrangement=Arrangement.spacedBy(12.dp)) {
        PageTitle("Daily DP entry", "Record today's DP transaction")
        if(users.isEmpty()) GlassCard(Modifier.fillMaxWidth()){ Text("Add a user before recording DP.",color=Muted) } else {
            val chosen = users.firstOrNull{it.id.toString()==userId} ?: users.first()
            UserPicker(users,chosen){userId=it.id.toString()}
            GlassCard(Modifier.fillMaxWidth()) {
                Text("DP AMOUNTS", color=Cyan, fontSize=10.sp, letterSpacing=1.4.sp, fontWeight=FontWeight.Bold)
                amounts.forEachIndexed { i,v -> OutlinedTextField(v,{s->amounts=amounts.toMutableList().also{it[i]=s}},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("DP ${i+1} · coins")},singleLine=true,colors=fieldColors()) }
                val total = amounts.mapNotNull{it.toDoubleOrNull()}.sum()
                Row(Modifier.fillMaxWidth().padding(top=12.dp),horizontalArrangement=Arrangement.SpaceBetween){ Text("Calculated total",color=Muted); Text(money(total),fontWeight=FontWeight.Bold,color=Cyan) }
            }
            GlassCard(Modifier.fillMaxWidth()) {
                Row(verticalAlignment=Alignment.CenterVertically){ Checkbox(contacted,{contacted=it},colors=CheckboxDefaults.colors(checkedColor=Cyan)); Text("Contacted today") }
                OutlinedTextField(notes,{notes=it},modifier=Modifier.fillMaxWidth(),label={Text("Contact notes")},colors=fieldColors())
            }
            Button(onClick={
                val parsed=amounts.map{it.trim().takeIf{v->v.isNotEmpty()}?.toDoubleOrNull()}
                when {
                    amounts.any{it.isNotBlank() && it.toDoubleOrNull()==null} -> message="Check the amount format"
                    parsed.any{it!=null && it<0} -> message="Amounts cannot be negative"
                    parsed.all{it==null} -> message="Enter at least one DP amount"
                    else -> { db.addDp(chosen.id,parsed,contacted,notes); message="DP entry saved"; amounts=List(5){""}; notes=""; contacted=false; onSaved() }
                }
            },modifier=Modifier.fillMaxWidth(),colors=ButtonDefaults.buttonColors(containerColor=Cyan,contentColor=Ink),shape=RoundedCornerShape(15.dp)){Text("Save daily DP",fontWeight=FontWeight.Bold)}
            if(message.isNotBlank()) Text(message,color=Cyan,fontSize=12.sp)
        }
    }
}

@Composable
fun BonusPage(users: List<User>, db: TrackerDb, onSaved: () -> Unit) {
    var userId by remember { mutableStateOf(users.firstOrNull()?.id?.toString() ?: "") }; var amount by remember{mutableStateOf("")}; var reason by remember{mutableStateOf("Deposit")}; var notes by remember{mutableStateOf("")}; var message by remember{mutableStateOf("")}
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(17.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
        PageTitle("Add bonus","Keep bonus records separate from DP")
        if(users.isEmpty()) Text("Add a user first.",color=Muted) else {
            val chosen=users.firstOrNull{it.id.toString()==userId}?:users.first()
            UserPicker(users,chosen){userId=it.id.toString()}
            GlassCard(Modifier.fillMaxWidth()) {
                OutlinedTextField(amount,{amount=it},modifier=Modifier.fillMaxWidth(),label={Text("Bonus amount · coins")},singleLine=true,colors=fieldColors())
                Spacer(Modifier.height(10.dp))
                Text("BONUS REASON",color=Muted,fontSize=10.sp)
                Row(horizontalArrangement=Arrangement.spacedBy(6.dp)) { listOf("Deposit","Special","Promotional","Other").forEach { r -> FilterChip(selected=reason==r,onClick={reason=r},label={Text(r)},colors=FilterChipDefaults.filterChipColors(selectedContainerColor=Color(0xFF34405B),selectedLabelColor=Cyan)) } }
                OutlinedTextField(notes,{notes=it},modifier=Modifier.fillMaxWidth().padding(top=10.dp),label={Text("Notes")},colors=fieldColors())
            }
            Button(onClick={val n=amount.toDoubleOrNull(); if(n==null||n<0) message="Enter a valid amount" else {db.addBonus(chosen.id,n,reason,notes); amount="";notes="";message="Bonus saved";onSaved()}},modifier=Modifier.fillMaxWidth(),colors=ButtonDefaults.buttonColors(containerColor=Violet,contentColor=Ink),shape=RoundedCornerShape(15.dp)){Text("Save bonus",fontWeight=FontWeight.Bold)}
            Text(message,color=Cyan,fontSize=12.sp)
        }
    }
}
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UserPicker(users: List<User>, selected: User, onSelect:(User)->Unit) {
    var expanded by remember{mutableStateOf(false)}
    ExposedDropdownMenuBox(expanded=expanded,onExpandedChange={expanded=it}) {
        OutlinedTextField(value=selected.name,onValueChange={},readOnly=true,label={Text("Select user")},modifier=Modifier.menuAnchor().fillMaxWidth(),trailingIcon={ExposedDropdownMenuDefaults.TrailingIcon(expanded)},colors=fieldColors())
        ExposedDropdownMenu(expanded=expanded,onDismissRequest={expanded=false}) { users.forEach{u->DropdownMenuItem(text={Text(u.name)},onClick={onSelect(u);expanded=false})} }
    }
}

@Composable
fun MorePage(users: List<User>, db: TrackerDb, refresh: Int, onChanged:()->Unit, onGo:(String)->Unit) {
    var section by remember{mutableStateOf("More")}
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(17.dp),verticalArrangement=Arrangement.spacedBy(12.dp)) {
        when(section) {
            "More" -> {
                PageTitle("Workspace","History, follow-ups and tools")
                listOf("Follow-ups" to Icons.Outlined.NotificationsActive,"Reports" to Icons.Outlined.BarChart,"Sports interests" to Icons.Outlined.SportsSoccer,"Match calendar" to Icons.Outlined.CalendarMonth,"Backup & settings" to Icons.Outlined.Settings).forEach{(label,icon)->
                    GlassCard(Modifier.fillMaxWidth().clickable{section=label}){Row(verticalAlignment=Alignment.CenterVertically){Icon(icon,null,tint=Cyan);Spacer(Modifier.width(12.dp));Text(label,Modifier.weight(1f),fontWeight=FontWeight.SemiBold);Icon(Icons.Outlined.ChevronRight,null,tint=Muted)}}
                }
                Text("Local-first · No Telegram · No paid cloud service",color=Muted,fontSize=10.sp)
            }
            "Follow-ups" -> {
                Row(verticalAlignment=Alignment.CenterVertically){TextButton(onClick={section="More"}){Text("‹ Back",color=Cyan)};PageTitle("Follow-ups","Users grouped by last DP date")}
                db.followUpUsers().forEach{(u,status)->GlassCard(Modifier.fillMaxWidth()){Text(u.name,fontWeight=FontWeight.SemiBold);Text(status,color=Violet,fontSize=11.sp);Text(u.number,color=Muted,fontSize=10.sp)}}
            }
            "Reports" -> {
                Row(verticalAlignment=Alignment.CenterVertically){TextButton(onClick={section="More"}){Text("‹ Back",color=Cyan)};PageTitle("Monthly report","Current month · transaction dates")}
                Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){MetricTile("DP",money(db.monthDp()),Icons.Outlined.TrendingUp,Cyan,Modifier.weight(1f));MetricTile("Bonus",money(db.monthBonus()),Icons.Outlined.CardGiftcard,Violet,Modifier.weight(1f))}
                db.monthSummary().forEach{r->GlassCard(Modifier.fillMaxWidth()){Row(horizontalArrangement=Arrangement.SpaceBetween,modifier=Modifier.fillMaxWidth()){Text(r.date,fontWeight=FontWeight.SemiBold);Text(money(r.total),color=Cyan)};Text("${r.entries} DP entries",color=Muted,fontSize=11.sp)}}
            }
            "Sports interests" -> {
                Row(verticalAlignment=Alignment.CenterVertically){TextButton(onClick={section="More"}){Text("‹ Back",color=Cyan)};PageTitle("Sports interests","Save a user's preferred sports and teams")}
                SportsPreferences(users,db)
            }
            "Match calendar" -> {
                Row(verticalAlignment=Alignment.CenterVertically){TextButton(onClick={section="More"}){Text("‹ Back",color=Cyan)};PageTitle("Match calendar","Manual fixture list and reminders")}
                MatchEditor(db)
                db.upcomingMatches().forEach{m->GlassCard(Modifier.fillMaxWidth()){Text("${m.home} vs ${m.away}",fontWeight=FontWeight.Bold);Text("${m.sport} · ${m.competition}",color=Muted,fontSize=11.sp);Text("${m.date}  ${m.time}",color=Cyan,fontSize=12.sp)}}
                Text("Fixture discovery is not automated in this build. Add or verify fixtures manually.",color=Muted,fontSize=10.sp)
            }
            else -> {
                Row(verticalAlignment=Alignment.CenterVertically){TextButton(onClick={section="More"}){Text("‹ Back",color=Cyan)};PageTitle("Backup & settings","Keep your local data safe")}
                GlassCard(Modifier.fillMaxWidth()){Text("Your data is stored in tracker.db on this phone.",color=Color.White);Spacer(Modifier.height(8.dp));Text("This build does not yet include a verified backup/restore export workflow. Do not uninstall the app before making a separate device backup.",color=Color(0xFFFFC778),fontSize=12.sp)}
            }
        }
    }
}

@Composable
fun SportsPreferences(users:List<User>,db:TrackerDb) {
    var uid by remember{mutableStateOf(users.firstOrNull()?.id?.toString()?: "")}; var sports by remember{mutableStateOf("Cricket, Football")};var teams by remember{mutableStateOf("")};var comps by remember{mutableStateOf("")};var language by remember{mutableStateOf("Bangla")};var message by remember{mutableStateOf("")}
    if(users.isEmpty()){Text("Add users first.",color=Muted);return}
    val chosen=users.firstOrNull{it.id.toString()==uid}?:users.first()
    UserPicker(users,chosen){uid=it.id.toString()}
    GlassCard(Modifier.fillMaxWidth()) {
        OutlinedTextField(sports,{sports=it},modifier=Modifier.fillMaxWidth(),label={Text("Sports (Cricket, Football, Kabaddi, Tennis, Badminton, Esports)")},colors=fieldColors())
        OutlinedTextField(teams,{teams=it},modifier=Modifier.fillMaxWidth().padding(top=8.dp),label={Text("Favourite teams / players")},colors=fieldColors())
        OutlinedTextField(comps,{comps=it},modifier=Modifier.fillMaxWidth().padding(top=8.dp),label={Text("Leagues / competitions")},colors=fieldColors())
        OutlinedTextField(language,{language=it},modifier=Modifier.fillMaxWidth().padding(top=8.dp),label={Text("Preferred language")},colors=fieldColors())
    }
    Button(onClick={db.savePreferences(chosen.id,sports,teams,comps,language);message="Preferences saved"},colors=ButtonDefaults.buttonColors(containerColor=Cyan,contentColor=Ink)){Text("Save preferences")}
    Text(message,color=Cyan,fontSize=12.sp)
}
@Composable
fun MatchEditor(db:TrackerDb) {
    var sport by remember{mutableStateOf("Cricket")};var comp by remember{mutableStateOf("")};var home by remember{mutableStateOf("")};var away by remember{mutableStateOf("")};var date by remember{mutableStateOf(java.time.LocalDate.now().toString())};var time by remember{mutableStateOf("")};var message by remember{mutableStateOf("")}
    GlassCard(Modifier.fillMaxWidth()) {
        Text("ADD FIXTURE",color=Cyan,fontWeight=FontWeight.Bold,fontSize=10.sp)
        OutlinedTextField(sport,{sport=it},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("Sport")},colors=fieldColors())
        OutlinedTextField(comp,{comp=it},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("Competition / league")},colors=fieldColors())
        OutlinedTextField(home,{home=it},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("Home / first team")},colors=fieldColors())
        OutlinedTextField(away,{away=it},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("Away / second team")},colors=fieldColors())
        OutlinedTextField(date,{date=it},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("Date · YYYY-MM-DD")},colors=fieldColors())
        OutlinedTextField(time,{time=it},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("Time")},colors=fieldColors())
        Button(onClick={if(home.isNotBlank()&&date.matches(Regex("\\d{4}-\\d{2}-\\d{2}"))){db.addMatch(sport,comp,home,away,date,time,"");home="";away="";message="Fixture saved"}else message="Enter team names and a valid date"},colors=ButtonDefaults.buttonColors(containerColor=Violet,contentColor=Ink)){Text("Save fixture")}
        Text(message,color=Cyan,fontSize=11.sp)
    }
}

@Composable
fun fieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor=Cyan, unfocusedBorderColor=Color(0xFF39465F),
    focusedLabelColor=Cyan, cursorColor=Cyan,
    focusedTextColor=Color.White, unfocusedTextColor=Color.White,
    focusedContainerColor=Color(0xFF0F182A), unfocusedContainerColor=Color(0xFF0F182A)
)
fun money(v:Double) = "${String.format(Locale.US,"%.2f",v)} coins"
