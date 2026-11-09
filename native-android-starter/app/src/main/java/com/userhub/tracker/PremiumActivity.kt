package com.userhub.tracker

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.core.view.WindowCompat

private val HubGreen = Color(0xFF087F5B)
private val HubGreenDark = Color(0xFF056348)
private val HubCanvas = Color(0xFFF5F8F6)
private val HubInk = Color(0xFF17251D)
private val HubMuted = Color(0xFF718078)

class PremiumActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val db = TrackerDb(this)
        window.statusBarColor = android.graphics.Color.rgb(245, 248, 246)
        window.navigationBarColor = android.graphics.Color.rgb(255, 255, 255)
        WindowCompat.getInsetsController(window, window.decorView).apply {
            isAppearanceLightStatusBars = true
            isAppearanceLightNavigationBars = true
        }
        setContent { PremiumUserHubApp(db) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PremiumUserHubApp(db: TrackerDb) {
    var tab by remember { mutableStateOf("Home") }
    var refresh by remember { mutableIntStateOf(0) }
    var users by remember { mutableStateOf(db.users()) }
    var selectedUser by remember { mutableStateOf<User?>(null) }
    fun reload() {
        users = db.users()
        refresh++
    }

    val colors = lightColorScheme(
        primary = HubGreen,
        onPrimary = Color.White,
        primaryContainer = Color(0xFFE2F3EA),
        onPrimaryContainer = HubGreenDark,
        secondary = Color(0xFF668B78),
        tertiary = Color(0xFFB88742),
        background = HubCanvas,
        onBackground = HubInk,
        surface = Color.White,
        onSurface = HubInk,
        surfaceVariant = Color(0xFFEDF3EF),
        onSurfaceVariant = HubMuted,
        outline = Color(0xFFDCE6DF)
    )
    val shapes = Shapes(
        extraSmall = RoundedCornerShape(8.dp),
        small = RoundedCornerShape(12.dp),
        medium = RoundedCornerShape(16.dp),
        large = RoundedCornerShape(22.dp),
        extraLarge = RoundedCornerShape(28.dp)
    )

    MaterialTheme(colorScheme = colors, shapes = shapes) {
        Scaffold(
            containerColor = HubCanvas,
            topBar = {
                TopAppBar(
                    title = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                Modifier
                                    .size(38.dp)
                                    .clip(RoundedCornerShape(13.dp))
                                    .background(Brush.linearGradient(listOf(HubGreen, Color(0xFF56A77D)))),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Outlined.SpaceDashboard, null, tint = Color.White, modifier = Modifier.size(21.dp))
                            }
                            Spacer(Modifier.width(11.dp))
                            Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
                                Text("USER HUB", fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, letterSpacing = 1.5.sp, color = HubInk)
                                Text("PRIVATE DP WORKSPACE", fontSize = 9.sp, letterSpacing = 1.15.sp, color = HubMuted)
                            }
                        }
                    },
                    actions = {
                        Surface(
                            shape = RoundedCornerShape(50),
                            color = Color(0xFFE7F3EC),
                            modifier = Modifier.padding(end = 16.dp)
                        ) {
                            Icon(Icons.Outlined.Person, contentDescription = "Operator profile", tint = HubGreen, modifier = Modifier.padding(9.dp).size(19.dp))
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = Color.White)
                )
            },
            bottomBar = {
                NavigationBar(
                    containerColor = Color.White,
                    contentColor = HubInk,
                    tonalElevation = 8.dp
                ) {
                    val destinations = listOf(
                        Triple("Home", Icons.Outlined.SpaceDashboard, "Home"),
                        Triple("Users", Icons.Outlined.Groups, "Users"),
                        Triple("DP", Icons.Outlined.AddCircle, "DP"),
                        Triple("Bonus", Icons.Outlined.CardGiftcard, "Bonus"),
                        Triple("More", Icons.Outlined.GridView, "More")
                    )
                    destinations.forEach { (label, icon, _) ->
                        NavigationBarItem(
                            selected = tab == label,
                            onClick = { tab = label; selectedUser = null },
                            icon = { Icon(icon, contentDescription = label) },
                            label = { Text(label, fontSize = 10.sp, fontWeight = if (tab == label) FontWeight.SemiBold else FontWeight.Normal) },
                            alwaysShowLabel = true,
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = HubGreen,
                                selectedTextColor = HubGreen,
                                indicatorColor = Color(0xFFE4F2E9),
                                unselectedIconColor = HubMuted,
                                unselectedTextColor = HubMuted
                            )
                        )
                    }
                }
            }
        ) { padding ->
            Box(
                Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .background(HubCanvas)
            ) {
                AnimatedContent(
                    targetState = tab,
                    transitionSpec = {
                        (fadeIn(tween(220)) + slideInVertically(tween(220)) { it / 18 }) togetherWith
                            (fadeOut(tween(150)) + slideOutVertically(tween(150)) { -it / 28 })
                    },
                    label = "main_navigation_transition"
                ) { destination ->
                    when (destination) {
                        "Home" -> DashboardScreen(db, users, refresh) { tab = it }
                        "Users" -> UsersPage(users, db, selectedUser, { selectedUser = it }, refresh) { reload() }
                        "DP" -> DpPage(users, db) { reload() }
                        "Bonus" -> BonusPage(users, db) { reload() }
                        "Follow-ups" -> Column(
                            Modifier.fillMaxSize().padding(horizontal = 16.dp).padding(top = 12.dp)
                        ) { FollowUpPage(db) }
                        else -> MorePage(users, db, refresh) { reload() }
                    }
                }
            }
        }
    }
}
