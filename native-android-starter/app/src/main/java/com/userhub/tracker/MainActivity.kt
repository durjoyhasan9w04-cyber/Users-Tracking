package com.userhub.tracker

import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.time.LocalDate
import java.util.Locale

private val Ink=Color(0xFF080D1B)
private val Panel=Color(0xFF151D31)
private val PanelLight=Color(0xFF202B45)
private val Cyan=Color(0xFF68E1E8)
private val Violet=Color(0xFF9B8CFF)
private val Muted=Color(0xFF9AA8C2)

class MainActivity:ComponentActivity(){
    override fun onCreate(savedInstanceState:Bundle?){
        super.onCreate(savedInstanceState)
        val db=TrackerDb(this)
        window.statusBarColor=android.graphics.Color.rgb(8,13,27)
        window.navigationBarColor=android.graphics.Color.rgb(8,13,27)
        createDailyBackup(this,db)
        setContent{UserHubApp(db)}
    }
}
private fun createDailyBackup(context:Context,db:TrackerDb){
    try{
        db.writableDatabase.rawQuery("PRAGMA wal_checkpoint(FULL)",null).use{}
        val folder=File(context.filesDir,"backups").apply{mkdirs()}
        val day=LocalDate.now().toString()
        if(folder.listFiles()?.none{it.name.startsWith("tracker_daily_$day")}!=false){
            val src=context.getDatabasePath("tracker.db")
            if(src.exists()) File(folder,"tracker_daily_$day.db").also{src.copyTo(it,true)}
        }
        folder.listFiles()?.sortedByDescending{it.lastModified()}?.drop(30)?.forEach{it.delete()}
    }catch(_:Exception){}
}

@Composable
fun UserHubApp(db:TrackerDb){
    var tab by remember{mutableStateOf("Home")}
    var refresh by remember{mutableIntStateOf(0)}
    var users by remember{mutableStateOf(db.users())}
    var selectedUser by remember{mutableStateOf<User?>(null)}
    fun reload(){users=db.users();refresh++}
    MaterialTheme(colorScheme=darkColorScheme(primary=Cyan,secondary=Violet,background=Ink,surface=Panel,onBackground=Color.White,onSurface=Color.White,onPrimary=Ink)){
        Scaffold(containerColor=Ink,topBar={
            Row(Modifier.fillMaxWidth().background(Ink).padding(horizontal=20.dp,vertical=14.dp),verticalAlignment=Alignment.CenterVertically){
                Box(Modifier.size(38.dp).clip(RoundedCornerShape(13.dp)).background(Brush.linearGradient(listOf(Cyan,Violet))),contentAlignment=Alignment.Center){Icon(Icons.Outlined.Hub,null,tint=Ink)}
                Spacer(Modifier.width(11.dp))
                Column(Modifier.weight(1f)){Text("USER HUB",fontWeight=FontWeight.ExtraBold,letterSpacing=2.sp,fontSize=15.sp);Text("PRIVATE DP WORKSPACE",color=Muted,fontSize=10.sp,letterSpacing=1.3.sp)}
                Box(Modifier.size(36.dp).clip(CircleShape).background(PanelLight),contentAlignment=Alignment.Center){Icon(Icons.Outlined.Person,null,tint=Cyan)}
            }
        },bottomBar={
            NavigationBar(containerColor=Color(0xFF10182A)){
                listOf("Home","Users","DP","Bonus","More").forEach{label->
                    val icon=when(label){"Home"->Icons.Outlined.SpaceDashboard;"Users"->Icons.Outlined.Groups;"DP"->Icons.Outlined.AddCircle;"Bonus"->Icons.Outlined.CardGiftcard;else->Icons.Outlined.GridView}
                    NavigationBarItem(selected=tab==label,onClick={tab=label;selectedUser=null},icon={Icon(icon,null)},label={Text(label,fontSize=10.sp)},colors=NavigationBarItemDefaults.colors(selectedIconColor=Cyan,selectedTextColor=Cyan,indicatorColor=Color(0xFF26364B),unselectedIconColor=Muted,unselectedTextColor=Muted))
                }
            }
        }){padding->
            Box(Modifier.fillMaxSize().padding(padding)){
                when(tab){
                    "Home"->DashboardScreen(db,users,refresh){tab=it}
                    "Users"->UsersPage(users,db,selectedUser,{selectedUser=it},refresh){reload()}
                    "DP"->DpPage(users,db){reload()}
                    "Bonus"->BonusPage(users,db){reload()}
                    else->MorePage(users,db,refresh,{reload()})
                }
            }
        }
    }
}
@Composable fun GlassCard(modifier:Modifier=Modifier,content:@Composable ColumnScope.()->Unit){
    Column(modifier.clip(RoundedCornerShape(22.dp)).background(Brush.linearGradient(listOf(Color(0xFF1B2941),Color(0xFF111A2D)))).border(1.dp,Color(0xFF34425B).copy(alpha=.7f),RoundedCornerShape(22.dp)).padding(16.dp),content=content)
}
@Composable fun PageTitle(title:String,subtitle:String){Column(verticalArrangement=Arrangement.spacedBy(4.dp)){Text(title,fontSize=25.sp,fontWeight=FontWeight.Bold);Text(subtitle,fontSize=12.sp,color=Muted)}}
@Composable fun MetricTile(label:String,value:String,icon:androidx.compose.ui.graphics.vector.ImageVector,accent:Color,modifier:Modifier=Modifier){
    GlassCard(modifier){Row(verticalAlignment=Alignment.CenterVertically){Box(Modifier.size(33.dp).clip(RoundedCornerShape(10.dp)).background(accent.copy(alpha=.15f)),contentAlignment=Alignment.Center){Icon(icon,null,tint=accent,modifier=Modifier.size(18.dp))};Spacer(Modifier.width(8.dp));Text(label,color=Muted,fontSize=10.sp)};Spacer(Modifier.height(11.dp));Text(value,fontSize=19.sp,fontWeight=FontWeight.Bold)}
}
@Composable fun DashboardScreen(db:TrackerDb,users:List<User>,refresh:Int,onGo:(String)->Unit){
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(17.dp),verticalArrangement=Arrangement.spacedBy(14.dp)){
        PageTitle("Good day, Operator","Your private workspace · ${LocalDate.now()}")
        GlassCard(Modifier.fillMaxWidth()){
            Text("TODAY'S DP TOTAL",color=Cyan,fontSize=10.sp,letterSpacing=1.5.sp,fontWeight=FontWeight.Bold)
            Text(money(db.todayDp()),fontSize=31.sp,fontWeight=FontWeight.ExtraBold)
            Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){
                MiniStat("DP entries",db.dpCountToday().toString());MiniStat("Users with DP",db.todayDpUsers().toString());MiniStat("Multi-DP",db.usersWithMultipleDpToday().toString())
            }
        }
        Row(horizontalArrangement=Arrangement.spacedBy(9.dp)){MetricTile("Total users",users.size.toString(),Icons.Outlined.Groups,Cyan,Modifier.weight(1f));MetricTile("Today's bonus",money(db.todayBonus()),Icons.Outlined.CardGiftcard,Violet,Modifier.weight(1f))}
        Row(horizontalArrangement=Arrangement.spacedBy(9.dp)){MetricTile("Contacted today",db.contactedToday().toString(),Icons.Outlined.Phone,Cyan,Modifier.weight(1f));MetricTile("Not contacted",(users.size-db.contactedToday()).coerceAtLeast(0).toString(),Icons.Outlined.Notifications,Violet,Modifier.weight(1f))}
        Row(horizontalArrangement=Arrangement.spacedBy(9.dp)){MetricTile("Monthly DP",money(db.monthDp()),Icons.Outlined.TrendingUp,Color(0xFF77D6A5),Modifier.weight(1f));MetricTile("Monthly bonus",money(db.monthBonus()),Icons.Outlined.Stars,Color(0xFFFFC778),Modifier.weight(1f))}
        Row(horizontalArrangement=Arrangement.spacedBy(9.dp)){MetricTile("Active DP users",db.activeMonthUsers().toString(),Icons.Outlined.CheckCircle,Cyan,Modifier.weight(1f));MetricTile("Never DP",users.count{it.activityStatus=="NEVER DP"}.toString(),Icons.Outlined.PersonOff,Violet,Modifier.weight(1f))}
        Row(horizontalArrangement=Arrangement.spacedBy(9.dp)){MetricTile("No DP this month",db.noDpThisMonth().toString(),Icons.Outlined.EventBusy,Cyan,Modifier.weight(1f));MetricTile("Follow-up queue",db.followUpUsers().count{!it.first.doNotContact}.toString(),Icons.Outlined.NotificationsActive,Violet,Modifier.weight(1f))}
        Text("QUICK ACTIONS",color=Muted,fontSize=10.sp,letterSpacing=1.5.sp,fontWeight=FontWeight.Bold)
        Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){QuickAction("Add user",Icons.Outlined.PersonAdd,Cyan){onGo("Users")};QuickAction("Daily DP",Icons.Outlined.AddCircle,Violet){onGo("DP")};QuickAction("Add bonus",Icons.Outlined.CardGiftcard,Color(0xFFFFC778)){onGo("Bonus")}}
        GlassCard(Modifier.fillMaxWidth()){
            Row(verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1f)){Text("Activity overview",fontWeight=FontWeight.SemiBold);Text("Based on the latest positive DP date",color=Muted,fontSize=10.sp)};TextButton(onClick={onGo("Follow-ups")}){Text("View all",color=Cyan)}}
            db.followUpUsers().take(6).forEach{(u,status)->Row(Modifier.fillMaxWidth().padding(vertical=5.dp),verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1f)){Text(u.name,fontSize=12.sp);Text(u.lastDp?: "No DP record",color=Muted,fontSize=10.sp)};Text(status,color=Violet,fontSize=10.sp)}}
        }
        Text("Private on-device SQLite storage · No Telegram · No paid cloud",color=Muted,fontSize=10.sp)
    }
}
@Composable fun MiniStat(label:String,value:String){Column{Text(value,color=Color.White,fontWeight=FontWeight.Bold,fontSize=16.sp);Text(label,color=Muted,fontSize=10.sp)}}
@Composable fun QuickAction(label:String,icon:androidx.compose.ui.graphics.vector.ImageVector,color:Color,click:()->Unit){
    Column(Modifier.width(104.dp).clip(RoundedCornerShape(17.dp)).background(Panel).border(1.dp,Color(0xFF34425B),RoundedCornerShape(17.dp)).clickable{click()}.padding(vertical=14.dp),horizontalAlignment=Alignment.CenterHorizontally){Icon(icon,null,tint=color,modifier=Modifier.size(22.dp));Spacer(Modifier.height(7.dp));Text(label,fontSize=10.sp,color=Color.White,fontWeight=FontWeight.Medium)}
}
@Composable fun UsersPage(users:List<User>,db:TrackerDb,selected:User?,choose:(User?)->Unit,refresh:Int,onChanged:()->Unit){
    val context=LocalContext.current
    var query by remember{mutableStateOf("")};var addOpen by remember{mutableStateOf(false)}
    if(selected!=null){val current=users.firstOrNull{it.id==selected.id}?:selected;ProfilePage(current,db,{choose(null)},{onChanged()})}
    else{
        Column(Modifier.fillMaxSize().padding(17.dp),verticalArrangement=Arrangement.spacedBy(11.dp)){
            Row(verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1f)){PageTitle("All users","${users.size} permanent profiles")};Button(onClick={addOpen=true},colors=ButtonDefaults.buttonColors(containerColor=Cyan,contentColor=Ink),shape=RoundedCornerShape(13.dp)){Icon(Icons.Outlined.Add,null);Text(" Add")}}
            OutlinedTextField(query,{query=it},modifier=Modifier.fillMaxWidth(),placeholder={Text("Search name or phone")},leadingIcon={Icon(Icons.Outlined.Search,null)},singleLine=true,shape=RoundedCornerShape(15.dp),colors=fieldColors())
            LazyColumn(verticalArrangement=Arrangement.spacedBy(8.dp)){
                items(users.filter{it.name.contains(query,true)||it.number.contains(query,true)}){u->
                    GlassCard(Modifier.fillMaxWidth().clickable{choose(u)}){
                        Row(verticalAlignment=Alignment.CenterVertically){Box(Modifier.size(39.dp).clip(CircleShape).background(Color(0xFF283953)),contentAlignment=Alignment.Center){Text(u.name.take(1).uppercase(),color=Cyan,fontWeight=FontWeight.Bold)};Spacer(Modifier.width(10.dp));Column(Modifier.weight(1f)){Text(u.name,fontWeight=FontWeight.SemiBold);Text(u.number.ifBlank{"No number"},color=Muted,fontSize=10.sp);Text("${u.lifecycleStatus} · ${u.activityStatus}",color=Violet,fontSize=10.sp)};Icon(Icons.Outlined.ChevronRight,null,tint=Muted)}
                        Row(Modifier.fillMaxWidth(),horizontalArrangement=Arrangement.SpaceBetween){Text("DP ${money(u.totalDp)}",fontSize=10.sp,color=Muted);Text("Bonus ${money(u.totalBonus)}",fontSize=10.sp,color=Muted);if(u.doNotContact)Text("DO NOT CONTACT",fontSize=9.sp,color=Color(0xFFFFC778))}
                    }
                }
            }
        }
        if(addOpen)AddUserDialog({addOpen=false}){n,p,note,type->val result=db.addUser(n,p,note,type);addOpen=false;onChanged();if(result==-1L)Toast.makeText(context,"A user with this number already exists",Toast.LENGTH_LONG).show()}
    }
}
@Composable fun AddUserDialog(onDismiss:()->Unit,onSave:(String,String,String,String)->Unit){
    var name by remember{mutableStateOf("")};var phone by remember{mutableStateOf("")};var notes by remember{mutableStateOf("")};var type by remember{mutableStateOf("new")}
    AlertDialog(onDismissRequest=onDismiss,containerColor=Panel,title={Text("Add new user")},text={Column(verticalArrangement=Arrangement.spacedBy(8.dp)){
        OutlinedTextField(name,{name=it},label={Text("Name *")},singleLine=true,colors=fieldColors())
        OutlinedTextField(phone,{phone=it},label={Text("Phone / user number")},singleLine=true,colors=fieldColors())
        Text("USER TYPE",color=Muted,fontSize=10.sp)
        Row{FilterChip(type=="new",{type="new"},label={Text("New user")});Spacer(Modifier.width(6.dp));FilterChip(type=="previous",{type="previous"},label={Text("Previous user")})}
        Text(if(type=="new")"No previous DP history. Becomes NEVER DP after 30 days without a positive DP." else "Had DP activity before being added; historical DP is not invented.",color=Muted,fontSize=10.sp)
        OutlinedTextField(notes,{notes=it},label={Text("Notes")},colors=fieldColors())
    }},confirmButton={TextButton(onClick={if(name.isNotBlank())onSave(name,phone,notes,type)} ){Text("Save",color=Cyan)}},dismissButton={TextButton(onClick=onDismiss){Text("Cancel")}})
}
@Composable fun ProfilePage(u:User,db:TrackerDb,onBack:()->Unit,onChanged:()->Unit){
    var refresh by remember{mutableIntStateOf(0)}
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),verticalArrangement=Arrangement.spacedBy(11.dp)){
        TextButton(onClick=onBack){Icon(Icons.Outlined.ArrowBack,null);Text("  All users")}
        PageTitle(u.name,u.number.ifBlank{"No phone or user number"}+" · Added "+u.firstAdded)
        Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){MetricTile("Lifetime DP",money(u.totalDp),Icons.Outlined.TrendingUp,Cyan,Modifier.weight(1f));MetricTile("Lifetime bonus",money(u.totalBonus),Icons.Outlined.CardGiftcard,Violet,Modifier.weight(1f))}
        GlassCard(Modifier.fillMaxWidth()){
            ProfileLine("User lifecycle",u.lifecycleStatus);ProfileLine("DP activity",u.activityStatus);ProfileLine("Last DP",u.lastDp?:"Never");ProfileLine("Days since DP",u.daysSince?.toString()?:"—");ProfileLine("Last contact",db.contactHistory(u.id).firstOrNull()?.date?:"—");ProfileLine("Notes",u.notes.ifBlank{"—"})
            Row(verticalAlignment=Alignment.CenterVertically){Text("Do not contact",Modifier.weight(1f));Switch(u.doNotContact,{db.toggleDoNotContact(u.id);onChanged()})}
        }
        SportsPreferencesEditor(u,db){refresh++}
        SectionLabel("DP HISTORY · ${db.dpHistory(u.id).size} records")
        db.dpHistory(u.id).forEach{r->GlassCard(Modifier.fillMaxWidth()){Text(r.date,fontWeight=FontWeight.SemiBold);Text(r.amounts.mapIndexedNotNull{i,v->v?.let{"DP${i+1}: ${money(it)}"}}.joinToString("  · ").ifBlank{"No amounts"},color=Muted,fontSize=11.sp)}}
        SectionLabel("BONUS HISTORY")
        db.bonusHistory(u.id).forEach{b->GlassCard(Modifier.fillMaxWidth()){Row(horizontalArrangement=Arrangement.SpaceBetween,modifier=Modifier.fillMaxWidth()){Text(b.date,fontWeight=FontWeight.SemiBold);Text(money(b.amount),color=Cyan)};Text("${b.reason} · Related DP: ${b.relatedDp?.let{money(it)}?:"—"}",color=Muted,fontSize=10.sp);if(b.notes.isNotBlank())Text(b.notes,color=Muted,fontSize=10.sp)}}
        SectionLabel("CONTACT HISTORY")
        db.contactHistory(u.id).forEach{c->GlassCard(Modifier.fillMaxWidth()){Row(horizontalArrangement=Arrangement.SpaceBetween,modifier=Modifier.fillMaxWidth()){Text(c.date,fontWeight=FontWeight.SemiBold);Text(c.status,color=Violet,fontSize=11.sp)};Text("${c.reason} · ${c.channel}",color=Muted,fontSize=10.sp);if(c.followUp.isNotBlank())Text("Follow-up: ${c.followUp}",color=Muted,fontSize=10.sp);if(c.notes.isNotBlank())Text(c.notes,color=Muted,fontSize=10.sp)}}
    }
}
@Composable fun ProfileLine(label:String,value:String){Row(Modifier.fillMaxWidth().padding(top=8.dp),horizontalArrangement=Arrangement.SpaceBetween){Text(label,color=Muted,fontSize=11.sp);Text(value,color=Color.White,fontSize=11.sp)}}
@Composable fun SectionLabel(s:String){Text(s,color=Cyan,fontWeight=FontWeight.Bold,fontSize=10.sp,letterSpacing=1.2.sp)}
@Composable fun DpPage(users:List<User>,db:TrackerDb,onSaved:()->Unit){
    var uid by remember{mutableStateOf(users.firstOrNull()?.id?.toString()?:"")};var amounts by remember{mutableStateOf(List(5){""})};var message by remember{mutableStateOf("")}
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(17.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
        PageTitle("Daily DP entry","One saved record per submission · ${LocalDate.now()}")
        if(users.isEmpty())Text("Add a user before recording DP.",color=Muted)else{
            val user=users.firstOrNull{it.id.toString()==uid}?:users.first()
            UserPicker(users,user){uid=it.id.toString()}
            GlassCard(Modifier.fillMaxWidth()){
                Text("DP AMOUNTS",color=Cyan,fontSize=10.sp,fontWeight=FontWeight.Bold)
                amounts.forEachIndexed{i,v->OutlinedTextField(v,{s->amounts=amounts.toMutableList().also{it[i]=s}},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("DP ${i+1} · coins · optional")},singleLine=true,colors=fieldColors())}
                val total=amounts.mapNotNull{it.toDoubleOrNull()}.sum()
                Row(Modifier.fillMaxWidth().padding(top=10.dp),horizontalArrangement=Arrangement.SpaceBetween){Text("Calculated total",color=Muted);Text(money(total),color=Cyan,fontWeight=FontWeight.Bold)}
            }
            Button(onClick={
                val invalid=amounts.any{it.isNotBlank()&&(it.toDoubleOrNull()==null||it.toDoubleOrNull()!!<0)}
                val values=amounts.map{it.trim().takeIf{v->v.isNotEmpty()}?.toDoubleOrNull()}
                when{invalid->message="Enter zero or positive numeric amounts";values.none{it!=null&&it>0}->message="Enter at least one amount above zero";else->{db.addDp(user.id,values);message="DP record saved";amounts=List(5){""};onSaved()}}
            },modifier=Modifier.fillMaxWidth(),colors=ButtonDefaults.buttonColors(containerColor=Cyan,contentColor=Ink),shape=RoundedCornerShape(14.dp)){Text("Save daily DP",fontWeight=FontWeight.Bold)}
            Text(message,color=Cyan,fontSize=12.sp)
        }
    }
}
@Composable fun BonusPage(users:List<User>,db:TrackerDb,onSaved:()->Unit){
    var uid by remember{mutableStateOf(users.firstOrNull()?.id?.toString()?:"")};var amount by remember{mutableStateOf("")};var related by remember{mutableStateOf("")};var reason by remember{mutableStateOf("Deposit Bonus")};var notes by remember{mutableStateOf("")};var message by remember{mutableStateOf("")}
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(17.dp),verticalArrangement=Arrangement.spacedBy(12.dp)){
        PageTitle("Bonus manager","Every bonus is a separate dated transaction")
        if(users.isEmpty())Text("Add a user first.",color=Muted)else{
            val user=users.firstOrNull{it.id.toString()==uid}?:users.first();UserPicker(users,user){uid=it.id.toString()}
            GlassCard(Modifier.fillMaxWidth()){
                OutlinedTextField(amount,{amount=it},modifier=Modifier.fillMaxWidth(),label={Text("Bonus amount · coins")},singleLine=true,colors=fieldColors())
                OutlinedTextField(related,{related=it},modifier=Modifier.fillMaxWidth().padding(top=8.dp),label={Text("Related DP amount · optional")},singleLine=true,colors=fieldColors())
                Text("BONUS REASON",color=Muted,fontSize=10.sp,modifier=Modifier.padding(top=10.dp))
                Column{listOf("Deposit Bonus","Special Bonus","Promotional Bonus","Other").forEach{FilterChip(reason==it,{reason=it},label={Text(it)})}}
                OutlinedTextField(notes,{notes=it},modifier=Modifier.fillMaxWidth().padding(top=8.dp),label={Text("Notes")},colors=fieldColors())
            }
            Button(onClick={val a=amount.toDoubleOrNull();val r=related.toDoubleOrNull();if(a==null||a<=0||related.isNotBlank()&&(r==null||r<0))message="Enter a valid bonus and related DP amount"else{db.addBonus(user.id,a,r,reason,notes);amount="";related="";notes="";message="Bonus saved";onSaved()}},modifier=Modifier.fillMaxWidth(),colors=ButtonDefaults.buttonColors(containerColor=Violet,contentColor=Ink)){Text("Save bonus")}
            Text(message,color=Cyan,fontSize=12.sp)
        }
        SectionLabel("RECENT BONUS HISTORY")
        db.bonusHistory().take(30).forEach{b->GlassCard(Modifier.fillMaxWidth()){Row(horizontalArrangement=Arrangement.SpaceBetween,modifier=Modifier.fillMaxWidth()){Text(b.userName,fontWeight=FontWeight.SemiBold);Text(money(b.amount),color=Cyan)};Text("${b.date} · ${b.reason}",color=Muted,fontSize=10.sp)}}
    }
}
@OptIn(ExperimentalMaterial3Api::class)
@Composable fun UserPicker(users:List<User>,selected:User,onSelect:(User)->Unit){
    var expanded by remember{mutableStateOf(false)}
    ExposedDropdownMenuBox(expanded=expanded,onExpandedChange={expanded=it}){OutlinedTextField(selected.name,{},readOnly=true,label={Text("Select user")},modifier=Modifier.menuAnchor().fillMaxWidth(),trailingIcon={ExposedDropdownMenuDefaults.TrailingIcon(expanded)},colors=fieldColors());ExposedDropdownMenu(expanded=expanded,onDismissRequest={expanded=false}){users.forEach{DropdownMenuItem(text={Text(it.name+" · "+it.number)},onClick={onSelect(it);expanded=false})}}}
}

@Composable fun MorePage(users:List<User>,db:TrackerDb,refresh:Int,onChanged:()->Unit){
    var section by remember{mutableStateOf("More")}
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),verticalArrangement=Arrangement.spacedBy(11.dp)){
        if(section=="More"){
            PageTitle("Workspace","All tools and records")
            listOf("Contact history" to Icons.Outlined.Phone,"Follow-up center" to Icons.Outlined.NotificationsActive,"Monthly reports" to Icons.Outlined.BarChart,"DP activity calendar" to Icons.Outlined.CalendarMonth,"Sports interests" to Icons.Outlined.SportsSoccer,"Match calendar" to Icons.Outlined.Event,"Match reminders" to Icons.Outlined.Notifications,"Backup & restore" to Icons.Outlined.Backup).forEach{(name,icon)->GlassCard(Modifier.fillMaxWidth().clickable{section=name}){Row(verticalAlignment=Alignment.CenterVertically){Icon(icon,null,tint=Cyan);Spacer(Modifier.width(12.dp));Text(name,Modifier.weight(1f),fontWeight=FontWeight.SemiBold);Icon(Icons.Outlined.ChevronRight,null,tint=Muted)}}}
        }else{
            Row(verticalAlignment=Alignment.CenterVertically){TextButton(onClick={section="More"}){Text("‹ Back",color=Cyan)};PageTitle(section,"Local records · no automatic messages")}
            when(section){
                "Contact history"->ContactPage(users,db){onChanged()}
                "Follow-up center"->FollowUpPage(db)
                "Monthly reports"->ReportsPage(users,db)
                "DP activity calendar"->DpCalendarPage(db)
                "Sports interests"->SportsPage(users,db)
                "Match calendar"->MatchPage(users,db)
                "Match reminders"->RemindersPage(db)
                "Backup & restore"->BackupPage(db)
            }
        }
    }
}
@Composable fun ContactPage(users:List<User>,db:TrackerDb,onSaved:()->Unit){
    var uid by remember{mutableStateOf(users.firstOrNull()?.id?.toString()?:"")};var status by remember{mutableStateOf("Contacted")};var reason by remember{mutableStateOf("General support")};var channel by remember{mutableStateOf("WhatsApp")};var follow by remember{mutableStateOf("")};var notes by remember{mutableStateOf("")};var message by remember{mutableStateOf("")}
    if(users.isEmpty())Text("Add users first.",color=Muted)else{
        val user=users.firstOrNull{it.id.toString()==uid}?:users.first()
        GlassCard(Modifier.fillMaxWidth()){
            Text("LOG A CONTACT",color=Cyan,fontWeight=FontWeight.Bold,fontSize=10.sp);UserPicker(users,user){uid=it.id.toString()}
            ChoiceField("Status",status,listOf("Contacted","No response","Declined further contact")){status=it}
            ChoiceField("Reason",reason,listOf("General support","Account question","Payment support","User-requested callback","Opted-in sports information","Other")){reason=it}
            ChoiceField("Channel",channel,listOf("WhatsApp","Phone call","SMS","Email","In-app","Other")){channel=it}
            OutlinedTextField(follow,{follow=it},modifier=Modifier.fillMaxWidth().padding(top=8.dp),label={Text("Agreed follow-up date · YYYY-MM-DD")},colors=fieldColors())
            OutlinedTextField(notes,{notes=it},modifier=Modifier.fillMaxWidth().padding(top=8.dp),label={Text("Contact notes")},colors=fieldColors())
            Button(onClick={if(follow.isNotBlank()&&!follow.matches(Regex("\\d{4}-\\d{2}-\\d{2}")))message="Use YYYY-MM-DD for follow-up date"else{db.addContact(user.id,status,reason,channel,follow,notes);message="Contact record saved";notes="";onSaved()}},modifier=Modifier.fillMaxWidth(),colors=ButtonDefaults.buttonColors(containerColor=Cyan,contentColor=Ink)){Text("Save contact record")}
            Text(message,color=Cyan,fontSize=11.sp)
        }
    }
    SectionLabel("RECENT CONTACT HISTORY")
    db.contactHistory().take(100).forEach{c->GlassCard(Modifier.fillMaxWidth()){Row(horizontalArrangement=Arrangement.SpaceBetween,modifier=Modifier.fillMaxWidth()){Text(c.userName,fontWeight=FontWeight.SemiBold);Text(c.status,color=Violet,fontSize=11.sp)};Text("${c.date} · ${c.reason} · ${c.channel}",color=Muted,fontSize=10.sp);if(c.followUp.isNotBlank())Text("Follow-up: ${c.followUp}",color=Muted,fontSize=10.sp);if(c.notes.isNotBlank())Text(c.notes,color=Muted,fontSize=10.sp)}}
}
@OptIn(ExperimentalMaterial3Api::class)
@Composable fun ChoiceField(label:String,value:String,options:List<String>,onSelect:(String)->Unit){
    var expanded by remember{mutableStateOf(false)}
    ExposedDropdownMenuBox(expanded=expanded,onExpandedChange={expanded=it}){OutlinedTextField(value,{},readOnly=true,label={Text(label)},modifier=Modifier.menuAnchor().fillMaxWidth().padding(top=7.dp),trailingIcon={ExposedDropdownMenuDefaults.TrailingIcon(expanded)},colors=fieldColors());ExposedDropdownMenu(expanded=expanded,onDismissRequest={expanded=false}){options.forEach{DropdownMenuItem(text={Text(it)},onClick={onSelect(it);expanded=false})}}}
}
@Composable fun FollowUpPage(db:TrackerDb){
    val all=db.users()
    Column(verticalArrangement=Arrangement.spacedBy(8.dp)){
        listOf("ACTIVE","FOLLOW-UP","INACTIVE","LONG INACTIVE","VERY LONG INACTIVE","NEVER DP").forEach{status->
            val rows=all.filter{it.activityStatus==status}
            GlassCard(Modifier.fillMaxWidth()){Text("$status · ${rows.size}",color=Cyan,fontWeight=FontWeight.Bold);rows.forEach{Text("${it.name} · ${it.daysSince?.let{"$it days"}?:"No DP history"}",fontSize=11.sp,color=Muted)}}
        }
        val notContacted=all.filter{u->db.contactHistory(u.id).none{it.date==LocalDate.now().toString()&&it.status=="Contacted"}}
        GlassCard(Modifier.fillMaxWidth()){Text("NOT CONTACTED TODAY · ${notContacted.size}",color=Violet,fontWeight=FontWeight.Bold);notContacted.forEach{Text(it.name,fontSize=11.sp,color=Muted)}}
        Text("Informational activity lists only. No automated contact or promotional prompts.",color=Muted,fontSize=10.sp)
    }
}
@Composable fun ReportsPage(users:List<User>,db:TrackerDb){
    var month by remember{mutableStateOf(LocalDate.now().toString().take(7))}
    val valid=month.matches(Regex("\\d{4}-\\d{2}"))
    val rows=if(valid)db.reportUsers(month)else emptyList()
    Column(verticalArrangement=Arrangement.spacedBy(9.dp)){
        OutlinedTextField(month,{month=it},modifier=Modifier.fillMaxWidth(),label={Text("Report month · YYYY-MM")},singleLine=true,colors=fieldColors())
        if(valid){
            Row(horizontalArrangement=Arrangement.spacedBy(8.dp)){MetricTile("DP total",money(db.monthDp(month)),Icons.Outlined.TrendingUp,Cyan,Modifier.weight(1f));MetricTile("Bonus total",money(db.monthBonus(month)),Icons.Outlined.CardGiftcard,Violet,Modifier.weight(1f))}
            MetricTile("Active DP users",rows.count{it.dp>0}.toString(),Icons.Outlined.Groups,Cyan,Modifier.fillMaxWidth())
            rows.forEach{r->GlassCard(Modifier.fillMaxWidth()){Text(r.user.name,fontWeight=FontWeight.SemiBold);Text("DP ${money(r.dp)} · ${r.count} entries · Bonus ${money(r.bonus)}",color=Muted,fontSize=11.sp);Text(if(r.dp>0)"DP recorded" else if(r.everDp)"No DP this month · Previously active" else "Never DP",color=Violet,fontSize=10.sp)}}
            SectionLabel("BONUS TRANSACTIONS")
            db.bonusHistory(month=month).forEach{b->Text("${b.date} · ${b.userName} · ${money(b.amount)} · ${b.reason}",color=Muted,fontSize=11.sp)}
        }else Text("Enter a valid month such as 2026-11.",color=Color(0xFFFFC778))
    }
}
@Composable fun DpCalendarPage(db:TrackerDb){
    var month by remember{mutableStateOf(LocalDate.now().toString().take(7))}
    Column(verticalArrangement=Arrangement.spacedBy(8.dp)){
        OutlinedTextField(month,{month=it},modifier=Modifier.fillMaxWidth(),label={Text("Month · YYYY-MM")},colors=fieldColors())
        if(month.matches(Regex("\\d{4}-\\d{2}"))){
            db.dpCalendar(month).forEach{r->GlassCard(Modifier.fillMaxWidth()){Row(horizontalArrangement=Arrangement.SpaceBetween,modifier=Modifier.fillMaxWidth()){Text(r.date,fontWeight=FontWeight.SemiBold);Text(money(r.total),color=Cyan)};Text("${r.users} users · ${r.entries} DP entries",color=Muted,fontSize=11.sp)}}
        }
    }
}
@Composable fun SportsPage(users:List<User>,db:TrackerDb){
    if(users.isEmpty()){Text("Add users first.",color=Muted);return}
    var uid by remember{mutableStateOf(users.first().id.toString())};var refresh by remember{mutableIntStateOf(0)}
    val u=users.firstOrNull{it.id.toString()==uid}?:users.first()
    UserPicker(users,u){uid=it.id.toString()}
    SportsPreferencesEditor(u,db){refresh++}
    users.forEach{user->val p=db.preferences(user.id);if(p!=null)GlassCard(Modifier.fillMaxWidth()){Text(user.name,fontWeight=FontWeight.SemiBold);Text("Sports: ${p.sports.ifBlank{"—"}}",color=Muted,fontSize=10.sp);Text("Teams: ${p.teams.ifBlank{"—"}} · Players: ${p.players.ifBlank{"—"}}",color=Muted,fontSize=10.sp);Text("Competitions: ${p.competitions.ifBlank{"—"}}",color=Muted,fontSize=10.sp);Text("Event reminders: ${if(p.eventOptIn&&p.contactOptIn)"Opted in" else "Not opted in"}",color=Violet,fontSize=10.sp)}}
}
@Composable fun SportsPreferencesEditor(u:User,db:TrackerDb,onSaved:()->Unit){
    val old=db.preferences(u.id)
    var sports by remember(u.id,old){mutableStateOf(old?.sports?:"")};var teams by remember(u.id,old){mutableStateOf(old?.teams?:"")};var players by remember(u.id,old){mutableStateOf(old?.players?:"")};var competitions by remember(u.id,old){mutableStateOf(old?.competitions?:"")};var language by remember(u.id,old){mutableStateOf(old?.language?:"Bangla")};var channel by remember(u.id,old){mutableStateOf(old?.channel?:"WhatsApp")};var window by remember(u.id,old){mutableStateOf(old?.window?:"")};var frequency by remember(u.id,old){mutableStateOf(old?.frequency?:"Only when I request")};var contactOpt by remember(u.id,old){mutableStateOf(old?.contactOptIn?:false)};var eventOpt by remember(u.id,old){mutableStateOf(old?.eventOptIn?:false)};var saved by remember{mutableStateOf("")}
    GlassCard(Modifier.fillMaxWidth()){
        SectionLabel("SPORTS & CONTACT PREFERENCES")
        OutlinedTextField(sports,{sports=it},modifier=Modifier.fillMaxWidth().padding(top=8.dp),label={Text("Sports · Cricket, Football, Kabaddi, Tennis, Badminton, Esports")},colors=fieldColors())
        OutlinedTextField(teams,{teams=it},modifier=Modifier.fillMaxWidth().padding(top=8.dp),label={Text("Favourite teams / clubs · comma separated")},colors=fieldColors())
        OutlinedTextField(players,{players=it},modifier=Modifier.fillMaxWidth().padding(top=8.dp),label={Text("Favourite players")},colors=fieldColors())
        OutlinedTextField(competitions,{competitions=it},modifier=Modifier.fillMaxWidth().padding(top=8.dp),label={Text("Competitions / tournaments")},colors=fieldColors())
        ChoiceField("Preferred language",language,listOf("Bangla","English","Both")){language=it}
        ChoiceField("Preferred channel",channel,listOf("WhatsApp","Phone call","SMS","Email","In-app")){channel=it}
        OutlinedTextField(window,{window=it},modifier=Modifier.fillMaxWidth().padding(top=8.dp),label={Text("Preferred contact time")},colors=fieldColors())
        ChoiceField("Contact frequency",frequency,listOf("Only when I request","Important service updates only","Weekly maximum","Monthly maximum")){frequency=it}
        Row(verticalAlignment=Alignment.CenterVertically){Text("Agreed to service/support contact",Modifier.weight(1f),fontSize=11.sp);Switch(contactOpt,{contactOpt=it})}
        Row(verticalAlignment=Alignment.CenterVertically){Text("Opted in to match reminders",Modifier.weight(1f),fontSize=11.sp);Switch(eventOpt,{eventOpt=it})}
        Text("No automatic messages are sent. Only opted-in interests appear in internal reminders.",color=Muted,fontSize=10.sp)
        Button(onClick={db.savePreferences(u.id,sports,teams,players,competitions,language,channel,window,frequency,contactOpt,eventOpt);saved="Preferences saved";onSaved()},colors=ButtonDefaults.buttonColors(containerColor=Cyan,contentColor=Ink)){Text("Save preferences")}
        Text(saved,color=Cyan,fontSize=10.sp)
    }
}
@Composable fun MatchPage(users:List<User>,db:TrackerDb){
    var sport by remember{mutableStateOf("Cricket")};var competition by remember{mutableStateOf("")};var home by remember{mutableStateOf("")};var away by remember{mutableStateOf("")};var date by remember{mutableStateOf(LocalDate.now().toString())};var time by remember{mutableStateOf("")};var notes by remember{mutableStateOf("")};var msg by remember{mutableStateOf("")};var refresh by remember{mutableIntStateOf(0)}
    var syncStatus by remember{mutableStateOf(db.syncState().first)};var syncMessage by remember{mutableStateOf(db.syncState().second)}
    LaunchedEffect(Unit){FixtureSync.start(db){s,m->syncStatus=s;syncMessage=m;refresh++}}
    val events=remember(refresh,syncMessage){db.upcomingMatches()}
    GlassCard(Modifier.fillMaxWidth()){
        SectionLabel("WORLDWIDE FIXTURE DISCOVERY")
        Text("Multi-source best-effort refresh · SportScore, TheSportsDB and OpenLigaDB",color=Muted,fontSize=11.sp)
        Text("Bangladesh time (BST, UTC+6). Free providers have uneven coverage and rate limits; not every league or fixture is guaranteed.",color=Muted,fontSize=10.sp)
        Text("Status: $syncStatus · $syncMessage",color=Cyan,fontSize=10.sp)
        Button(onClick={FixtureSync.start(db,force=true){s,m->syncStatus=s;syncMessage=m;refresh++}},modifier=Modifier.fillMaxWidth(),colors=ButtonDefaults.buttonColors(containerColor=Cyan,contentColor=Ink)){Icon(Icons.Outlined.Refresh,null);Text(" Refresh worldwide fixtures")}
        val context=LocalContext.current
        Text("Powered by SportScore · TheSportsDB · OpenLigaDB",modifier=Modifier.clickable{context.startActivity(Intent(Intent.ACTION_VIEW,Uri.parse("https://sportscore.com/developers/")))},color=Cyan,fontSize=9.sp)
    }
    GlassCard(Modifier.fillMaxWidth()){
        SectionLabel("ADD FIXTURE MANUALLY")
        ChoiceField("Sport",sport,listOf("Cricket","Football","Kabaddi","Tennis","Badminton","Esports")){sport=it}
        OutlinedTextField(competition,{competition=it},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("Competition / league")},colors=fieldColors())
        OutlinedTextField(home,{home=it},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("Home / first team")},colors=fieldColors())
        OutlinedTextField(away,{away=it},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("Away / second team")},colors=fieldColors())
        OutlinedTextField(date,{date=it},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("Date · YYYY-MM-DD")},colors=fieldColors())
        OutlinedTextField(time,{time=it},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("Bangladesh time · HH:MM")},colors=fieldColors())
        OutlinedTextField(notes,{notes=it},modifier=Modifier.fillMaxWidth().padding(top=7.dp),label={Text("Notes")},colors=fieldColors())
        Button(onClick={if(home.isNotBlank()&&date.matches(Regex("\\d{4}-\\d{2}-\\d{2}"))){db.addMatch(sport,competition,home,away,date,time,notes);home="";away="";msg="Fixture saved";refresh++}else msg="Enter team names and a valid date"},colors=ButtonDefaults.buttonColors(containerColor=Violet,contentColor=Ink)){Text("Save fixture")}
        Text(msg,color=Cyan,fontSize=10.sp)
    }
    SectionLabel("UPCOMING FIXTURES · ${events.size}")
    events.forEach{m->GlassCard(Modifier.fillMaxWidth()){Row(verticalAlignment=Alignment.CenterVertically){Column(Modifier.weight(1f)){Text("${m.home}"+if(m.away.isNotBlank())" vs ${m.away}" else "",fontWeight=FontWeight.Bold);Text("${m.sport} · ${m.competition}",color=Muted,fontSize=10.sp);Text("${m.date} · ${m.time.ifBlank{"Time not set"}} · ${m.source}",color=Cyan,fontSize=10.sp)};IconButton(onClick={db.deleteMatch(m.id);refresh++}){Icon(Icons.Outlined.Delete,null,tint=Muted)}}}}
}
@Composable fun RemindersPage(db:TrackerDb){
    val reminders=db.matchingReminders()
    Text("Internal reminders only · no messages are sent automatically.",color=Muted,fontSize=11.sp)
    if(reminders.isEmpty())Text("No upcoming fixture currently matches opted-in user preferences.",color=Muted,fontSize=12.sp)
    reminders.forEach{g->GlassCard(Modifier.fillMaxWidth()){Text("${g.event.home} vs ${g.event.away}",fontWeight=FontWeight.Bold);Text("${g.event.sport} · ${g.event.competition} · ${g.event.date} ${g.event.time}",color=Cyan,fontSize=10.sp);Text("${g.users.size} opted-in matching users",color=Muted,fontSize=11.sp);g.users.forEach{Text("• ${it.name}",fontSize=11.sp)}}}
}
@Composable fun BackupPage(db:TrackerDb){
    val context= LocalContext.current
    var status by remember{mutableStateOf("")}
    var pendingCsv by remember{mutableStateOf("")}
    val exportBackup=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/octet-stream")){uri->if(uri!=null)try{db.writableDatabase.rawQuery("PRAGMA wal_checkpoint(FULL)",null).use{};context.contentResolver.openOutputStream(uri)?.use{out->context.getDatabasePath("tracker.db").inputStream().use{it.copyTo(out)}};status="Backup exported successfully"}catch(e:Exception){status="Backup export failed: ${e.message}"}}
    val restoreBackup=rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()){uri->if(uri!=null)try{
        val temp=File(context.cacheDir,"restore_check.db");context.contentResolver.openInputStream(uri)!!.use{input->FileOutputStream(temp).use{input.copyTo(it)}}
        val check=SQLiteDatabase.openDatabase(temp.absolutePath,null,SQLiteDatabase.OPEN_READONLY)
        val integrity=check.rawQuery("PRAGMA integrity_check",null).use{it.moveToFirst()&&it.getString(0)=="ok"}
        val tables=check.rawQuery("SELECT name FROM sqlite_master WHERE type='table'",null).use{c->buildSet{while(c.moveToNext())add(c.getString(0))}}
        check.close()
        if(!integrity||!tables.containsAll(setOf("users","dp_records","bonuses","contacts")))throw IllegalArgumentException("Not a valid User Hub database")
        db.writableDatabase.rawQuery("PRAGMA wal_checkpoint(FULL)",null).use{};val backupDir=File(context.filesDir,"backups").apply{mkdirs()};val before=File(backupDir,"tracker_before_restore_${System.currentTimeMillis()}.db");context.getDatabasePath("tracker.db").copyTo(before,true)
        db.close();val databaseFile=context.getDatabasePath("tracker.db");File(databaseFile.absolutePath+"-wal").delete();File(databaseFile.absolutePath+"-shm").delete();temp.copyTo(databaseFile,true);db.writableDatabase
        status="Database restored. Previous database safety copy was kept temporarily."
        temp.delete()
    }catch(e:Exception){status="Restore failed: ${e.message}"}}
    val exportCsv=rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")){uri->if(uri!=null)try{context.contentResolver.openOutputStream(uri)?.bufferedWriter()?.use{it.write(pendingCsv)};status="CSV exported successfully"}catch(e:Exception){status="CSV export failed: ${e.message}"}}
    Column(verticalArrangement=Arrangement.spacedBy(10.dp)){
        GlassCard(Modifier.fillMaxWidth()){
            SectionLabel("DATABASE BACKUP")
            Text("Automatic daily backup is made when the app starts. Keep a separate copy outside this phone.",color=Muted,fontSize=11.sp)
            Button(onClick={try{db.writableDatabase.rawQuery("PRAGMA wal_checkpoint(FULL)",null).use{};val dir=File(context.filesDir,"backups").apply{mkdirs()};val target=File(dir,"tracker_manual_${System.currentTimeMillis()}.db");context.getDatabasePath("tracker.db").copyTo(target,true);status="Local backup created: ${target.name}"}catch(e:Exception){status="Backup failed: ${e.message}"}},modifier=Modifier.fillMaxWidth(),colors=ButtonDefaults.buttonColors(containerColor=Violet,contentColor=Ink)){Icon(Icons.Outlined.Backup,null);Text(" Create local backup now")}
            Button(onClick={exportBackup.launch("userhub_backup_${LocalDate.now()}.db")},modifier=Modifier.fillMaxWidth(),colors=ButtonDefaults.buttonColors(containerColor=Cyan,contentColor=Ink)){Icon(Icons.Outlined.Download,null);Text(" Export database backup")}
            OutlinedButton(onClick={restoreBackup.launch(arrayOf("application/octet-stream","application/x-sqlite3","application/vnd.sqlite3","*/*"))},modifier=Modifier.fillMaxWidth()){Icon(Icons.Outlined.Restore,null);Text(" Restore database backup")}
            Text("You can also import your v5.5 Termux database here. Stop the Flask app first, copy data/tracker.db into Downloads, then select it. Restore replaces current data; a safety copy is created first. Only restore trusted backups.",color=Color(0xFFFFC778),fontSize=10.sp)
        }
        GlassCard(Modifier.fillMaxWidth()){
            SectionLabel("EXPORT CSV")
            listOf("Users" to db.allUsersCsv(),"DP records" to db.dpCsv(),"Bonus records" to db.bonusesCsv()).forEach{(label,data)->OutlinedButton(onClick={pendingCsv=data;exportCsv.launch(label.lowercase().replace(" ","_")+"_export.csv")},modifier=Modifier.fillMaxWidth()){Icon(Icons.Outlined.FileDownload,null);Text(" Export $label CSV")}}
        }
        Text(status,color=Cyan,fontSize=11.sp)
        val files=File(context.filesDir,"backups").listFiles()?.sortedByDescending{it.lastModified()}.orEmpty()
        SectionLabel("AUTOMATIC LOCAL SNAPSHOTS")
        files.forEach{f->Text("${f.name} · ${f.length()/1024} KB",color=Muted,fontSize=10.sp)}
    }
}

@Composable fun fieldColors()=OutlinedTextFieldDefaults.colors(focusedBorderColor=Cyan,unfocusedBorderColor=Color(0xFF39465F),focusedLabelColor=Cyan,cursorColor=Cyan,focusedTextColor=Color.White,unfocusedTextColor=Color.White,focusedContainerColor=Color(0xFF0F182A),unfocusedContainerColor=Color(0xFF0F182A))
fun money(v:Double)="${String.format(Locale.US,"%.2f",v)} coins"
