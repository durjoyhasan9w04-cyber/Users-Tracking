import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data/app_database.dart';
import 'services/match_notification_service.dart';
import 'services/fixture_discovery_service.dart';
import 'services/groq_fixture_service.dart';
import 'models/user_level_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UserHubApp());
  unawaited(AppDatabase.instance.createDailyBackupIfNeeded().catchError((_) {}));
  unawaited(MatchNotificationService.initializeAndRestore().catchError((_) {}));
}

const emerald = Color(0xFF3DDC97);
const amber = Color(0xFFF5B94A);
const muted = Color(0xFF8B9B94);
const panel = Color(0xFF111B18);
const bg = Color(0xFF0A110F);
const panelBorder = Color(0xFF1D2A25);

String normalizeContactChannel(String? preference) {
  switch ((preference ?? '').trim().toLowerCase()) {
    case 'whatsapp':
      return 'WhatsApp';
    case 'phone':
    case 'phone call':
    case 'call':
      return 'Phone call';
    case 'sms':
      return 'SMS';
    case 'imo':
      return 'IMO';
    case 'other':
      return 'Other';
    default:
      return 'WhatsApp';
  }
}

final ThemeData userHubTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: const ColorScheme.dark(
    primary: emerald, onPrimary: Color(0xFF062017),
    secondary: amber, onSecondary: Color(0xFF261A00),
    surface: panel, onSurface: Color(0xFFE8F0EC),
    error: Color(0xFFFF7474), onError: Color(0xFF240909),
  ),
  scaffoldBackgroundColor: bg,
  canvasColor: bg,
  textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
    displayLarge: GoogleFonts.spaceGrotesk(fontSize: 34, fontWeight: FontWeight.w700, color: const Color(0xFFE8F0EC), letterSpacing: 0, fontFeatures: const [FontFeature.tabularFigures()]),
    headlineLarge: GoogleFonts.spaceGrotesk(fontSize: 30, fontWeight: FontWeight.w700, color: const Color(0xFFE8F0EC), letterSpacing: 0),
    headlineMedium: GoogleFonts.spaceGrotesk(fontSize: 25, fontWeight: FontWeight.w700, color: const Color(0xFFE8F0EC), letterSpacing: 0),
    titleLarge: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFFE8F0EC), letterSpacing: 0),
    titleMedium: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFFE8F0EC), letterSpacing: 0),
    bodyLarge: GoogleFonts.inter(fontSize: 15, color: const Color(0xFFE8F0EC), letterSpacing: 0),
    bodyMedium: GoogleFonts.inter(fontSize: 13, color: muted, letterSpacing: 0),
    labelLarge: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0),
  ),
  appBarTheme: const AppBarTheme(backgroundColor: bg, surfaceTintColor: Colors.transparent, elevation: 0, foregroundColor: Color(0xFFE8F0EC)),
  cardTheme: CardThemeData(
    color: panel, elevation: 0, margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: panelBorder)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true, fillColor: panel, hintStyle: const TextStyle(color: muted, letterSpacing: 0),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: panelBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: emerald, width: 1.2)),
  ),
  filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
    backgroundColor: emerald, foregroundColor: const Color(0xFF062017),
    minimumSize: const Size(48, 50), padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
    shape: const StadiumBorder(), textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0),
  )),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: emerald, foregroundColor: Color(0xFF062017), elevation: 2, shape: StadiumBorder()),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: panel, indicatorColor: const Color(0xFF1B3B2D), labelBehavior: NavigationDestinationLabelBehavior.alwaysShow, height: 76,
    iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(color: states.contains(WidgetState.selected) ? emerald : muted)),
    labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(color: states.contains(WidgetState.selected) ? emerald : muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0)),
  ),
  chipTheme: const ChipThemeData(backgroundColor: panel, selectedColor: emerald, side: BorderSide(color: panelBorder), shape: StadiumBorder(), padding: EdgeInsets.symmetric(horizontal: 9, vertical: 7)),
  dividerColor: panelBorder,
);

class UserHubApp extends StatelessWidget {
  const UserHubApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(title: 'User Hub', debugShowCheckedModeBanner: false, theme: userHubTheme, home: const MainShell());
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}
class _MainShellState extends State<MainShell> {
  int index = 0;
  int revision = 0;
  void refresh() => setState(() => revision++);
  Future<void> addUser() async {
    final saved = await showDialog<bool>(context: context, builder: (_) => const UserFormDialog());
    if (saved == true) refresh();
  }
  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(key: ValueKey('home-$revision'), onChanged: refresh),
      UsersPage(key: ValueKey('users-$revision'), onChanged: refresh),
      const ActivityPage(),
      const ContactHistoryPage(),
      const MoreHubPage(),
    ];
    const titles = ['Overview', 'Users', 'Activity', 'Contacts', 'More'];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: index == 0 ? 88 : 72,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (index == 0) const Text('Good evening', style: TextStyle(fontSize: 13, color: muted, fontWeight: FontWeight.w500, letterSpacing: 0)),
          Text(titles[index], style: Theme.of(context).textTheme.headlineMedium),
        ]),
        actions: [
          if (index == 1) Padding(padding: const EdgeInsets.only(right: 14), child: IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: emerald, foregroundColor: bg, fixedSize: const Size(46, 46)),
            onPressed: addUser, icon: const Icon(Icons.add_rounded, size: 25),
          )),
          if (index != 1) Padding(padding: const EdgeInsets.only(right: 18), child: CircleAvatar(
            radius: 20, backgroundColor: const Color(0xFF47704C),
            child: ClipOval(child: Image.asset('assets/app_logo.png', width: 40, height: 40, fit: BoxFit.cover)),
          )),
        ],
      ),
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: pages[index]),
      floatingActionButton: index == 0 ? FloatingActionButton.extended(onPressed: addUser, icon: const Icon(Icons.add_rounded), label: const Text('Add user')) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: ClipRRect(borderRadius: BorderRadius.circular(26), child: NavigationBar(
          selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.people_outline_rounded), selectedIcon: Icon(Icons.people_rounded), label: 'Users'),
            NavigationDestination(icon: Icon(Icons.monitor_heart_outlined), selectedIcon: Icon(Icons.monitor_heart_rounded), label: 'Activity'),
            NavigationDestination(icon: Icon(Icons.chat_bubble_outline_rounded), selectedIcon: Icon(Icons.chat_bubble_rounded), label: 'Contacts'),
            NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'More'),
          ],
        )),
      ),
    );
  }
}
