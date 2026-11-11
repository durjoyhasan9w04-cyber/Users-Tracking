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
import 'data/app_database.dart';
import 'services/match_notification_service.dart';
import 'services/fixture_discovery_service.dart';
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
            radius: 20, backgroundColor: const Color(0xFF172820),
            child: Text('UH', style: GoogleFonts.spaceGrotesk(color: emerald, fontWeight: FontWeight.w700)),
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

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month);
    final nextMonth = DateTime(now.year, now.month + 1);
    final previousStart = DateTime(now.year, now.month - 1);
    return FutureBuilder<List<Object?>>(
      future: Future.wait<Object?>([
        AppDatabase.instance.countUsers(),
        AppDatabase.instance.countPotentialUsers(),
        AppDatabase.instance.monthDpTotal(),
        AppDatabase.instance.monthBonusTotal(),
        AppDatabase.instance.countOpenCustomerIssues(),
        AppDatabase.instance.todayDpTotal(),
        AppDatabase.instance.todayDpTransactions(),
        AppDatabase.instance.countFollowUpsDue(),
        AppDatabase.instance.getDpEntries(),
        AppDatabase.instance.getBonusEntries(),
        AppDatabase.instance.getReportTotals(monthStart, nextMonth),
        AppDatabase.instance.getReportTotals(previousStart, monthStart),
        AppDatabase.instance.todayContactMetrics(),
        AppDatabase.instance.todayBonusTotal(),
        AppDatabase.instance.getActivityStatusUsers(),
      ]),
      builder: (context, snap) {
        final data = snap.data;
        final count = (data?[0] as num?)?.toInt() ?? 0;
        final potentialCount = (data?[1] as num?)?.toInt() ?? 0;
        final dpMonth = (data?[2] as num?) ?? 0;
        final bonusMonth = (data?[3] as num?) ?? 0;
        final openIssues = (data?[4] as num?)?.toInt() ?? 0;
        final dpToday = (data?[5] as num?) ?? 0;
        final dpTransactionsToday = (data?[6] as num?)?.toInt() ?? 0;
        final followUpsDue = (data?[7] as num?)?.toInt() ?? 0;
        final dpRows = (data?[8] as List<Map<String, Object?>>?) ?? const [];
        final bonusRows = (data?[9] as List<Map<String, Object?>>?) ?? const [];
        final currentTotals = data?[10] as Map<String, num>?;
        final previousTotals = data?[11] as Map<String, num>?;
        final contactMetrics = data?[12] as Map<String, int>? ?? const <String, int>{};
        final bonusToday = (data?[13] as num?) ?? 0;
        final activityRows = data?[14] as List<Map<String, Object?>>? ?? const [];
        final activeUsers = activityRows.where((r) => r['activity_status'] == 'Active').length;
        final dpFollowUpUsers = activityRows.where((r) => r['activity_status'] == 'Follow-up').length;
        final inactiveUsers = activityRows.where((r) => const ['Inactive', 'Long inactive', 'Very long inactive'].contains(r['activity_status'])).length;
        final neverDpUsers = activityRows.where((r) => r['activity_status'] == 'Never DP').length;
        final contactedToday = contactMetrics['contacted'] ?? 0;
        final notContactedToday = contactMetrics['not_contacted'] ?? 0;
        final multipleDpToday = contactMetrics['multiple_dp'] ?? 0;
        final previousDp = previousTotals?['dp']?.toDouble() ?? 0;
        final delta = previousDp > 0 ? ((dpMonth.toDouble() - previousDp) / previousDp) * 100 : null;
        final recent = <Map<String, Object?>>[
          ...dpRows.take(8).map((r) => <String, Object?>{'kind': 'DP', 'name': r['user_name'], 'date': r['entry_date'], 'amount': r['total']}),
          ...bonusRows.take(8).map((r) => <String, Object?>{'kind': 'Bonus', 'name': r['user_name'], 'date': r['entry_date'], 'amount': r['amount']}),
        ]..sort((a, b) => (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? ''));
        final trend = dpRows.take(7).toList().reversed.map((r) => (r['total'] as num?)?.toDouble() ?? 0).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 132), children: [
          HeroKpiCard(label: 'DP this month', value: dpMonth, delta: delta, sparkline: trend, loading: snap.connectionState == ConnectionState.waiting),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: FilledButton.icon(
              onPressed: () async {
                final saved = await showDialog<bool>(context: context, builder: (_) => const DpEntryDialog());
                if (saved == true) onChanged();
              },
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Record Daily DP'),
              style: FilledButton.styleFrom(backgroundColor: emerald, foregroundColor: bg, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15)),
            )),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(
              onPressed: () async {
                final saved = await showDialog<bool>(context: context, builder: (_) => const BonusEntryDialog());
                if (saved == true) onChanged();
              },
              icon: const Icon(Icons.card_giftcard_rounded),
              label: const Text('Add Daily Bonus'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF355C91), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15)),
            )),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: MetricCard(label: 'Registered users', value: '$count', icon: Icons.people_alt_rounded, dotColor: emerald)),
            const SizedBox(width: 12),
            Expanded(child: MetricCard(label: 'Potential users', value: '$potentialCount', icon: Icons.person_add_alt_1_rounded, dotColor: const Color(0xFF72A8FF))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: MetricCard(label: 'DP today', value: dpToday.toStringAsFixed(dpToday % 1 == 0 ? 0 : 2), icon: Icons.bolt_rounded, dotColor: emerald)),
            const SizedBox(width: 12),
            Expanded(child: MetricCard(label: 'Bonus today', value: bonusToday.toStringAsFixed(bonusToday % 1 == 0 ? 0 : 2), icon: Icons.card_giftcard_rounded, dotColor: amber, amberValue: true)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: MetricCard(label: 'Bonus this month', value: bonusMonth.toStringAsFixed(bonusMonth % 1 == 0 ? 0 : 2), icon: Icons.redeem_rounded, dotColor: amber, amberValue: true)),
            const SizedBox(width: 12),
            Expanded(child: MetricCard(label: 'Active DP users', value: '$activeUsers', icon: Icons.bolt_rounded, dotColor: emerald)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: MetricCard(label: 'DP follow-up', value: '$dpFollowUpUsers', icon: Icons.event_available_rounded, dotColor: const Color(0xFF72A8FF))),
            const SizedBox(width: 12),
            Expanded(child: MetricCard(label: 'Inactive users', value: '$inactiveUsers', icon: Icons.pause_circle_outline_rounded, dotColor: amber, amberValue: true)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: MetricCard(label: 'Never DP', value: '$neverDpUsers', icon: Icons.person_off_outlined)),
            const SizedBox(width: 12),
            Expanded(child: MetricCard(label: 'Multiple DP today', value: '$multipleDpToday', icon: Icons.bolt_rounded, dotColor: const Color(0xFF72A8FF))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: MetricCard(label: 'Contacted today', value: '$contactedToday', icon: Icons.mark_chat_read_rounded, dotColor: emerald)),
            const SizedBox(width: 12),
            Expanded(child: MetricCard(label: 'Not contacted', value: '$notContactedToday', icon: Icons.mark_chat_unread_rounded, dotColor: amber, amberValue: true)),
          ]),
          const SizedBox(height: 27),
          const SectionHeading('Recent activity', trailing: 'Latest'),
          const SizedBox(height: 12),
          if (snap.connectionState == ConnectionState.waiting)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (recent.isEmpty)
            const EmptyState(title: 'Your activity starts here', subtitle: 'DP and bonus entries will appear here as they are recorded.', icon: Icons.auto_graph_rounded, compact: true)
          else
            Card(child: Column(children: [
              for (var i = 0; i < recent.take(4).length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 68, endIndent: 18),
                _RecentActivityTile(event: recent[i]),
              ],
            ])),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _DashboardAlertTile(title: 'Follow-ups due', value: '$followUpsDue', subtitle: 'Due today or earlier', icon: Icons.event_available_rounded, color: emerald, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FollowUpsPage())))),
            const SizedBox(width: 10),
            Expanded(child: _DashboardAlertTile(title: 'Open issues', value: '$openIssues', subtitle: 'Need attention', icon: Icons.support_agent_rounded, color: amber, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerIssuesPage())))),
          ]),
          const SizedBox(height: 8),
          Text('$dpTransactionsToday DP transactions recorded today · ${currentTotals?['dp_count'] ?? 0} this month', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted), textAlign: TextAlign.center),
        ]);
      },
    );
  }
}

class HeroKpiCard extends StatelessWidget {
  const HeroKpiCard({super.key, required this.label, required this.value, required this.delta, required this.sparkline, required this.loading});
  final String label; final num value; final double? delta; final List<double> sparkline; final bool loading;
  @override
  Widget build(BuildContext context) {
    final deltaText = delta == null ? 'MONTH TO DATE' : '${delta! >= 0 ? '+' : ''}${delta!.toStringAsFixed(1)}%';
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
      decoration: BoxDecoration(color: const Color(0xFF12271E), borderRadius: BorderRadius.circular(27), border: Border.all(color: const Color(0xFF1B4A35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: muted, fontSize: 14, letterSpacing: 0))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: const Color(0xFF1B4934), borderRadius: BorderRadius.circular(30)), child: Text(deltaText, style: const TextStyle(color: emerald, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0))),
        ]),
        const SizedBox(height: 10),
        loading ? const SizedBox(height: 58, child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 110, child: LinearProgressIndicator()))) : AnimatedNumberText(value: value.toDouble(), style: GoogleFonts.spaceGrotesk(fontSize: 48, fontWeight: FontWeight.w700, color: const Color(0xFFE8F0EC), letterSpacing: 0, fontFeatures: const [FontFeature.tabularFigures()])),
        const SizedBox(height: 12),
        SizedBox(height: 62, width: double.infinity, child: CustomPaint(painter: SparklinePainter(values: sparkline))),
      ]),
    );
  }
}

class SparklinePainter extends CustomPainter {
  const SparklinePainter({required this.values});
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final points = values.isEmpty ? List<double>.filled(7, 0) : values.length == 1 ? List<double>.filled(7, values.first) : values;
    final minValue = points.reduce((a, b) => a < b ? a : b);
    final maxValue = points.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.001 ? 1.0 : maxValue - minValue;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1 ? size.width : size.width * i / (points.length - 1);
      final y = size.height - 7 - ((points[i] - minValue) / range) * (size.height - 18);
      if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
    }
    canvas.drawPath(path, Paint()..color = emerald..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }
  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) => oldDelegate.values != values;
}

class AnimatedNumberText extends StatelessWidget {
  const AnimatedNumberText({super.key, required this.value, required this.style});
  final double value; final TextStyle style;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: value), duration: const Duration(milliseconds: 950), curve: Curves.easeOutCubic,
    builder: (context, current, _) => Text(NumberFormat('#,##0.##').format(current), style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
  );
}

class _RecentActivityTile extends StatelessWidget {
  const _RecentActivityTile({required this.event});
  final Map<String, Object?> event;
  @override
  Widget build(BuildContext context) {
    final isDp = event['kind'] == 'DP';
    final amount = (event['amount'] as num?)?.toDouble() ?? 0;
    final date = event['date'] as String? ?? '';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
      leading: CircleAvatar(backgroundColor: const Color(0xFF172820), child: Text(_initials(event['name'] as String? ?? 'User'), style: const TextStyle(color: emerald, fontWeight: FontWeight.w700))),
      title: Text(event['name'] as String? ?? 'User', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text('${isDp ? 'DP recorded' : 'Bonus added'} · $date', style: const TextStyle(color: muted, fontSize: 11)),
      trailing: Text('+${NumberFormat('#,##0.##').format(amount)}', style: TextStyle(color: isDp ? emerald : amber, fontWeight: FontWeight.w800, fontSize: 15)),
    );
  }
}

class _DashboardAlertTile extends StatelessWidget {
  const _DashboardAlertTile({required this.title, required this.value, required this.subtitle, required this.icon, required this.color, required this.onTap});
  final String title, value, subtitle; final IconData icon; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(22), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Icon(icon, color: color, size: 19), const SizedBox(height: 9),
    Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 24, fontWeight: FontWeight.w700, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    Text(subtitle, style: const TextStyle(fontSize: 10, color: muted)),
  ]))));
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}
String dpLevel(double amount, {required bool monthly, UserLevelConfig config = UserLevelConfig.defaults}) =>
    config.labelFor(amount, monthly: monthly);

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override State<UsersPage> createState() => _UsersPageState();
}
class _UsersPageState extends State<UsersPage> {
  final search = TextEditingController();
  late final Timer _relativeClock;
  String lifetimeFilter = 'All';
  String monthlyFilter = 'All';
  late Future<List<Object?>> future;
  @override void initState() { super.initState(); load(); search.addListener(load); _relativeClock = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) setState(() {}); }); }
  void load() => setState(() => future = Future.wait<Object?>([
    AppDatabase.instance.getUsers(search: search.text),
    AppDatabase.instance.getUserLevelConfig(),
  ]));
  @override void dispose() { _relativeClock.cancel(); search.removeListener(load); search.dispose(); super.dispose(); }
  Future<void> edit(Map<String, Object?>? user) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => UserFormDialog(user: user));
    if (ok == true) { load(); widget.onChanged(); }
  }
  Future<void> archive(Map<String, Object?> user) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Archive user?'),
      content: Text('Archive ${user['name']}? Their profile will be hidden from this list.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive'))],
    ));
    if (ok == true) { await AppDatabase.instance.archiveUser(user['id'] as int); load(); widget.onChanged(); }
  }
  Widget filterRow(String label, String selected, ValueChanged<String> onSelected, List<String> levelLabels) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(children: [
      SizedBox(width: 66, child: Text(label, style: const TextStyle(fontSize: 10, color: muted, fontWeight: FontWeight.w800))),
      Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        for (final item in ['All', ...levelLabels])
          Padding(padding: const EdgeInsets.only(right: 7), child: ChoiceChip(
            label: Text(item), selected: selected == item, onSelected: (_) => onSelected(item), showCheckmark: false,
            selectedColor: emerald, labelStyle: TextStyle(color: selected == item ? bg : muted, fontWeight: selected == item ? FontWeight.w800 : FontWeight.w500),
            side: BorderSide(color: selected == item ? emerald : panelBorder),
          )),
      ]))),
    ]),
  );
  @override Widget build(BuildContext context) => FutureBuilder<List<Object?>>(
    future: future,
    builder: (context, snap) {
      final config = snap.data?[1] as UserLevelConfig? ?? UserLevelConfig.defaults;
      final allRows = (snap.data?[0] as List<Map<String, Object?>>?) ?? const [];
      final levelLabels = config.tiers.reversed.map((tier) => tier.label).toList();
      final rows = allRows.where((user) {
        final lifetime = dpLevel((user['lifetime_dp'] as num).toDouble(), monthly: false, config: config);
        final monthly = dpLevel((user['monthly_dp'] as num).toDouble(), monthly: true, config: config);
        return (lifetimeFilter == 'All' || lifetime == lifetimeFilter) &&
            (monthlyFilter == 'All' || monthly == monthlyFilter);
      }).toList();
      return Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: TextField(
          controller: search,
          decoration: const InputDecoration(hintText: 'Search by name or phone', prefixIcon: Icon(Icons.search_rounded)),
        )),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: Column(children: [
          filterRow('LIFETIME', lifetimeFilter, (v) => setState(() => lifetimeFilter = v), levelLabels),
          filterRow('MONTHLY', monthlyFilter, (v) => setState(() => monthlyFilter = v), levelLabels),
        ])),
        Expanded(child: snap.connectionState == ConnectionState.waiting
            ? const Center(child: CircularProgressIndicator())
            : rows.isEmpty
                ? EmptyState(
                    title: search.text.isEmpty ? 'No users yet' : 'No matching users',
                    subtitle: search.text.isEmpty ? 'Add your first profile to start building your user list.' : 'Try another name or phone number.',
                    icon: Icons.group_add_rounded,
                    action: search.text.isEmpty ? () => edit(null) : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 34),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final user = rows[i];
                      final name = user['name'] as String;
                      final lifetimeIndex = config.indexFor((user['lifetime_dp'] as num).toDouble(), monthly: false);
                      final monthlyIndex = config.indexFor((user['monthly_dp'] as num).toDouble(), monthly: true);
                      final lifetime = config.tiers[lifetimeIndex].label;
                      final monthly = config.tiers[monthlyIndex].label;
                      return Card(child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        leading: CircleAvatar(radius: 23, backgroundColor: const Color(0xFF172820), child: Text(_initials(name), style: const TextStyle(color: emerald, fontWeight: FontWeight.w800))),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [ Text(_maskPhone(user['phone'] as String), style: const TextStyle(color: muted, fontSize: 12)), const SizedBox(height: 3), Text(user['latest_dp_at'] == null ? 'No DP history' : 'DP ${_timeSinceDp(user['latest_dp_at'] as String)}', style: TextStyle(color: user['latest_dp_at'] == null ? muted : emerald, fontSize: 11, fontWeight: FontWeight.w600)), ]),
                        trailing: SizedBox(width: 125, child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('L${lifetimeIndex + 1} · $lifetime', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: lifetimeIndex == 3 ? amber : emerald, fontWeight: FontWeight.w800, fontSize: 11)),
                          Text('M${monthlyIndex + 1} · $monthly', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 10)),
                        ])),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => UserProfilePage(userId: user['id'] as int, onChanged: () { load(); widget.onChanged(); }))),
                        onLongPress: () => archive(user),
                      ));
                    },
                  )),
      ]);
    },
  );
}

String _timeSinceDp(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return 'time unavailable';
  final elapsed = DateTime.now().difference(parsed);
  if (elapsed.isNegative) return 'just now';
  if (elapsed.inDays >= 1) return '${elapsed.inDays} ${elapsed.inDays == 1 ? 'day' : 'days'} ago';
  if (elapsed.inHours >= 1) return '${elapsed.inHours} ${elapsed.inHours == 1 ? 'hour' : 'hours'} ago';
  if (elapsed.inMinutes >= 1) return '${elapsed.inMinutes} ${elapsed.inMinutes == 1 ? 'minute' : 'minutes'} ago';
  return 'just now';
}

String _maskPhone(String phone) {
  if (phone.length < 7) return phone;
  return '${phone.substring(0, 2)}••• ••${phone.substring(phone.length - 3)}';
}
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.userId, required this.onChanged});
  final int userId;
  final VoidCallback onChanged;
  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late Future<List<Object?>> data;
  @override
  void initState() { super.initState(); load(); }
  void load() {
    data = Future.wait<Object?>([
      AppDatabase.instance.getUserProfile(widget.userId),
      AppDatabase.instance.getUserTimeline(widget.userId),
      AppDatabase.instance.getUserDpInsights(widget.userId),
      AppDatabase.instance.getUserLevelConfig(),
      AppDatabase.instance.getContactReminders(userId: widget.userId),
    ]);
  }
  Future<void> edit(Map<String, Object?> user) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => UserFormDialog(user: user));
    if (saved == true && mounted) { setState(load); widget.onChanged(); }
  }
  Future<void> recordContact(Map<String, Object?> user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ContactLogDialog(users: [user], initialUserId: widget.userId),
    );
    if (saved == true && mounted) { setState(load); widget.onChanged(); }
  }
  Future<void> setContactReminder(Map<String, Object?> user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ContactReminderDialog(userId: widget.userId, userName: user['name'] as String? ?? 'User'),
    );
    if (saved == true && mounted) { setState(load); widget.onChanged(); }
  }
  Future<void> completeReminder(int id) async {
    await AppDatabase.instance.completeContactReminder(id);
    await MatchNotificationService.cancelContactReminder(id);
    if (mounted) { setState(load); widget.onChanged(); }
  }
  Future<void> cancelReminder(int id) async {
    await AppDatabase.instance.deleteContactReminder(id);
    await MatchNotificationService.cancelContactReminder(id);
    if (mounted) { setState(load); widget.onChanged(); }
  }
  String amount(Object? value) {
    final n = (value as num?)?.toDouble() ?? 0;
    return n.toStringAsFixed(n % 1 == 0 ? 0 : 2);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('User profile')),
    body: FutureBuilder<List<Object?>>(
      future: data,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError || snap.data == null || snap.data![0] == null) {
          return const EmptyState(title: 'Profile unavailable', subtitle: 'This user profile could not be loaded.');
        }
        final user = snap.data![0] as Map<String, Object?>;
        final timeline = snap.data![1] as List<Map<String, Object?>>;
        final insights = snap.data![2] as Map<String, Object?>;
        final levelConfig = snap.data![3] as UserLevelConfig? ?? UserLevelConfig.defaults;
        final reminders = snap.data![4] as List<Map<String, Object?>>? ?? const [];
        final lifetimeLevel = levelConfig.labelFor((user['lifetime_dp'] as num? ?? 0).toDouble(), monthly: false);
        final monthlyLevel = levelConfig.labelFor((user['monthly_dp'] as num? ?? 0).toDouble(), monthly: true);
        final name = user['name'] as String? ?? 'User';
        final lastDp = user['last_dp_date'] as String?;
        final daysSinceLastDp = user['days_since_last_dp'] as int?;
        final lastContact = user['last_contact_date'] as String?;
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          children: [
            Card(child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(radius: 27, backgroundColor: const Color(0xFF183B36), child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: emerald, fontSize: 20, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 13),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(user['phone'] as String? ?? '', style: const TextStyle(color: muted)),
                  ])),
                  IconButton(onPressed: () => edit(user), icon: const Icon(Icons.edit_outlined)),
                ]),
                if ((user['notes'] as String? ?? '').isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(user['notes'] as String, style: const TextStyle(color: muted)),
                ],
                const SizedBox(height: 14),
                Text('Added: ${(user['created_at'] as String? ?? '').split('T').first}', style: const TextStyle(color: muted, fontSize: 12)),
                Text('Last DP: ${lastDp == null ? 'Never' : daysSinceLastDp == 0 ? 'Today' : daysSinceLastDp == 1 ? 'Yesterday' : '$daysSinceLastDp days ago · $lastDp'}', style: const TextStyle(color: muted, fontSize: 12)),
                Text('Last contact: ${lastContact ?? 'Not recorded'}', style: const TextStyle(color: muted, fontSize: 12)),
                if ((user['preferred_language'] as String? ?? '').isNotEmpty)
                  Text('Preferred language: ${user['preferred_language']}', style: const TextStyle(color: muted, fontSize: 12)),
                if ((user['preferred_contact_method'] as String? ?? '').isNotEmpty)
                  Text('Preferred contact: ${user['preferred_contact_method']}', style: const TextStyle(color: muted, fontSize: 12)),
              ]),
            )),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: FilledButton.icon(
                onPressed: () => recordContact(user),
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('Record Contact'),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                onPressed: () => setContactReminder(user),
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Set Reminder'),
              )),
            ]),
            if (reminders.isNotEmpty) ...[
              const SizedBox(height: 14),
              const SectionHeading('Contact reminders', trailing: 'Repeats daily'),
              const SizedBox(height: 8),
              ...reminders.map((reminder) {
                final when = DateTime.tryParse(reminder['remind_at'] as String? ?? '');
                final reminderId = reminder['id'] as int;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFF3A3020), child: Icon(Icons.notifications_active_outlined, color: amber)),
                    title: Text(when == null ? 'Scheduled reminder' : DateFormat('EEE, d MMM · h:mm a').format(when.toLocal())),
                    subtitle: Text('${(reminder['reason'] as String? ?? '').isEmpty ? 'Contact this user' : reminder['reason']}\nRepeats daily until completed'),
                    isThreeLine: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        tooltip: 'Mark reminder completed',
                        onPressed: () => completeReminder(reminderId),
                        icon: const Icon(Icons.check_circle_outline_rounded, color: emerald),
                      ),
                      IconButton(
                        tooltip: 'Cancel reminder',
                        onPressed: () => cancelReminder(reminderId),
                        icon: const Icon(Icons.close_rounded, color: muted),
                      ),
                    ]),
                  ),
                );
              }),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: MetricCard(label: 'Lifetime DP', value: amount(user['lifetime_dp']), icon: Icons.account_balance_wallet_rounded)),
              const SizedBox(width: 10),
              Expanded(child: MetricCard(label: 'Lifetime bonus', value: amount(user['lifetime_bonus']), icon: Icons.card_giftcard_rounded)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: MetricCard(label: 'DP records', value: '${user['dp_transactions']}', icon: Icons.receipt_long_rounded)),
              const SizedBox(width: 10),
              Expanded(child: MetricCard(label: 'Bonus records', value: '${user['bonus_transactions']}', icon: Icons.redeem_rounded)),
            ]),
            const SizedBox(height: 12),
            Card(child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('LIFETIME LEVEL', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(lifetimeLevel, style: const TextStyle(color: emerald, fontWeight: FontWeight.w800, fontSize: 15)),
                ])),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('MONTHLY LEVEL', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(monthlyLevel, style: const TextStyle(color: emerald, fontWeight: FontWeight.w800, fontSize: 15)),
                ])),
              ]),
            )),
            const SizedBox(height: 20),
            const SectionHeading('DP behaviour · Last 30 days', trailing: 'Recent pattern'),
            if ((insights['usual_time_records'] as int? ?? 0) >= 3 &&
                insights['usual_minute'] is num)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Usual DP entry time: ${TimeOfDay(hour: (insights['usual_minute'] as num).round() ~/ 60, minute: (insights['usual_minute'] as num).round() % 60).format(context)} · based on ${insights['usual_time_records']} records',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: MetricCard(label: 'DP total · 30 days', value: amount(insights['total']), icon: Icons.account_balance_wallet_rounded)),
              const SizedBox(width: 10),
              Expanded(child: MetricCard(label: 'Active DP days', value: '${insights['active_days']}', icon: Icons.calendar_today_rounded)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: MetricCard(label: 'Average per DP day', value: amount(insights['average_per_day']), icon: Icons.trending_up_rounded)),
              const SizedBox(width: 10),
              Expanded(child: MetricCard(label: 'Highest DP day', value: amount(insights['highest_day']), icon: Icons.emoji_events_outlined)),
            ]),
            const SizedBox(height: 8),
            Text(
              insights['average_gap'] == null
                  ? 'Average gap between DP days: Not enough activity yet'
                  : 'Average gap between DP days: ${(insights['average_gap'] as num).toStringAsFixed(1)} days',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 20),
            const SectionHeading('Activity timeline', trailing: 'Newest first'),
            const SizedBox(height: 10),
            if (timeline.isEmpty)
              const EmptyState(title: 'No activity recorded', subtitle: 'DP, bonus, contact and issue history will appear here.')
            else
              ...timeline.map((event) {
                final kind = event['kind'] as String? ?? 'Activity';
                final date = event['event_date'] as String? ?? '';
                final detail = event['detail'] as String? ?? '';
                final icon = kind == 'DP' ? Icons.account_balance_wallet_outlined : kind == 'Bonus' ? Icons.card_giftcard_outlined : kind == 'Contact' ? Icons.chat_bubble_outline : Icons.support_agent_outlined;
                final value = event['amount'];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: const Color(0xFF183B36), child: Icon(icon, color: emerald)),
                    title: Text(kind, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('$date · $detail'),
                    trailing: value == null ? null : Text(amount(value), style: const TextStyle(color: emerald, fontWeight: FontWeight.w800)),
                  ),
                );
              }),
          ],
        );
      },
    ),
  );
}

class UserFormDialog extends StatefulWidget {
  const UserFormDialog({super.key, this.user});
  final Map<String, Object?>? user;
  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}
class _UserFormDialogState extends State<UserFormDialog> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.user?['name'] as String? ?? '');
  late final phone = TextEditingController(text: widget.user?['phone'] as String? ?? '');
  late final notes = TextEditingController(text: widget.user?['notes'] as String? ?? '');
  late final preferredLanguage = TextEditingController(text: widget.user?['preferred_language'] as String? ?? '');
  late final preferredContactMethod = TextEditingController(text: widget.user?['preferred_contact_method'] as String? ?? '');
  bool saving = false;
  bool hasPreviousDp = false;
  DateTime? previousDpAt;
  late bool doNotContact = (widget.user?['do_not_contact'] as int? ?? 0) == 1;
  @override
  void dispose() { name.dispose(); phone.dispose(); notes.dispose(); preferredLanguage.dispose(); preferredContactMethod.dispose(); super.dispose(); }
  Future<void> choosePreviousDpAt() async {
    final now = DateTime.now();
    final initial = previousDpAt ?? now;
    final date = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: now);
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    final chosen = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (chosen.isAfter(now)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Previous DP time cannot be in the future.'))); return; }
    setState(() => previousDpAt = chosen);
  }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (widget.user == null && hasPreviousDp && previousDpAt == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose the previous DP date and time.'))); return; }
    setState(() => saving = true);
    try {
      if (widget.user == null) {
        await AppDatabase.instance.addUser(name: name.text, phone: phone.text, notes: notes.text, doNotContact: doNotContact, preferredLanguage: preferredLanguage.text, preferredContactMethod: preferredContactMethod.text, hasPreviousDp: hasPreviousDp, previousDpAt: hasPreviousDp ? previousDpAt : null);
      } else {
        await AppDatabase.instance.updateUser(id: widget.user!['id'] as int, name: name.text, phone: phone.text, notes: notes.text, doNotContact: doNotContact, preferredLanguage: preferredLanguage.text, preferredContactMethod: preferredContactMethod.text);
        unawaited(MatchNotificationService.rescheduleAllUpcoming().catchError((_) {}));
      }
      if (mounted) Navigator.pop(context, true);
    } on DuplicatePhoneException catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on DatabaseException catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        e.isUniqueConstraintError() ? 'That phone number is already registered.' : 'Could not save this profile.',
      )));
    }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.user == null ? 'Add user' : 'Edit user'),
    content: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Full name'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null),
      const SizedBox(height: 12),
      TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number'), validator: (v) => v == null || v.trim().length < 5 ? 'Enter a valid phone number' : null),
      if (widget.user == null) ...[
        const SizedBox(height: 12),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: hasPreviousDp, onChanged: saving ? null : (value) => setState(() { hasPreviousDp = value; if (!value) previousDpAt = null; }), title: const Text('Has deposited before?'), subtitle: const Text('Record the date and time of their previous DP.')),
        if (hasPreviousDp) ...[
          Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: saving ? null : choosePreviousDpAt, icon: const Icon(Icons.schedule_rounded), label: Text(previousDpAt == null ? 'Choose previous DP date & time' : DateFormat('dd MMM yyyy · hh:mm a').format(previousDpAt!)))),
          if (previousDpAt == null) const Align(alignment: Alignment.centerLeft, child: Text('Please select when the previous DP happened.', style: TextStyle(color: amber, fontSize: 12))),
        ],
      ],
      const SizedBox(height: 12),
      TextFormField(controller: preferredLanguage, decoration: const InputDecoration(labelText: 'Preferred language (optional)', hintText: 'e.g. Bangla, English')),
      const SizedBox(height: 12),
      TextFormField(controller: preferredContactMethod, decoration: const InputDecoration(labelText: 'Preferred contact method (optional)', hintText: 'e.g. WhatsApp, Phone call, SMS, IMO')),
      const SizedBox(height: 12),
      TextFormField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes (optional)')),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: doNotContact,
        onChanged: saving ? null : (value) => setState(() => doNotContact = value),
        title: const Text('Do not contact'),
        subtitle: const Text('Exclude this user from match reminders and contact prompts.'),
      ),
    ]))),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save user')),
    ],
  );
}


class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});
  @override
  State<ActivityPage> createState() => _ActivityPageState();
}
class _ActivityPageState extends State<ActivityPage> {
  String section = 'dp';
  late Future<List<Map<String, Object?>>> dpEntries;
  late Future<List<Map<String, Object?>>> bonusEntries;
  @override
  void initState() {
    super.initState();
    load();
  }
  void load() {
    dpEntries = AppDatabase.instance.getDpEntries();
    bonusEntries = AppDatabase.instance.getBonusEntries();
  }
  Future<void> addRecord() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => section == 'dp' ? const DpEntryDialog() : const BonusEntryDialog(),
    );
    if (!mounted) return;
    if (saved == true) setState(load);
  }

  Future<void> editRecord(Map<String, Object?> row, bool isDp) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => isDp ? DpEntryDialog(existing: row) : BonusEntryDialog(existing: row),
    );
    if (mounted && saved == true) setState(load);
  }

  Future<void> deleteRecord(Map<String, Object?> row, bool isDp) async {
    final label = isDp ? 'DP record' : 'bonus record';
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Delete $label?'),
      content: const Text('This record will be removed from totals and history. A deletion entry will be kept in the audit log.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
      ],
    ));
    if (confirmed != true) return;
    if (isDp) {
      await AppDatabase.instance.deleteDpEntry(row['id'] as int);
    } else {
      await AppDatabase.instance.deleteBonusEntry(row['id'] as int);
    }
    if (mounted) setState(load);
  }
  @override
  Widget build(BuildContext context) {
    final isDp = section == 'dp';
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(children: [
          Expanded(child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(20), border: Border.all(color: panelBorder)),
            child: Row(children: [
              _ActivitySegment(label: 'DP', selected: section == 'dp', onTap: () => setState(() => section = 'dp')),
              _ActivitySegment(label: 'Bonuses', selected: section == 'bonus', onTap: () => setState(() => section = 'bonus')),
            ]),
          )),
          const SizedBox(width: 10),
          FilledButton.icon(onPressed: addRecord, icon: const Icon(Icons.add, size: 18), label: Text(isDp ? 'Record' : 'Add bonus')),
        ]),
      ),
      Expanded(child: FutureBuilder<List<Map<String, Object?>>>(
        future: isDp ? dpEntries : bonusEntries,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final rows = snap.data ?? [];
          if (rows.isEmpty) {
            return EmptyState(
              title: isDp ? 'No DP records yet' : 'No bonus records yet',
              subtitle: isDp ? 'Record your first DP entry to start building your activity history.' : 'Add your first bonus record to keep its history separate from DP.',
              icon: isDp ? Icons.account_balance_wallet_rounded : Icons.card_giftcard_rounded,
              action: addRecord,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 9),
            itemBuilder: (context, i) {
              final row = rows[i];
              final amount = (row[isDp ? 'total' : 'amount'] as num).toDouble();
              final date = row['entry_date'] as String;
              return Card(child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF183B36),
                  child: Icon(isDp ? Icons.account_balance_wallet_outlined : Icons.card_giftcard_rounded, color: emerald),
                ),
                title: Text(row['user_name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  isDp ? '$date  •  ${row['dp_count']} DP' : '$date  •  ${row['reason']}',
                  style: const TextStyle(color: muted),
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2),
                    style: TextStyle(color: isDp ? emerald : const Color(0xFFFFC36B), fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') editRecord(row, isDp);
                      if (value == 'delete') deleteRecord(row, isDp);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit record')),
                      PopupMenuItem(value: 'delete', child: Text('Delete record')),
                    ],
                  ),
                ]),
              ));
            },
          );
        },
      )),
    ]);
  }
}

class _ActivitySegment extends StatelessWidget {
  const _ActivitySegment({required this.label, required this.selected, required this.onTap});
  final String label; final bool selected; final VoidCallback onTap;
  @override Widget build(BuildContext context) => Expanded(child: InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(15),
    child: AnimatedContainer(duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(color: selected ? const Color(0xFF1B3328) : Colors.transparent, borderRadius: BorderRadius.circular(15)),
      child: Center(child: Text(label, style: TextStyle(color: selected ? emerald : muted, fontWeight: FontWeight.w700))),
    ),
  ));
}
class BonusEntryDialog extends StatefulWidget {
  const BonusEntryDialog({super.key, this.existing});
  final Map<String, Object?>? existing;
  @override
  State<BonusEntryDialog> createState() => _BonusEntryDialogState();
}
class _BonusEntryDialogState extends State<BonusEntryDialog> {
  final form = GlobalKey<FormState>();
  final amount = TextEditingController();
  final relatedDp = TextEditingController();
  final notes = TextEditingController();
  int? userId;
  String userSearch = '';
  String reason = 'Deposit';
  bool saving = false;
  late Future<List<Map<String, Object?>>> users;
  @override
  void initState() {
    super.initState();
    final row = widget.existing;
    if (row != null) {
      userId = row['user_id'] as int;
      amount.text = (row['amount'] as num).toString();
      reason = row['reason'] as String? ?? 'Other';
      relatedDp.text = row['related_dp'] == null ? '' : (row['related_dp'] as num).toString();
      notes.text = row['notes'] as String? ?? '';
    }
    users = AppDatabase.instance.getUsers(includeArchivedId: userId);
  }
  @override
  void dispose() {
    amount.dispose();
    relatedDp.dispose();
    notes.dispose();
    super.dispose();
  }
  Future<void> save() async {
    if (!form.currentState!.validate() || userId == null) return;
    setState(() => saving = true);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await AppDatabase.instance.addBonusEntry(
          userId: userId!,
          date: DateTime.now(),
          amount: double.parse(amount.text.trim()),
          reason: reason,
          relatedDp: relatedDp.text.trim().isEmpty ? null : double.parse(relatedDp.text.trim()),
          notes: notes.text,
        );
      } else {
        await AppDatabase.instance.updateBonusEntry(
          id: existing['id'] as int,
          userId: userId!,
          amount: double.parse(amount.text.trim()),
          reason: reason,
          relatedDp: relatedDp.text.trim().isEmpty ? null : double.parse(relatedDp.text.trim()),
          notes: notes.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on Exception {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save this bonus record.')));
    }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add bonus record' : 'Edit bonus record'),
    content: SizedBox(width: 420, child: FutureBuilder<List<Map<String, Object?>>>(
      future: users,
      builder: (context, snap) {
        final rows = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator()));
        if (rows.isEmpty) return const Text('Add a registered user before recording a bonus.');
        userId ??= rows.first['id'] as int;
        final filteredUsers = rows.where((u) => '${u['name']} ${u['phone']}'.toLowerCase().contains(userSearch.toLowerCase())).toList();
        if (!filteredUsers.any((u) => u['id'] == userId) && filteredUsers.isNotEmpty) userId = filteredUsers.first['id'] as int;
        return Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(onChanged: (value) => setState(() => userSearch = value), decoration: const InputDecoration(labelText: 'Search user by name or number', prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: filteredUsers.any((u) => u['id'] == userId) ? userId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'User'),
            items: filteredUsers.map((u) => DropdownMenuItem<int>(value: u['id'] as int, child: Text('${u['name']} · ${u['phone']}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: saving ? null : (v) => setState(() => userId = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Bonus amount (coins)'),
            validator: (v) {
              final n = double.tryParse(v?.trim() ?? '');
              return n == null || n <= 0 ? 'Enter an amount greater than zero' : null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: const ['Deposit', 'Special', 'Promotional', 'Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: saving ? null : (v) => setState(() => reason = v ?? 'Other'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: relatedDp,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Related DP (optional)'),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final n = double.tryParse(v.trim());
              return n == null || n < 0 ? 'Enter a valid amount' : null;
            },
          ),
          const SizedBox(height: 12),
          TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
        ])));
      },
    )),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.existing == null ? 'Save bonus' : 'Save changes')),
    ],
  );
}

class DpEntryDialog extends StatefulWidget {
  const DpEntryDialog({super.key, this.existing});
  final Map<String, Object?>? existing;
  @override
  State<DpEntryDialog> createState() => _DpEntryDialogState();
}
class _DpEntryDialogState extends State<DpEntryDialog> {
  final form = GlobalKey<FormState>();
  final amounts = List.generate(5, (_) => TextEditingController());
  final notes = TextEditingController();
  int? userId;
  String userSearch = '';
  bool contacted = false;
  bool saving = false;
  late Future<List<Map<String, Object?>>> users;
  @override
  void initState() {
    super.initState();
    final row = widget.existing;
    if (row != null) {
      userId = row['user_id'] as int;
      for (var i = 0; i < 5; i++) {
        amounts[i].text = (row['dp${i + 1}'] as num).toString();
      }
      contacted = (row['contacted'] as int? ?? 0) == 1;
      notes.text = row['notes'] as String? ?? '';
    }
    users = AppDatabase.instance.getUsers(includeArchivedId: userId);
  }
  @override
  void dispose() { for (final c in amounts) { c.dispose(); } notes.dispose(); super.dispose(); }
  Future<void> save() async {
    if (!form.currentState!.validate() || userId == null) return;
    final values = amounts.map((c) => double.tryParse(c.text.trim()) ?? 0).toList();
    if (!values.any((v) => v > 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter at least one DP amount.')));
      return;
    }
    setState(() => saving = true);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await AppDatabase.instance.addDpEntry(userId: userId!, date: DateTime.now(), amounts: values, contacted: contacted, notes: notes.text);
      } else {
        await AppDatabase.instance.updateDpEntry(id: existing['id'] as int, userId: userId!, amounts: values, contacted: contacted, notes: notes.text);
      }
      if (mounted) Navigator.pop(context, true);
    } on Exception {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save this DP record.')));
    }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Record daily DP' : 'Edit DP record'),
    content: SizedBox(width: 420, child: FutureBuilder<List<Map<String, Object?>>>(
      future: users,
      builder: (context, snap) {
        final rows = snap.data ?? [];
        if (snap.connectionState == ConnectionState.waiting) return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator()));
        if (rows.isEmpty) return const Text('Add a registered user before recording DP.');
        userId ??= rows.first['id'] as int;
        final filteredUsers = rows.where((u) => '${u['name']} ${u['phone']}'.toLowerCase().contains(userSearch.toLowerCase())).toList();
        if (!filteredUsers.any((u) => u['id'] == userId) && filteredUsers.isNotEmpty) userId = filteredUsers.first['id'] as int;
        return Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(onChanged: (value) => setState(() => userSearch = value), decoration: const InputDecoration(labelText: 'Search user by name or number', prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: filteredUsers.any((u) => u['id'] == userId) ? userId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'User'),
            items: filteredUsers.map((u) => DropdownMenuItem<int>(value: u['id'] as int, child: Text('${u['name']} · ${u['phone']}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: saving ? null : (v) => setState(() => userId = v),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < 5; i++) ...[
            TextFormField(
              controller: amounts[i],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'DP ${i + 1} (coins)', hintText: 'Optional'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = double.tryParse(v);
                return n == null || n < 0 ? 'Enter a valid non-negative amount' : null;
              },
            ),
            const SizedBox(height: 8),
          ],
          TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: contacted,
            onChanged: saving ? null : (v) => setState(() => contacted = v ?? false),
            title: const Text('Contacted today'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ])));
      },
    )),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.existing == null ? 'Save DP' : 'Save changes')),
    ],
  );
}

class PotentialUsersPage extends StatefulWidget {
  const PotentialUsersPage({super.key});
  @override
  State<PotentialUsersPage> createState() => _PotentialUsersPageState();
}
class _PotentialUsersPageState extends State<PotentialUsersPage> {
  final search = TextEditingController();
  late Future<List<Map<String, Object?>>> future;
  @override
  void initState() {
    super.initState();
    load();
    search.addListener(load);
  }
  void load() => setState(() => future = AppDatabase.instance.getPotentialUsers(search: search.text));
  @override
  void dispose() { search.removeListener(load); search.dispose(); super.dispose(); }
  Future<void> add() async {
    final ok = await showDialog<bool>(context: context, builder: (_) => const PotentialUserDialog());
    if (ok == true && mounted) load();
  }

  Future<void> edit(Map<String, Object?> row) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => PotentialUserDialog(existing: row));
    if (ok == true && mounted) load();
  }
  Future<void> convert(Map<String, Object?> row) async {
    try {
      await AppDatabase.instance.convertPotentialUser(row['id'] as int);
      if (!mounted) return;
      load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prospect converted to a registered user.')));
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().contains('already registered') ? 'This phone number is already registered.' : 'Could not convert this prospect.')));
    }
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 10), child: Row(children: [
      Expanded(child: TextField(controller: search, decoration: const InputDecoration(hintText: 'Search prospects', prefixIcon: Icon(Icons.search)))),
      const SizedBox(width: 10),
      FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('Add')),
    ])),
    Expanded(child: FutureBuilder<List<Map<String, Object?>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return const EmptyState(title: 'Could not load prospects', subtitle: 'Please close and reopen this page.');
        final rows = snap.data ?? [];
        if (rows.isEmpty) return EmptyState(title: search.text.isEmpty ? 'No potential users yet' : 'No matching prospects', subtitle: 'Keep prospect details separate until they choose to register.', action: add);
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 9),
          itemBuilder: (context, i) {
            final row = rows[i];
            return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(row['name'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') await edit(row);
                    if (v == 'convert') await convert(row);
                    if (v == 'interested') { await AppDatabase.instance.updatePotentialStatus(row['id'] as int, 'Interested'); load(); }
                    if (v == 'not_interested') { await AppDatabase.instance.updatePotentialStatus(row['id'] as int, 'Not Interested'); load(); }
                    if (v == 'do_not_contact') { await AppDatabase.instance.updatePotentialStatus(row['id'] as int, 'Do Not Contact'); load(); }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit prospect')),
                    PopupMenuItem(value: 'convert', child: Text('Convert to registered user')),
                    PopupMenuItem(value: 'interested', child: Text('Mark interested')),
                    PopupMenuItem(value: 'not_interested', child: Text('Not interested')),
                    PopupMenuItem(value: 'do_not_contact', child: Text('Do not contact')),
                  ],
                ),
              ]),
              Text(row['phone'] as String, style: const TextStyle(color: muted)),
              const SizedBox(height: 7),
              Wrap(spacing: 6, runSpacing: 6, children: [
                Chip(label: Text(row['status'] as String), visualDensity: VisualDensity.compact),
                if ((row['language'] as String).isNotEmpty) Chip(label: Text(row['language'] as String), visualDensity: VisualDensity.compact),
                if ((row['sports'] as String).isNotEmpty) Chip(label: Text(row['sports'] as String), visualDensity: VisualDensity.compact),
              ]),
              if ((row['notes'] as String).isNotEmpty) Text(row['notes'] as String, style: const TextStyle(color: muted)),
              if ((row['contact_permission'] as int) == 0) const Text('Contact permission not recorded', style: TextStyle(color: Color(0xFFFFC36B), fontSize: 11)),
            ])));
          },
        );
      },
    )),
  ]);
}

class PotentialUserDialog extends StatefulWidget {
  const PotentialUserDialog({super.key, this.existing});
  final Map<String, Object?>? existing;
  @override
  State<PotentialUserDialog> createState() => _PotentialUserDialogState();
}
class _PotentialUserDialogState extends State<PotentialUserDialog> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final phone = TextEditingController();
  final source = TextEditingController();
  final language = TextEditingController();
  final sports = TextEditingController();
  final notes = TextEditingController();
  String status = 'New Lead';
  DateTime? followUpDate;
  bool permission = false;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final row = widget.existing;
    if (row != null) {
      name.text = row['name'] as String? ?? '';
      phone.text = row['phone'] as String? ?? '';
      source.text = row['source'] as String? ?? '';
      language.text = row['language'] as String? ?? '';
      sports.text = row['sports'] as String? ?? '';
      notes.text = row['notes'] as String? ?? '';
      status = row['status'] as String? ?? 'New Lead';
      final date = row['follow_up_date'] as String?;
      followUpDate = date == null ? null : DateTime.tryParse(date);
      permission = (row['contact_permission'] as int? ?? 0) == 1;
    }
  }
  @override
  void dispose() { name.dispose(); phone.dispose(); source.dispose(); language.dispose(); sports.dispose(); notes.dispose(); super.dispose(); }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final existing = widget.existing;
      if (existing == null) {
        await AppDatabase.instance.addPotentialUser(
          name: name.text, phone: phone.text, source: source.text,
          language: language.text, sports: sports.text, notes: notes.text,
          status: status, followUpDate: followUpDate, contactPermission: permission,
        );
      } else {
        await AppDatabase.instance.updatePotentialUser(
          id: existing['id'] as int, name: name.text, phone: phone.text,
          source: source.text, language: language.text, sports: sports.text,
          notes: notes.text, status: status, followUpDate: followUpDate,
          contactPermission: permission,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on DuplicatePhoneException catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on DatabaseException catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.isUniqueConstraintError() ? 'This phone number is already in your prospects.' : 'Could not save this prospect.')));
    }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'Add potential user' : 'Edit potential user'),
    content: SizedBox(width: 420, child: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null),
      const SizedBox(height: 10),
      TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number'), validator: (v) => v == null || v.trim().length < 5 ? 'Enter a valid phone number' : null),
      const SizedBox(height: 10),
      TextField(controller: source, decoration: const InputDecoration(labelText: 'Contact source (optional)')),
      const SizedBox(height: 10),
      TextField(controller: language, decoration: const InputDecoration(labelText: 'Preferred language (optional)')),
      const SizedBox(height: 10),
      TextField(controller: sports, decoration: const InputDecoration(labelText: 'Sports interests (optional)')),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: status,
        decoration: const InputDecoration(labelText: 'Interest status'),
        items: const ['New Lead', 'Interested', 'Considering', 'Not Interested', 'Do Not Contact'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => status = v ?? 'New Lead'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: saving ? null : () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: followUpDate ?? DateTime.now(),
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime(2100),
          );
          if (picked != null) setState(() => followUpDate = picked);
        },
        icon: const Icon(Icons.event_available_outlined),
        label: Text(followUpDate == null ? 'Set follow-up date (optional)' : 'Follow-up: ${followUpDate!.toIso8601String().substring(0, 10)}'),
      ),
      const SizedBox(height: 10),
      TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero, value: permission,
        onChanged: (v) => setState(() => permission = v ?? false),
        title: const Text('Permission to contact recorded'),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    ])))),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.existing == null ? 'Save prospect' : 'Save changes')),
    ],
  );
}

class FollowUpsPage extends StatefulWidget {
  const FollowUpsPage({super.key});
  @override
  State<FollowUpsPage> createState() => _FollowUpsPageState();
}

class _FollowUpsPageState extends State<FollowUpsPage> {
  late Future<List<Object>> due;
  @override
  void initState() { super.initState(); load(); }
  void load() {
    due = Future.wait<Object>([
      AppDatabase.instance.getDueContactFollowUps(),
      AppDatabase.instance.getDuePotentialFollowUps(),
      AppDatabase.instance.getDueContactReminders(),
    ]);
  }
  Future<void> complete(bool prospect, int id) async {
    if (prospect) {
      await AppDatabase.instance.completePotentialFollowUp(id);
    } else {
      await AppDatabase.instance.completeContactFollowUp(id);
    }
    if (mounted) setState(load);
  }
  Future<void> completeReminder(int id) async {
    await AppDatabase.instance.completeContactReminder(id);
    await MatchNotificationService.cancelContactReminder(id);
    if (mounted) setState(load);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Follow-ups due')),
    body: FutureBuilder<List<Object>>(
      future: due,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return const EmptyState(title: 'Could not load follow-ups', subtitle: 'Please reopen this page and try again.');
        final contacts = snap.data?[0] as List<Map<String, Object?>>? ?? [];
        final prospects = snap.data?[1] as List<Map<String, Object?>>? ?? [];
        final reminders = snap.data?[2] as List<Map<String, Object?>>? ?? [];
        if (contacts.isEmpty && prospects.isEmpty && reminders.isEmpty) return const EmptyState(title: 'You are all caught up', subtitle: 'There are no overdue or due follow-ups.');
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            if (contacts.isNotEmpty) ...[
              const SectionHeading('Registered users', trailing: 'Contact follow-ups'),
              const SizedBox(height: 8),
              ...contacts.map((row) => _FollowUpTile(
                name: row['user_name'] as String? ?? 'Unknown user',
                phone: row['user_phone'] as String? ?? '',
                date: row['due_date'] as String? ?? '',
                detail: (row['reason'] as String? ?? '').isEmpty ? (row['notes'] as String? ?? '') : row['reason'] as String,
                onDone: () => complete(false, row['id'] as int),
              )),
            ],
            if (prospects.isNotEmpty) ...[
              const SizedBox(height: 18),
              const SectionHeading('Potential users', trailing: 'Prospect follow-ups'),
              const SizedBox(height: 8),
              ...prospects.map((row) => _FollowUpTile(
                name: row['name'] as String? ?? 'Unknown prospect',
                phone: row['phone'] as String? ?? '',
                date: row['follow_up_date'] as String? ?? '',
                detail: row['status'] as String? ?? '',
                onDone: () => complete(true, row['id'] as int),
              )),
            ],
            if (reminders.isNotEmpty) ...[
              const SizedBox(height: 18),
              const SectionHeading('Scheduled contact reminders', trailing: 'Repeating until done'),
              const SizedBox(height: 8),
              ...reminders.map((row) {
                final at = DateTime.tryParse(row['due_at'] as String? ?? '');
                return _FollowUpTile(
                  name: row['user_name'] as String? ?? 'User',
                  phone: row['user_phone'] as String? ?? '',
                  date: at?.toIso8601String().substring(0, 10) ?? '',
                  detail: row['reason'] as String? ?? 'Contact reminder',
                  onDone: () => completeReminder(row['id'] as int),
                );
              }),
            ],
          ],
        );
      },
    ),
  );
}

class _FollowUpTile extends StatelessWidget {
  const _FollowUpTile({required this.name, required this.phone, required this.date, required this.detail, required this.onDone});
  final String name, phone, date, detail;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) {
    final overdue = date.isNotEmpty && date.compareTo(DateTime.now().toIso8601String().substring(0, 10)) < 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$phone\n${overdue ? 'Overdue' : 'Due today'} · $date${detail.isEmpty ? '' : '\n$detail'}'),
        isThreeLine: true,
        trailing: IconButton(
          tooltip: 'Mark follow-up complete',
          onPressed: onDone,
          icon: const Icon(Icons.check_circle_outline_rounded, color: emerald),
        ),
      ),
    );
  }
}

class ContactHistoryPage extends StatefulWidget {
  const ContactHistoryPage({super.key});
  @override
  State<ContactHistoryPage> createState() => _ContactHistoryPageState();
}

class _ContactHistoryPageState extends State<ContactHistoryPage> {
  final search = TextEditingController();
  late Future<List<Map<String, Object?>>> history;
  late Future<List<Map<String, Object?>>> users;

  @override
  void initState() {
    super.initState();
    load();
    users = AppDatabase.instance.getUsers();
    search.addListener(load);
  }

  void load() => setState(() {
    history = AppDatabase.instance.getContactHistory(search: search.text);
  });

  @override
  void dispose() {
    search.removeListener(load);
    search.dispose();
    super.dispose();
  }

  Future<void> addLog(List<Map<String, Object?>> registeredUsers) async {
    if (registeredUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a registered user before recording contact history.')),
      );
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ContactLogDialog(users: registeredUsers),
    );
    if (saved == true) load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(
    future: users,
    builder: (context, userSnap) {
      final registeredUsers = userSnap.data ?? [];
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: TextField(
            controller: search,
            decoration: const InputDecoration(
              hintText: 'Search user, phone, reason or notes',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: userSnap.connectionState == ConnectionState.waiting ? null : () => addLog(registeredUsers),
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Record a contact'),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: history,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final rows = snap.data ?? [];
              if (rows.isEmpty) {
                return EmptyState(
                  title: search.text.isEmpty ? 'No contact history yet' : 'No matching records',
                  subtitle: 'Record calls, WhatsApp conversations, replies and follow-up dates here.',
                  action: registeredUsers.isEmpty ? null : () => addLog(registeredUsers),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final date = DateTime.tryParse(row['contact_date'] as String? ?? '');
                  final followUp = row['follow_up_date'] as String?;
                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF183B36),
                        child: Icon(
                          row['channel'] == 'Phone' ? Icons.call_outlined : row['channel'] == 'WhatsApp' ? Icons.chat_bubble_outline : Icons.forum_outlined,
                          color: emerald,
                        ),
                      ),
                      title: Text(row['user_name'] as String? ?? 'Unknown user', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${row['channel']} · ${row['outcome']} · ${date == null ? '' : date.toLocal().toString().substring(0, 16)}'),
                            if ((row['reason'] as String? ?? '').isNotEmpty) Text('Reason: ${row['reason']}'),
                            if ((row['response'] as String? ?? '').isNotEmpty) Text('Response: ${row['response']}'),
                            if ((row['notes'] as String? ?? '').isNotEmpty) Text(row['notes'] as String),
                            if (followUp != null) Text('Follow-up: $followUp', style: const TextStyle(color: emerald, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (userSnap.connectionState == ConnectionState.waiting)
          const LinearProgressIndicator(minHeight: 2),
      ]);
    },
  );
}

class ContactReminderDialog extends StatefulWidget {
  const ContactReminderDialog({super.key, required this.userId, required this.userName});
  final int userId;
  final String userName;
  @override
  State<ContactReminderDialog> createState() => _ContactReminderDialogState();
}

class _ContactReminderDialogState extends State<ContactReminderDialog> {
  final reason = TextEditingController();
  DateTime remindAt = DateTime.now().add(const Duration(hours: 1));
  bool saving = false;

  @override
  void dispose() { reason.dispose(); super.dispose(); }

  Future<void> chooseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: remindAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) {
      setState(() => remindAt = DateTime(picked.year, picked.month, picked.day, remindAt.hour, remindAt.minute));
    }
  }

  Future<void> chooseTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(remindAt));
    if (picked != null && mounted) {
      setState(() => remindAt = DateTime(remindAt.year, remindAt.month, remindAt.day, picked.hour, picked.minute));
    }
  }

  Future<void> save() async {
    if (!remindAt.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a future date and time.')));
      return;
    }
    setState(() => saving = true);
    try {
      final permissionGranted = await MatchNotificationService.requestPermission();
      final id = await AppDatabase.instance.addContactReminder(
        userId: widget.userId, remindAt: remindAt, reason: reason.text,
      );
      await MatchNotificationService.scheduleContactReminder(
        reminderId: id, userName: widget.userName, remindAt: remindAt, reason: reason.text,
      );
      if (!permissionGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reminder saved. Enable Android notifications to receive alerts.')));
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save reminder: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Remind me to contact ${widget.userName}'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.calendar_today_outlined, color: emerald),
        title: const Text('Reminder date'),
        subtitle: Text(DateFormat('EEEE, d MMMM yyyy').format(remindAt)),
        onTap: saving ? null : chooseDate,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.schedule_rounded, color: emerald),
        title: const Text('Reminder time'),
        subtitle: Text(TimeOfDay.fromDateTime(remindAt).format(context)),
        onTap: saving ? null : chooseTime,
      ),
      TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason or note (optional)')),
      const SizedBox(height: 10),
      const Text('You will receive a notification every day at this time until you mark the reminder completed.', style: TextStyle(color: muted, fontSize: 12)),
    ]))),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save reminder')),
    ],
  );
}

class ContactLogDialog extends StatefulWidget {
  const ContactLogDialog({super.key, required this.users, this.initialUserId});
  final List<Map<String, Object?>> users;
  final int? initialUserId;
  @override
  State<ContactLogDialog> createState() => _ContactLogDialogState();
}

class _ContactLogDialogState extends State<ContactLogDialog> {
  final form = GlobalKey<FormState>();
  final reason = TextEditingController();
  final response = TextEditingController();
  final notes = TextEditingController();
  int? userId;
  String channel = 'WhatsApp';
  String outcome = 'Replied';
  DateTime contactDate = DateTime.now();
  DateTime? followUpDate;
  bool saving = false;

  String _preferredChannelFor(int? selectedUserId) {
    for (final user in widget.users) {
      if (user['id'] == selectedUserId) {
        return normalizeContactChannel(user['preferred_contact_method'] as String?);
      }
    }
    return 'WhatsApp';
  }

  @override
  void initState() {
    super.initState();
    if (widget.users.isNotEmpty) {
      userId = widget.initialUserId ?? widget.users.first['id'] as int;
      channel = _preferredChannelFor(userId);
    }
  }

  @override
  void dispose() {
    reason.dispose();
    response.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate() || userId == null) return;
    setState(() => saving = true);
    try {
      await AppDatabase.instance.addContactLog(
        userId: userId!,
        contactDate: contactDate,
        channel: channel,
        reason: reason.text,
        outcome: outcome,
        response: response.text,
        notes: notes.text,
        followUpDate: followUpDate,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save contact: $e')));
      }
    }
  }

  Future<void> chooseFollowUp() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: followUpDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => followUpDate = picked);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record contact'),
    content: SizedBox(
      width: 440,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              initialValue: userId,
              decoration: const InputDecoration(labelText: 'Registered user'),
              items: widget.users.map((u) => DropdownMenuItem<int>(
                value: u['id'] as int,
                child: Text('${u['name']} · ${u['phone']}'),
              )).toList(),
              onChanged: (v) => setState(() {
                userId = v;
                channel = _preferredChannelFor(v);
              }),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: channel,
              decoration: const InputDecoration(labelText: 'Contact channel'),
              items: const ['WhatsApp', 'Phone call', 'SMS', 'IMO', 'Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => channel = v ?? 'WhatsApp'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: outcome,
              decoration: const InputDecoration(labelText: 'Outcome'),
              items: const ['Replied', 'No reply', 'Call completed', 'Could not reach', 'Issue reported'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) => setState(() => outcome = v ?? 'Replied'),
            ),
            const SizedBox(height: 10),
            TextFormField(controller: reason, decoration: const InputDecoration(labelText: 'Contact reason')),
            const SizedBox(height: 10),
            TextField(controller: response, maxLines: 2, decoration: const InputDecoration(labelText: 'Customer reply / feedback')),
            const SizedBox(height: 10),
            TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Private notes')),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Contact date: ${contactDate.toLocal().toString().substring(0, 10)}'),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: contactDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (picked != null) setState(() => contactDate = picked);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(followUpDate == null ? 'Add follow-up date (optional)' : 'Follow-up: ${followUpDate!.toLocal().toString().substring(0, 10)}'),
              trailing: Icon(followUpDate == null ? Icons.add_alarm : Icons.edit_calendar_outlined, color: emerald),
              onTap: chooseFollowUp,
            ),
            if (followUpDate != null)
              Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => followUpDate = null), child: const Text('Clear follow-up'))),
          ]),
        ),
      ),
    ),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save contact')),
    ],
  );
}

class MoreHubPage extends StatelessWidget {
  const MoreHubPage({super.key});

  void open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 36),
    children: [
      const Text('Workspace tools', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Manage prospects and customer support records.', style: TextStyle(color: muted)),
      const SizedBox(height: 18),
      _MoreTile(
        icon: Icons.person_search_outlined,
        title: 'Potential users',
        subtitle: 'Prospects, interest status and conversion',
        onTap: () => open(context, const PotentialUsersPage()),
      ),
      const SizedBox(height: 10),
      _MoreTile(
        icon: Icons.track_changes_rounded,
        title: 'Activity status',
        subtitle: 'Active, follow-up, inactive and never-DP users',
        onTap: () => open(context, const ActivityStatusPage()),
      ),
      const SizedBox(height: 10),
      _MoreTile(
        icon: Icons.support_agent_rounded,
        title: 'Customer issues',
        subtitle: 'Complaints, requests, priorities and resolutions',
        onTap: () => open(context, const CustomerIssuesPage()),
      ),
      const SizedBox(height: 10),
      _MoreTile(
        icon: Icons.archive_outlined,
        title: 'Archived users',
        subtitle: 'View and restore archived profiles',
        onTap: () => open(context, const ArchivedUsersPage()),
      ),
      const SizedBox(height: 10),
      _MoreTile(
        icon: Icons.history_rounded,
        title: 'Audit history',
        subtitle: 'Review recorded DP and bonus deletions',
        onTap: () => open(context, const AuditHistoryPage()),
      ),
      const SizedBox(height: 10),
      _MoreTile(
        icon: Icons.backup_outlined,
        title: 'Backup & restore',
        subtitle: 'Save a complete local backup or restore one',
        onTap: () => open(context, const BackupRestorePage()),
      ),
      const SizedBox(height: 10),
      _MoreTile(
        icon: Icons.sports_soccer_rounded,
        title: 'Sports & matches',
        subtitle: 'Save favourite teams and discover upcoming fixtures online',
        onTap: () => open(context, const SportsMatchesPage()),
      ),
      const SizedBox(height: 10),
      _MoreTile(
        icon: Icons.notifications_active_outlined,
        title: 'Notifications & reminders',
        subtitle: 'Local match alerts for opted-in users',
        onTap: () => open(context, const MatchNotificationSettingsPage()),
      ),
      const SizedBox(height: 10),
      _MoreTile(
        icon: Icons.summarize_outlined,
        title: 'Reports & export',
        subtitle: 'Review period totals and export transaction history',
        onTap: () => open(context, const ReportsPage()),
      ),
      const SizedBox(height: 10),
      _MoreTile(
        icon: Icons.stars_rounded,
        title: 'User level requirements',
        subtitle: 'Edit lifetime and monthly DP thresholds and level labels',
        onTap: () => open(context, const UserLevelSettingsPage()),
      ),
      const SizedBox(height: 10),
      _MoreTile(
        icon: Icons.settings_outlined,
        title: 'Settings',
        subtitle: 'App preferences, data checks and workspace information',
        onTap: () => open(context, const SettingsPage()),
      ),
    ],
  );
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: CircleAvatar(backgroundColor: const Color(0xFF183B36), child: Icon(icon, color: emerald)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    ),
  );
}

class UserLevelSettingsPage extends StatefulWidget {
  const UserLevelSettingsPage({super.key});

  @override
  State<UserLevelSettingsPage> createState() => _UserLevelSettingsPageState();
}

class _UserLevelSettingsPageState extends State<UserLevelSettingsPage> {
  static const keys = ['neighborly', 'low', 'medium', 'high'];
  late final List<TextEditingController> labels;
  late final List<TextEditingController> lifetime;
  late final List<TextEditingController> monthly;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    labels = List.generate(4, (_) => TextEditingController());
    lifetime = List.generate(4, (_) => TextEditingController());
    monthly = List.generate(4, (_) => TextEditingController());
    load();
  }

  Future<void> load() async {
    final config = await AppDatabase.instance.getUserLevelConfig();
    if (!mounted) return;
    for (var i = 0; i < 4; i++) {
      labels[i].text = config.tiers[i].label;
      lifetime[i].text = config.tiers[i].lifetimeMinimum.toStringAsFixed(0);
      monthly[i].text = config.tiers[i].monthlyMinimum.toStringAsFixed(0);
    }
    setState(() => loading = false);
  }

  @override
  void dispose() {
    for (final controller in [...labels, ...lifetime, ...monthly]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? validateNumber(String? value, int index, List<TextEditingController> controllers) {
    final number = double.tryParse((value ?? '').trim());
    if (number == null || !number.isFinite || number < 0) return 'Enter a valid non-negative amount';
    if (index > 0) {
      final previous = double.tryParse(controllers[index - 1].text.trim());
      if (previous != null && number <= previous) return 'Must be greater than the level below';
    }
    return null;
  }

  Future<void> save() async {
    final parsedLifetime = lifetime.map((c) => double.tryParse(c.text.trim())).toList();
    final parsedMonthly = monthly.map((c) => double.tryParse(c.text.trim())).toList();
    if (labels.any((c) => c.text.trim().isEmpty) ||
        labels.map((c) => c.text.trim().toLowerCase()).toSet().length != 4 ||
        parsedLifetime.any((v) => v == null || !v.isFinite) ||
        parsedMonthly.any((v) => v == null || !v.isFinite)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check that all labels are unique and all DP requirements are valid.')));
      return;
    }
    final tiers = List.generate(4, (i) => UserLevelTier(
      key: keys[i],
      label: labels[i].text.trim(),
      lifetimeMinimum: parsedLifetime[i]!,
      monthlyMinimum: parsedMonthly[i]!,
    ));
    final config = UserLevelConfig(tiers: tiers);
    try {
      config.validate();
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Invalid argument(s): ', ''))));
      return;
    }
    setState(() => saving = true);
    try {
      await AppDatabase.instance.saveUserLevelConfig(config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User level requirements saved. User levels have been recalculated.')));
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save settings: $error')));
      }
    }
  }

  Widget thresholdField(String label, TextEditingController controller, int index, List<TextEditingController> controllers) =>
      Expanded(child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: 'DP '),
        validator: (value) => validateNumber(value, index, controllers),
      ));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('User level requirements')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 32), children: [
            const Text('Customize your four user levels', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Change each label and the minimum DP needed to reach it. Lifetime and monthly requirements are independent.', style: TextStyle(color: muted, height: 1.4)),
            const SizedBox(height: 16),
            for (var i = 3; i >= 0; i--) ...[
              Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('LEVEL ${i + 1}', style: const TextStyle(color: emerald, fontWeight: FontWeight.w800, fontSize: 11)),
                const SizedBox(height: 10),
                TextField(controller: labels[i], decoration: const InputDecoration(labelText: 'Level label')),
                const SizedBox(height: 10),
                if (i == 0)
                  const Text('This is the starting level. Its minimum is always 0 DP.', style: TextStyle(color: muted, fontSize: 12))
                else ...[
                  Row(children: [
                    thresholdField('Lifetime minimum', lifetime[i], i, lifetime),
                    const SizedBox(width: 10),
                    thresholdField('Monthly minimum', monthly[i], i, monthly),
                  ]),
                  const SizedBox(height: 8),
                  Text('Applies from this amount up to the next level.', style: const TextStyle(color: muted, fontSize: 11)),
                ],
              ]))),
              const SizedBox(height: 10),
            ],
            const Text('The app updates the level shown on user profiles and the Users page. Your DP records are not changed.', style: TextStyle(color: muted, height: 1.4)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: saving ? null : save,
              icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
              label: Text(saving ? 'Saving…' : 'Save requirements'),
            ),
          ]),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool checking = false;
  String? integrityResult;

  Future<void> checkDatabase() async {
    setState(() { checking = true; integrityResult = null; });
    try {
      final valid = await AppDatabase.instance.checkIntegrity();
      if (mounted) {
        setState(() => integrityResult = valid
            ? 'Database integrity check passed.'
            : 'Database integrity check reported a problem.');
      }
    } catch (e) {
      if (mounted) setState(() => integrityResult = 'Check failed: $e');
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  void open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text('Workspace preferences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Manage local reminders and protect your records.', style: TextStyle(color: muted)),
        const SizedBox(height: 16),
        Card(child: Column(children: [
          ListTile(
            leading: const Icon(Icons.stars_rounded, color: emerald),
            title: const Text('User level requirements'),
            subtitle: const Text('Customize level labels and lifetime/monthly DP thresholds'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => open(context, const UserLevelSettingsPage()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.notifications_active_outlined, color: emerald),
            title: const Text('Notifications & quiet hours'),
            subtitle: const Text('Match alerts, reminder schedule and quiet-time settings'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => open(context, const MatchNotificationSettingsPage()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.backup_outlined, color: emerald),
            title: const Text('Backup & restore'),
            subtitle: const Text('Create a backup, restore a database or review local backups'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => open(context, const BackupRestorePage()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.summarize_outlined, color: emerald),
            title: const Text('Reports & export'),
            subtitle: const Text('Monthly DP and bonus totals with transaction export'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => open(context, const ReportsPage()),
          ),
        ])),
        const SizedBox(height: 14),
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Database health', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('Run SQLite’s integrity check on the local workspace database.', style: TextStyle(color: muted, height: 1.4)),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: checking ? null : checkDatabase,
              icon: checking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.fact_check_outlined),
              label: Text(checking ? 'Checking…' : 'Check database integrity'),
            )),
            if (integrityResult != null) ...[
              const SizedBox(height: 8),
              Text(integrityResult!, style: TextStyle(
                color: integrityResult!.contains('passed') ? emerald : amber,
                fontWeight: FontWeight.w600,
              )),
            ],
          ]),
        )),
        const SizedBox(height: 14),
        const Card(child: ListTile(
          leading: Icon(Icons.phone_android_rounded, color: emerald),
          title: Text('User Hub · Local workspace'),
          subtitle: Text('Offline-first storage. Your records remain in this app’s local SQLite database. No user messages are sent automatically.'),
        )),
      ],
    ),
  );
}

class MatchNotificationSettingsPage extends StatefulWidget {
  const MatchNotificationSettingsPage({super.key});
  @override
  State<MatchNotificationSettingsPage> createState() => _MatchNotificationSettingsPageState();
}

class _MatchNotificationSettingsPageState extends State<MatchNotificationSettingsPage> {
  bool enabled = false;
  bool dpTimeEnabled = false;
  bool loading = true;
  bool busy = false;
  bool quietHoursEnabled = false;
  TimeOfDay quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      enabled = prefs.getBool('match_reminders_enabled') ?? false;
      dpTimeEnabled = prefs.getBool('dp_time_reminders_enabled') ?? false;
      quietHoursEnabled = prefs.getBool('quiet_hours_enabled') ?? false;
      final start = prefs.getInt('quiet_hours_start_minute') ?? 1320;
      final end = prefs.getInt('quiet_hours_end_minute') ?? 420;
      quietStart = TimeOfDay(hour: start ~/ 60, minute: start % 60);
      quietEnd = TimeOfDay(hour: end ~/ 60, minute: end % 60);
      loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value) {
        final granted = await MatchNotificationService.requestPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notification permission was not granted. Enable it in Android settings to receive match reminders.')),
            );
          }
          return;
        }
        await prefs.setBool('match_reminders_enabled', true);
        await MatchNotificationService.rescheduleAllUpcoming();
      } else {
        await prefs.setBool('match_reminders_enabled', false);
        await MatchNotificationService.rescheduleAllUpcoming();
      }
      if (mounted) setState(() => enabled = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update notification settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _toggleDpTime(bool value) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value) {
        final granted = await MatchNotificationService.requestPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notification permission was not granted. Enable it in Android settings to receive reminders.')),
            );
          }
          return;
        }
      }
      await prefs.setBool('dp_time_reminders_enabled', value);
      await MatchNotificationService.rescheduleAllUpcoming();
      if (mounted) setState(() => dpTimeEnabled = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update usual DP-time reminders: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  int _minuteOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

  String _timeLabel(TimeOfDay time) => time.format(context);

  Future<void> _toggleQuietHours(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quiet_hours_enabled', value);
    if (!mounted) return;
    setState(() => quietHoursEnabled = value);
    if (enabled || dpTimeEnabled) await MatchNotificationService.rescheduleAllUpcoming();
  }

  Future<void> _chooseQuietTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? quietStart : quietEnd,
      helpText: isStart ? 'Quiet hours start' : 'Quiet hours end',
    );
    if (picked == null || !mounted) return;
    final nextStart = isStart ? picked : quietStart;
    final nextEnd = isStart ? quietEnd : picked;
    if (_minuteOfDay(nextStart) == _minuteOfDay(nextEnd)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiet hours start and end must be different.')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('quiet_hours_start_minute', _minuteOfDay(nextStart));
    await prefs.setInt('quiet_hours_end_minute', _minuteOfDay(nextEnd));
    if (!mounted) return;
    setState(() { quietStart = nextStart; quietEnd = nextEnd; });
    if (enabled || dpTimeEnabled) await MatchNotificationService.rescheduleAllUpcoming();
  }

  Future<void> _test() async {
    try {
      await MatchNotificationService.showTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test notification sent to this device.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send test notification: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notifications & reminders')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              CircleAvatar(backgroundColor: Color(0xFF183B36), child: Icon(Icons.notifications_active_outlined, color: emerald)),
              SizedBox(width: 12),
              Expanded(child: Text('Local match reminders', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 12),
            const Text(
              'Get a reminder 30 minutes before a saved match when it matches a registered user’s saved sports interests and that user has opted in to match alerts. If the match is less than 30 minutes away, the reminder is scheduled for match time.',
              style: TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable match reminders'),
              subtitle: Text(enabled ? 'Reminders are enabled on this device' : 'Reminders are currently off'),
              value: enabled,
              onChanged: loading || busy ? null : _toggle,
            ),
            if (busy || loading) const LinearProgressIndicator(),
          ]),
        )),
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Usual DP-time reminders', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('A daily operator-only alert at the average DP-entry time from the last 30 days. It requires at least three recorded DP entries and excludes archived and Do Not Contact users.', style: TextStyle(color: muted, height: 1.4)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable usual DP-time reminders'),
              subtitle: Text(dpTimeEnabled ? 'Daily reminders are enabled' : 'Daily reminders are off'),
              value: dpTimeEnabled,
              onChanged: loading || busy ? null : _toggleDpTime,
            ),
          ]),
        )),
        const SizedBox(height: 12),
        Card(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Quiet hours', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Avoid match reminder notifications during your chosen rest period. If quiet hours end after a match starts, that reminder is skipped.', style: TextStyle(color: muted, height: 1.4)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable quiet hours'),
              subtitle: Text(quietHoursEnabled ? 'Reminders are paused during this time' : 'Quiet hours are off'),
              value: quietHoursEnabled,
              onChanged: loading ? null : _toggleQuietHours,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start'),
              subtitle: Text(_timeLabel(quietStart)),
              trailing: const Icon(Icons.access_time_rounded, color: emerald),
              enabled: !loading,
              onTap: loading ? null : () => _chooseQuietTime(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End'),
              subtitle: Text(_timeLabel(quietEnd)),
              trailing: const Icon(Icons.access_time_rounded, color: emerald),
              enabled: !loading,
              onTap: loading ? null : () => _chooseQuietTime(isStart: false),
            ),
          ]),
        )),
        const SizedBox(height: 12),
        Card(child: Column(children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: emerald),
            title: const Text('Operator-only notifications'),
            subtitle: const Text('These alerts appear on this device. The app does not send messages to users. Only users with Match alerts opted in are considered.'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.notifications_outlined, color: emerald),
            title: const Text('Send test notification'),
            subtitle: const Text('Check whether Android notifications are working.'),
            enabled: !busy && (enabled || dpTimeEnabled),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: busy || (!enabled && !dpTimeEnabled) ? null : _test,
          ),
        ])),
        const SizedBox(height: 10),
        const Text(
          'Fixture discovery searches Google News for saved teams and competitions. Search results are suggestions, not a complete or verified worldwide fixture feed. Review match date and local time before saving. Android notification permission and battery settings can affect delivery.',
          style: TextStyle(color: muted, fontSize: 12, height: 1.5),
        ),
      ],
    ),
  );
}

class ActivityStatusPage extends StatefulWidget {
  const ActivityStatusPage({super.key});
  @override
  State<ActivityStatusPage> createState() => _ActivityStatusPageState();
}

class _ActivityStatusPageState extends State<ActivityStatusPage> {
  static const statuses = ['All', 'Active', 'Follow-up', 'Inactive', 'Long inactive', 'Very long inactive', 'Never DP'];
  String selected = 'All';
  late Future<List<Map<String, Object?>>> future;

  @override
  void initState() {
    super.initState();
    future = AppDatabase.instance.getActivityStatusUsers();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activity status')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load activity status.'));
        }
        final all = snapshot.data ?? [];
        final rows = selected == 'All'
            ? all
            : all.where((row) => row['activity_status'] == selected).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Wrap(spacing: 8, runSpacing: 8, children: statuses.map((status) {
              final count = status == 'All'
                  ? all.length
                  : all.where((row) => row['activity_status'] == status).length;
              return ChoiceChip(
                label: Text('$status ($count)'),
                selected: selected == status,
                onSelected: (_) => setState(() => selected = status),
              );
            }).toList()),
          ),
          Expanded(
            child: rows.isEmpty
                ? const EmptyState(
                    title: 'No users in this group',
                    subtitle: 'Users will appear here when their DP activity matches this status.',
                    icon: Icons.people_outline_rounded,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      final status = row['activity_status'] as String;
                      final days = row['days_since_last_dp'] as int?;
                      final detail = days == null
                          ? 'No DP recorded'
                          : days == 0 ? 'Last DP today' : 'Last DP $days day(s) ago';
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF183B36),
                            child: Icon(
                              status == 'Active' ? Icons.bolt_rounded : Icons.schedule_rounded,
                              color: status == 'Active' ? emerald : amber,
                            ),
                          ),
                          title: Text(row['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('$detail · $status', style: const TextStyle(color: muted)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => UserProfilePage(
                              userId: row['id'] as int,
                              onChanged: () => setState(() {
                                future = AppDatabase.instance.getActivityStatusUsers();
                              }),
                            ),
                          )),
                        ),
                      );
                    },
                  ),
          ),
        ]);
      },
    ),
  );
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<List<Object>> report;
  bool exporting = false;

  DateTime get nextMonth => DateTime(month.year, month.month + 1);
  @override
  void initState() { super.initState(); load(); }
  void load() {
    report = Future.wait<Object>([
      AppDatabase.instance.getReportTotals(month, nextMonth),
      AppDatabase.instance.getReportRows(month, nextMonth),
    ]);
  }

  Future<void> chooseMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Choose a date in the report month',
    );
    if (picked != null && mounted) setState(() { month = DateTime(picked.year, picked.month); load(); });
  }

  String csvCell(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  Future<void> exportCsv(List<Map<String, Object?>> rows) async {
    setState(() => exporting = true);
    try {
      const headers = ['Type', 'Date', 'User', 'Phone', 'Amount (coins)', 'DP count', 'Reason', 'Notes'];
      final lines = <String>[headers.map(csvCell).join(',')];
      for (final row in rows) {
        lines.add([
          row['type'], row['transaction_date'], row['user_name'], row['phone'],
          row['amount'], row['item_count'], row['reason'], row['notes'],
        ].map(csvCell).join(','));
      }
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/user-hub-report-${month.year}-${month.month.toString().padLeft(2, '0')}.csv');
      await file.writeAsString(lines.join('\n'), flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'User Hub monthly report'));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not export this report.')));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> exportPdf(
    List<Map<String, Object?>> rows,
    Map<String, num> totals,
  ) async {
    setState(() => exporting = true);
    try {
      final pdf = pw.Document();
      final monthLabel = DateFormat('MMMM yyyy').format(month);
      final headers = [
        'Type', 'Date', 'User', 'Phone', 'Amount', 'DP count', 'Reason', 'Notes',
      ];
      final tableRows = <List<String>>[
        headers,
        ...rows.map((row) => [
          row['type']?.toString() ?? '',
          row['transaction_date']?.toString() ?? '',
          row['user_name']?.toString() ?? '',
          row['phone']?.toString() ?? '',
          row['amount']?.toString() ?? '0',
          row['item_count']?.toString() ?? '',
          row['reason']?.toString() ?? '',
          row['notes']?.toString() ?? '',
        ]),
      ];
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('User Hub · Monthly Report',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text('Period: $monthLabel'),
          pw.SizedBox(height: 8),
          pw.Wrap(spacing: 24, runSpacing: 6, children: [
            pw.Text('DP total: ${totals['dp'] ?? 0} coins'),
            pw.Text('Bonus total: ${totals['bonus'] ?? 0} coins'),
            pw.Text('DP records: ${totals['dp_count'] ?? 0}'),
            pw.Text('Bonus records: ${totals['bonus_count'] ?? 0}'),
            pw.Text('Transactions: ${rows.length}'),
          ]),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: tableRows.skip(1).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 7),
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(4),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.8),
              1: const pw.FlexColumnWidth(1.0),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(1.2),
              4: const pw.FlexColumnWidth(0.8),
              5: const pw.FlexColumnWidth(0.6),
              6: const pw.FlexColumnWidth(1.0),
              7: const pw.FlexColumnWidth(1.5),
            },
          ),
        ],
      ));
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/user-hub-report-${month.year}-${month.month.toString().padLeft(2, '0')}.pdf',
      );
      await file.writeAsBytes(await pdf.save(), flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'User Hub monthly report · $monthLabel',
      ));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not create the PDF report.')),
        );
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reports & export')),
    body: FutureBuilder<List<Object>>(
      future: report,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return const EmptyState(title: 'Report unavailable', subtitle: 'Please try again.');
        final totals = snap.data![0] as Map<String, num>;
        final rows = snap.data![1] as List<Map<String, Object?>>;
        final dp = totals['dp'] ?? 0;
        final bonus = totals['bonus'] ?? 0;
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            OutlinedButton.icon(onPressed: chooseMonth, icon: const Icon(Icons.calendar_month), label: Text('${month.year}-${month.month.toString().padLeft(2, '0')}')),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: MetricCard(label: 'DP total', value: dp.toString(), icon: Icons.account_balance_wallet_outlined)),
              const SizedBox(width: 10),
              Expanded(child: MetricCard(label: 'Bonus total', value: bonus.toString(), icon: Icons.card_giftcard_outlined)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: MetricCard(label: 'DP records', value: '${totals['dp_count']}', icon: Icons.receipt_long_outlined)),
              const SizedBox(width: 10),
              Expanded(child: MetricCard(label: 'Bonus records', value: '${totals['bonus_count']}', icon: Icons.redeem_outlined)),
            ]),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: exporting ? null : () => exportCsv(rows),
              icon: const Icon(Icons.file_download_outlined),
              label: Text(exporting ? 'Preparing export…' : 'Export transaction CSV'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: exporting ? null : () => exportPdf(rows, totals),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text(exporting ? 'Preparing export…' : 'Export monthly PDF report'),
            ),
            const SizedBox(height: 18),
            const SectionHeading('Transactions', trailing: 'Selected month'),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const EmptyState(title: 'No transactions this month', subtitle: 'DP and bonus records will appear here.')
            else
              ...rows.take(100).map((row) => Card(
                margin: const EdgeInsets.only(bottom: 7),
                child: ListTile(
                  title: Text('${row['user_name']} · ${row['type']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${row['transaction_date']} · ${row['reason'] ?? ''}'),
                  trailing: Text('${row['amount']}', style: const TextStyle(color: emerald, fontWeight: FontWeight.w800)),
                ),
              )),
            if (rows.length > 100) Text('Showing 100 of ${rows.length} transactions. The CSV includes all records.', style: const TextStyle(color: muted)),
          ],
        );
      },
    ),
  );
}

class FixtureDiscoveryPage extends StatefulWidget {
  const FixtureDiscoveryPage({super.key});
  @override
  State<FixtureDiscoveryPage> createState() => _FixtureDiscoveryPageState();
}

class _FixtureDiscoveryPageState extends State<FixtureDiscoveryPage> {
  final query = TextEditingController();
  bool loading = false;
  String? error;
  List<FixtureSearchResult> results = [];
  List<Map<String, Object?>> interests = [];
  @override
  void initState() { super.initState(); _loadInterests(); }
  @override
  void dispose() { query.dispose(); super.dispose(); }

  Future<void> _loadInterests() async {
    try {
      final rows = await AppDatabase.instance.getSportsInterests();
      if (!mounted) return;
      setState(() => interests = rows);
      // Automatically discover upcoming fixtures from public schedule pages.
      await _searchUpcoming();
    } catch (e) {
      if (mounted) setState(() => error = 'Could not load saved sports interests: $e');
    }
  }

  Future<void> _searchCustom() async {
    if (query.text.trim().isEmpty) return;
    await _run(() => FixtureDiscoveryService.search(query.text.trim()));
  }

  Future<void> _searchUpcoming() async {
    await _run(() async {
      final combined = <FixtureSearchResult>[];
      final seen = <String>{};
      try {
        for (final result in await FixtureDiscoveryService.searchUpcomingFixtures(days: 60)) {
          final key = '${result.title.toLowerCase()}|${result.matchStartAt?.toIso8601String() ?? result.url}';
          if (seen.add(key)) combined.add(result);
        }
      } catch (_) {}
      try {
        for (final result in await FixtureDiscoveryService.searchSavedInterests(interests)) {
          final key = result.url.isEmpty ? result.title : result.url;
          if (seen.add(key)) combined.add(result);
        }
      } catch (_) {}
      return combined;
    });
  }

  Future<void> _run(Future<List<FixtureSearchResult>> Function() action) async {
    setState(() { loading = true; error = null; results = []; });
    try {
      final found = await action();
      if (mounted) setState(() => results = found);
      if (found.isEmpty && mounted) {
        setState(() => error = 'No results were found. Try a team name, league or a broader search.');
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Fixture search failed: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _review(FixtureSearchResult result) async {
    final pair = FixtureDiscoveryService.parseTeams(result.title);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => MatchDialog(
        initialHomeTeam: pair?['home'] ?? '',
        initialAwayTeam: pair?['away'] ?? '',
        sourceUrl: result.url,
        notes: 'Found by online fixture search. Verify the official fixture date and local start time before saving.\n${result.title}',
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fixture saved to your match calendar.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Find fixtures online')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.travel_explore_rounded, color: emerald),
              SizedBox(width: 9),
              Expanded(child: Text('Search match fixtures', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 8),
            const Text('Checks public schedules from multi-sport and specialist sources, plus saved-team searches and TheSportsDB artwork. Shows structured fixtures up to 60 days ahead when a source exposes reliable event data. Match times are converted to Bangladesh time (UTC+6). Coverage depends on public data exposed by each source.', style: TextStyle(color: muted, height: 1.45)),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: loading ? null : _searchUpcoming,
              icon: const Icon(Icons.travel_explore_rounded),
              label: const Text('Find upcoming matches · 60 days'),
            )),
            if (interests.isEmpty) const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Add favourite teams or competitions in User interests first.', style: TextStyle(color: amber, fontSize: 12)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchCustom(),
              decoration: InputDecoration(
                hintText: 'Search any team, league or match',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(onPressed: query.clear, icon: const Icon(Icons.close)),
              ),
            ),
            const SizedBox(height: 9),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: loading ? null : _searchCustom,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Search the web'),
            )),
            if (loading) const Padding(
              padding: EdgeInsets.only(top: 14),
              child: LinearProgressIndicator(),
            ),
          ]),
        )),
        if (error != null) Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(error!, style: const TextStyle(color: amber)),
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionHeading('Search results', trailing: '${results.length} found'),
          const SizedBox(height: 10),
          for (final result in results) ...[
            Card(child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (result.imageUrl.isNotEmpty)
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(
                    result.imageUrl, height: 150, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  )),
                if (result.imageUrl.isNotEmpty) const SizedBox(height: 10),
                Text(result.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 7),
                Text('${result.source} · ${result.matchStartAt == null ? (result.publishedAt.isEmpty ? 'Schedule time not confirmed — open source to verify' : 'Article: ${result.publishedAt}') : DateFormat('EEE, d MMM · hh:mm a').format(result.matchStartAt!.toUtc().add(const Duration(hours: 6)))}${result.matchStartAt == null ? '' : ' Bangladesh time'}', style: const TextStyle(color: muted, fontSize: 11)),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: FilledButton.tonalIcon(
                  onPressed: () => _review(result),
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: const Text('Review & add fixture'),
                )),
              ]),
            )),
            const SizedBox(height: 8),
          ],
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text("Structured event times are preferred; article publication dates are never treated as match times. TheSportsDB free API has request and data limits, and some sites block scraping or do not expose machine-readable fixtures. Images use event artwork when available, then team artwork; verify important fixtures before saving.", style: TextStyle(color: muted, fontSize: 12, height: 1.45)),
          ),
        ],
      ],
    ),
  );
}

class SportsMatchesPage extends StatefulWidget {
  const SportsMatchesPage({super.key});
  @override
  State<SportsMatchesPage> createState() => _SportsMatchesPageState();
}

class _SportsMatchesPageState extends State<SportsMatchesPage> {
  String section = 'matches';
  final search = TextEditingController();
  late Future<List<Map<String, Object?>>> matches;
  late Future<List<Map<String, Object?>>> interests;
  @override
  void initState() { super.initState(); load(); search.addListener(_reload); }
  void _reload() { if (mounted) setState(load); }
  void load() {
    matches = AppDatabase.instance.getMatches(search: search.text);
    interests = AppDatabase.instance.getSportsInterests();
  }
  @override
  void dispose() { search.removeListener(_reload); search.dispose(); super.dispose(); }
  Future<void> addMatch() async {
    final saved = await showDialog<bool>(context: context, builder: (_) => const MatchDialog());
    if (saved == true && mounted) setState(load);
  }
  Future<void> addInterest() async {
    final users = await AppDatabase.instance.getUsers();
    if (!mounted) return;
    if (users.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a registered user first.')));
      return;
    }
    final saved = await showDialog<bool>(context: context, builder: (_) => SportsInterestDialog(users: users));
    if (saved == true && mounted) setState(load);
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sports & matches'),
      actions: [
        IconButton(
          tooltip: 'Find fixtures online',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FixtureDiscoveryPage())),
          icon: const Icon(Icons.travel_explore_rounded, color: emerald),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: section == 'matches' ? addMatch : addInterest,
      icon: const Icon(Icons.add),
      label: Text(section == 'matches' ? 'Add match' : 'Add interest'),
    ),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 10), child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'matches', label: Text('Match calendar'), icon: Icon(Icons.calendar_month_outlined)),
          ButtonSegment(value: 'interests', label: Text('User interests'), icon: Icon(Icons.favorite_border_rounded)),
        ],
        selected: {section},
        onSelectionChanged: (v) => setState(() => section = v.first),
      )),
      if (section == 'matches')
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FixtureDiscoveryPage()),
              ),
              icon: const Icon(Icons.travel_explore_rounded),
              label: const Text('Find fixtures for saved teams & leagues'),
            ),
          ),
        ),
      if (section == 'matches')
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: TextField(
          controller: search,
          decoration: const InputDecoration(hintText: 'Search teams, sport or competition', prefixIcon: Icon(Icons.search)),
        )),
      Expanded(child: section == 'matches'
        ? FutureBuilder<List<Map<String, Object?>>>(future: matches, builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return const EmptyState(title: 'Could not load matches', subtitle: 'Please try again.');
            final rows = snap.data ?? [];
            if (rows.isEmpty) return const EmptyState(title: 'No matches saved', subtitle: 'Use the fixture finder above to search saved favourites, or add a match manually.');
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final row = rows[i];
                final date = DateTime.tryParse(row['start_at'] as String? ?? '')?.toLocal();
                return Card(child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Color(0xFF183B36), child: Icon(Icons.sports, color: emerald)),
                  title: Text('${row['home_team']} vs ${row['away_team']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${row['sport']} · ${row['competition']}\n${date?.toString().substring(0, 16) ?? ''} · ${row['status']}'),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'delete') {
                        await AppDatabase.instance.deleteMatch(row['id'] as int);
                      } else {
                        await AppDatabase.instance.updateMatchStatus(row['id'] as int, v);
                      }
                      await MatchNotificationService.rescheduleAllUpcoming();
                      if (mounted) setState(load);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'Upcoming', child: Text('Mark upcoming')),
                      PopupMenuItem(value: 'Live', child: Text('Mark live')),
                      PopupMenuItem(value: 'Finished', child: Text('Mark finished')),
                      PopupMenuItem(value: 'Cancelled', child: Text('Mark cancelled')),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ));
              },
            );
          })
        : FutureBuilder<List<Map<String, Object?>>>(future: interests, builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return const EmptyState(title: 'Could not load interests', subtitle: 'Please try again.');
            final rows = snap.data ?? [];
            if (rows.isEmpty) return const EmptyState(title: 'No sports interests saved', subtitle: 'Add a user’s favourite sports, teams and competitions.');
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final row = rows[i];
                return Card(child: ListTile(
                  title: Text(row['user_name'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Sports: ${row['sports']}\nTeams: ${row['teams']}\nCompetitions: ${row['competitions']}'),
                  isThreeLine: true,
                  trailing: IconButton(tooltip: 'Edit interests', icon: const Icon(Icons.edit_outlined, color: emerald), onPressed: () async {
                    final users = await AppDatabase.instance.getUsers();
                    if (!context.mounted) return;
                    final saved = await showDialog<bool>(context: context, builder: (_) => SportsInterestDialog(users: users, existing: row));
                    if (saved == true && mounted) setState(load);
                  }),
                ));
              },
            );
          })),
    ]),
  );
}

class MatchDialog extends StatefulWidget {
  const MatchDialog({super.key, this.initialHomeTeam = '', this.initialAwayTeam = '', this.sourceUrl = '', this.notes = ''});
  final String initialHomeTeam, initialAwayTeam, sourceUrl, notes;
  @override
  State<MatchDialog> createState() => _MatchDialogState();
}
class _MatchDialogState extends State<MatchDialog> {
  final form = GlobalKey<FormState>();
  final competition = TextEditingController();
  final home = TextEditingController();
  final away = TextEditingController();
  final source = TextEditingController();
  final notes = TextEditingController();
  String sport = 'Cricket';
  String status = 'Upcoming';
  DateTime date = DateTime.now();
  TimeOfDay time = TimeOfDay.now();
  bool saving = false;
  @override
  void initState() {
    super.initState();
    home.text = widget.initialHomeTeam;
    away.text = widget.initialAwayTeam;
    source.text = widget.sourceUrl;
    notes.text = widget.notes;
  }
  @override
  void dispose() { competition.dispose(); home.dispose(); away.dispose(); source.dispose(); notes.dispose(); super.dispose(); }
  Future<void> chooseDate() async {
    final value = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (value != null) setState(() => date = value);
  }
  Future<void> chooseTime() async {
    final value = await showTimePicker(context: context, initialTime: time);
    if (value != null) setState(() => time = value);
  }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await AppDatabase.instance.addMatch(
        sport: sport, competition: competition.text, homeTeam: home.text,
        awayTeam: away.text,
        startAt: DateTime(date.year, date.month, date.day, time.hour, time.minute),
        status: status, sourceUrl: source.text, notes: notes.text,
      );
      await MatchNotificationService.rescheduleAllUpcoming();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => saving = false);
    }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add match'),
    content: SizedBox(width: 420, child: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        initialValue: sport,
        decoration: const InputDecoration(labelText: 'Sport'),
        items: const ['Cricket', 'Football', 'Kabaddi', 'Tennis', 'Badminton', 'Esports'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => sport = v ?? 'Cricket'),
      ),
      const SizedBox(height: 10),
      TextFormField(controller: home, decoration: const InputDecoration(labelText: 'Home / first team'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a team' : null),
      const SizedBox(height: 10),
      TextFormField(controller: away, decoration: const InputDecoration(labelText: 'Away / second team'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a team' : null),
      const SizedBox(height: 10),
      TextField(controller: competition, decoration: const InputDecoration(labelText: 'League / competition')),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: chooseDate, icon: const Icon(Icons.calendar_today), label: Text('${date.day}/${date.month}/${date.year}'))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: chooseTime, icon: const Icon(Icons.schedule), label: Text(time.format(context)))),
      ]),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: status,
        decoration: const InputDecoration(labelText: 'Status'),
        items: const ['Upcoming', 'Live', 'Finished', 'Cancelled'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => status = v ?? 'Upcoming'),
      ),
      const SizedBox(height: 10),
      TextField(controller: source, decoration: const InputDecoration(labelText: 'Fixture source URL (optional)')),
      const SizedBox(height: 10),
      TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
    ])))),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: const Text('Save match')),
    ],
  );
}

class SportsInterestDialog extends StatefulWidget {
  const SportsInterestDialog({super.key, required this.users, this.existing});
  final List<Map<String, Object?>> users;
  final Map<String, Object?>? existing;

  @override
  State<SportsInterestDialog> createState() => _SportsInterestDialogState();
}

class _SportsInterestDialogState extends State<SportsInterestDialog> {
  final sports = TextEditingController();
  final teams = TextEditingController();
  final players = TextEditingController();
  final competitions = TextEditingController();
  final notes = TextEditingController();
  int? userId;
  bool alerts = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final row = widget.existing;
    if (row != null) {
      userId = row['user_id'] as int?;
      sports.text = row['sports'] as String? ?? '';
      teams.text = row['teams'] as String? ?? '';
      players.text = row['players'] as String? ?? '';
      competitions.text = row['competitions'] as String? ?? '';
      notes.text = row['notes'] as String? ?? '';
      alerts = (row['match_alerts'] as num? ?? 0) == 1;
    }
  }

  @override
  void dispose() {
    sports.dispose();
    teams.dispose();
    players.dispose();
    competitions.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (userId == null) return;
    setState(() => saving = true);
    try {
      await AppDatabase.instance.saveSportsInterest(
        userId: userId!,
        sports: sports.text,
        teams: teams.text,
        players: players.text,
        competitions: competitions.text,
        notes: notes.text,
        matchAlerts: alerts,
      );
      await MatchNotificationService.rescheduleAllUpcoming();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Save sports interests' : 'Edit sports interests'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: userId,
                decoration: const InputDecoration(labelText: 'Registered user'),
                items: widget.users.map((user) {
                  return DropdownMenuItem<int>(
                    value: user['id'] as int,
                    child: Text(user['name'] as String),
                  );
                }).toList(),
                onChanged: saving || widget.existing != null ? null : (value) => setState(() => userId = value),
              ),
              const SizedBox(height: 10),
              TextField(controller: sports, decoration: const InputDecoration(labelText: 'Sports (e.g. Cricket, Football)')),
              const SizedBox(height: 10),
              TextField(controller: teams, decoration: const InputDecoration(labelText: 'Favourite teams')),
              const SizedBox(height: 10),
              TextField(controller: players, decoration: const InputDecoration(labelText: 'Favourite players')),
              const SizedBox(height: 10),
              TextField(controller: competitions, decoration: const InputDecoration(labelText: 'Leagues / competitions')),
              const SizedBox(height: 10),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
              SwitchListTile(
                value: alerts,
                onChanged: saving ? null : (value) => setState(() => alerts = value),
                title: const Text('Match alerts opted in'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving || userId == null ? null : save,
          child: Text(saving ? 'Saving…' : widget.existing == null ? 'Save interests' : 'Update interests'),
        ),
      ],
    );
  }
}

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});
  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  bool busy = false;
  String status = 'Backups contain your users, DP, bonuses, prospects, contacts and issue history. Keep a copy somewhere safe.';

  Future<void> exportBackup() async {
    setState(() { busy = true; status = 'Preparing backup…'; });
    try {
      final path = await AppDatabase.instance.createBackupFile();
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'User Hub database backup'));
      if (mounted) setState(() => status = 'Backup prepared. Choose a safe destination in the share sheet.');
    } catch (_) {
      if (mounted) setState(() => status = 'Could not create the backup. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> restoreBackup() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db', 'sqlite', 'sqlite3'],
      allowMultiple: false,
    );
    if (picked == null || picked.files.single.path == null || !mounted) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Restore this backup?'),
      content: const Text('The current local database will be replaced. A rollback copy is kept during the restore, but export your current data first if you may need it.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore backup')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    setState(() { busy = true; status = 'Checking and restoring backup…'; });
    try {
      await AppDatabase.instance.restoreBackupFile(picked.files.single.path!);
      // Rebuild local reminders against the restored match and interest data.
      await MatchNotificationService.rescheduleAllUpcoming();
      if (mounted) setState(() => status = 'Backup restored successfully. Your saved records and eligible match reminders are refreshed.');
    } catch (e) {
      if (mounted) setState(() => status = 'Restore failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> runIntegrityCheck() async {
    setState(() { busy = true; status = 'Checking database integrity…'; });
    try {
      final valid = await AppDatabase.instance.checkIntegrity();
      if (mounted) setState(() => status = valid ? 'Database integrity check passed.' : 'Database integrity check reported a problem. Create a backup before making changes.');
    } catch (_) {
      if (mounted) setState(() => status = 'Could not complete the integrity check.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Backup & restore')),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: emerald),
            const SizedBox(width: 12),
            Expanded(child: Text(status, style: const TextStyle(color: muted, height: 1.4))),
          ],
        ))),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : exportBackup,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Export database backup'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: busy ? null : restoreBackup,
          icon: const Icon(Icons.restore_rounded),
          label: const Text('Restore from backup file'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: busy ? null : runIntegrityCheck,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Check database integrity'),
        ),
        if (busy) ...[
          const SizedBox(height: 18),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    ),
  );
}

class AuditHistoryPage extends StatelessWidget {
  const AuditHistoryPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Audit history')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: AppDatabase.instance.getAuditLog(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return const EmptyState(title: 'Could not load audit history', subtitle: 'Please try again.');
        final rows = snap.data ?? [];
        if (rows.isEmpty) return const EmptyState(title: 'No changes recorded', subtitle: 'Deleted DP and bonus records will be listed here.');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final row = rows[index];
            final date = DateTime.tryParse(row['created_at'] as String? ?? '');
            return Card(child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF3A2A20), child: Icon(Icons.delete_outline_rounded, color: Color(0xFFFFC36B))),
              title: Text('${row['action']} ${row['entity_type']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${row['details']}\n${date?.toLocal().toString().substring(0, 16) ?? ''}'),
              isThreeLine: true,
            ));
          },
        );
      },
    ),
  );
}

class ArchivedUsersPage extends StatefulWidget {
  const ArchivedUsersPage({super.key});
  @override
  State<ArchivedUsersPage> createState() => _ArchivedUsersPageState();
}

class _ArchivedUsersPageState extends State<ArchivedUsersPage> {
  late Future<List<Map<String, Object?>>> users;
  @override
  void initState() { super.initState(); load(); }
  void load() { users = AppDatabase.instance.getArchivedUsers(); }
  Future<void> restore(Map<String, Object?> user) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Restore user?'),
      content: Text('Restore ${user['name']} to the active users list?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
      ],
    ));
    if (confirmed == true) {
      try {
        await AppDatabase.instance.restoreUser(user['id'] as int);
        if (mounted) setState(load);
      } on DatabaseException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.isUniqueConstraintError() ? 'Another active profile already uses this phone number.' : 'Could not restore this user.'),
        ));
      }
    }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Archived users')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: users,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snap.hasError) return const EmptyState(title: 'Could not load archived users', subtitle: 'Please try again.');
        final rows = snap.data ?? [];
        if (rows.isEmpty) return const EmptyState(title: 'No archived users', subtitle: 'Profiles you archive will appear here and can be restored.');
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final user = rows[index];
            return Card(child: ListTile(
              title: Text(user['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${user['phone']} · Lifetime DP: ${user['lifetime_dp']}'),
              trailing: TextButton.icon(onPressed: () => restore(user), icon: const Icon(Icons.unarchive_outlined), label: const Text('Restore')),
            ));
          },
        );
      },
    ),
  );
}

class CustomerIssuesPage extends StatefulWidget {
  const CustomerIssuesPage({super.key});
  @override
  State<CustomerIssuesPage> createState() => _CustomerIssuesPageState();
}

class _CustomerIssuesPageState extends State<CustomerIssuesPage> {
  final search = TextEditingController();
  String filter = 'All';
  late Future<List<Map<String, Object?>>> issues;

  @override
  void initState() {
    super.initState();
    load();
    search.addListener(load);
  }

  void load() => setState(() {
    issues = AppDatabase.instance.getCustomerIssues(search: search.text, status: filter);
  });

  @override
  void dispose() {
    search.removeListener(load);
    search.dispose();
    super.dispose();
  }

  Future<void> addIssue() async {
    final users = await AppDatabase.instance.getUsers();
    if (!mounted) return;
    final saved = await showDialog<bool>(context: context, builder: (_) => CustomerIssueDialog(users: users));
    if (saved == true && mounted) load();
  }

  Future<void> updateIssue(Map<String, Object?> issue) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => UpdateIssueDialog(issue: issue));
    if (saved == true && mounted) load();
  }

  Color priorityColor(String priority) {
    switch (priority) {
      case 'Urgent': return const Color(0xFFFF7777);
      case 'High': return const Color(0xFFFFC36B);
      case 'Low': return muted;
      default: return emerald;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Customer issues')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: addIssue,
      icon: const Icon(Icons.add),
      label: const Text('New issue'),
    ),
    body: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: TextField(
          controller: search,
          decoration: const InputDecoration(hintText: 'Search issues or users', prefixIcon: Icon(Icons.search)),
        ),
      ),
      SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: ['All', 'Open', 'In Progress', 'Waiting for Customer', 'Resolved', 'Closed'].map((value) => Padding(
            padding: const EdgeInsets.only(right: 7),
            child: ChoiceChip(
              label: Text(value),
              selected: filter == value,
              onSelected: (_) => setState(() { filter = value; load(); }),
            ),
          )).toList(),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: FutureBuilder<List<Map<String, Object?>>>(
          future: issues,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return const EmptyState(title: 'Could not load issues', subtitle: 'Please reopen this page and try again.');
            final rows = snap.data ?? [];
            if (rows.isEmpty) {
              return EmptyState(
                title: search.text.isEmpty ? 'No issues recorded' : 'No matching issues',
                subtitle: 'Record customer complaints, questions or service requests and track them to resolution.',
                action: addIssue,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final row = rows[index];
                final priority = row['priority'] as String? ?? 'Normal';
                final status = row['status'] as String? ?? 'Open';
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => updateIssue(row),
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(row['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                          Icon(Icons.circle, size: 9, color: priorityColor(priority)),
                          const SizedBox(width: 5),
                          Text(priority, style: TextStyle(color: priorityColor(priority), fontSize: 11, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 7),
                        Text((row['user_name'] as String?) ?? 'General issue · no linked user', style: const TextStyle(color: muted, fontSize: 12)),
                        if ((row['description'] as String? ?? '').isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(row['description'] as String, maxLines: 3, overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 10),
                        Wrap(spacing: 7, runSpacing: 6, children: [
                          Chip(label: Text(status), visualDensity: VisualDensity.compact),
                          Chip(label: Text(row['category'] as String), visualDensity: VisualDensity.compact),
                        ]),
                        if ((row['resolution'] as String? ?? '').isNotEmpty)
                          Text('Resolution: ${row['resolution']}', style: const TextStyle(color: emerald, fontSize: 12)),
                        Align(alignment: Alignment.centerRight, child: Text('Tap to update', style: TextStyle(color: muted.withValues(alpha: .8), fontSize: 10))),
                      ]),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ]),
  );
}

class CustomerIssueDialog extends StatefulWidget {
  const CustomerIssueDialog({super.key, required this.users});
  final List<Map<String, Object?>> users;
  @override
  State<CustomerIssueDialog> createState() => _CustomerIssueDialogState();
}

class _CustomerIssueDialogState extends State<CustomerIssueDialog> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  int? userId;
  String category = 'General';
  String priority = 'Normal';
  bool saving = false;

  @override
  void dispose() { title.dispose(); description.dispose(); super.dispose(); }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await AppDatabase.instance.addCustomerIssue(
        userId: userId, title: title.text, category: category,
        description: description.text, priority: priority,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save issue: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New customer issue'),
    content: SizedBox(width: 440, child: Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Issue title'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter an issue title' : null),
      const SizedBox(height: 10),
      DropdownButtonFormField<int?>(
        initialValue: userId,
        decoration: const InputDecoration(labelText: 'Link to registered user (optional)'),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('No linked user')),
          ...widget.users.map((u) => DropdownMenuItem<int?>(value: u['id'] as int, child: Text('${u['name']} · ${u['phone']}'))),
        ],
        onChanged: (v) => setState(() => userId = v),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: category,
        decoration: const InputDecoration(labelText: 'Category'),
        items: const ['General', 'Payment', 'Account', 'Technical', 'Bonus', 'Complaint', 'Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => category = v ?? 'General'),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: priority,
        decoration: const InputDecoration(labelText: 'Priority'),
        items: const ['Low', 'Normal', 'High', 'Urgent'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => priority = v ?? 'Normal'),
      ),
      const SizedBox(height: 10),
      TextFormField(controller: description, maxLines: 4, decoration: const InputDecoration(labelText: 'Description / customer message')),
    ])))),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save issue')),
    ],
  );
}

class UpdateIssueDialog extends StatefulWidget {
  const UpdateIssueDialog({super.key, required this.issue});
  final Map<String, Object?> issue;
  @override
  State<UpdateIssueDialog> createState() => _UpdateIssueDialogState();
}

class _UpdateIssueDialogState extends State<UpdateIssueDialog> {
  final resolution = TextEditingController();
  late String status;
  late String priority;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    status = widget.issue['status'] as String? ?? 'Open';
    priority = widget.issue['priority'] as String? ?? 'Normal';
    resolution.text = widget.issue['resolution'] as String? ?? '';
  }

  @override
  void dispose() { resolution.dispose(); super.dispose(); }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await AppDatabase.instance.updateCustomerIssue(
        id: widget.issue['id'] as int, status: status,
        priority: priority, resolution: resolution.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update issue: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Update issue'),
    content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.issue['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: status,
        decoration: const InputDecoration(labelText: 'Progress status'),
        items: const ['Open', 'In Progress', 'Waiting for Customer', 'Resolved', 'Closed'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => status = v ?? 'Open'),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: priority,
        decoration: const InputDecoration(labelText: 'Priority'),
        items: const ['Low', 'Normal', 'High', 'Urgent'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => priority = v ?? 'Normal'),
      ),
      const SizedBox(height: 10),
      TextField(controller: resolution, maxLines: 4, decoration: const InputDecoration(labelText: 'Resolution / update notes')),
    ]))),
    actions: [
      TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
      FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save update')),
    ],
  );
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.icon, required this.title, required this.subtitle});
  final IconData icon; final String title; final String subtitle;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.widgets_outlined, size: 0),
      Icon(icon, size: 42, color: emerald),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: muted, height: 1.5)),
    ]),
  ));
}
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.trailing, this.onTrailingTap});
  final String title; final String? trailing; final VoidCallback? onTrailingTap;
  @override Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(title, style: Theme.of(context).textTheme.titleLarge),
    if (trailing != null) TextButton(onPressed: onTrailingTap, child: Text(trailing!, style: const TextStyle(color: muted, fontSize: 12))),
  ]);
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.label, required this.value, required this.icon, this.dotColor = emerald, this.amberValue = false});
  final String label, value; final IconData icon; final Color dotColor; final bool amberValue;
  @override Widget build(BuildContext context) {
    final numeric = double.tryParse(value.replaceAll(',', ''));
    return Card(child: Padding(padding: const EdgeInsets.fromLTRB(16, 15, 14, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: muted))) ]),
      const SizedBox(height: 14),
      if (numeric != null) AnimatedNumberText(value: numeric, style: GoogleFonts.spaceGrotesk(fontSize: 29, fontWeight: FontWeight.w700, color: amberValue ? amber : const Color(0xFFE8F0EC), letterSpacing: 0))
      else Text(value, style: GoogleFonts.spaceGrotesk(fontSize: 29, fontWeight: FontWeight.w700)),
    ])));
  }
}
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.subtitle, this.action, this.icon, this.compact = false});
  final String title, subtitle; final VoidCallback? action; final IconData? icon; final bool compact;
  @override Widget build(BuildContext context) {
    final illustration = icon ?? (
      title.toLowerCase().contains('dp') ? Icons.account_balance_wallet_rounded :
      title.toLowerCase().contains('bonus') ? Icons.card_giftcard_rounded :
      title.toLowerCase().contains('contact') ? Icons.chat_bubble_rounded :
      title.toLowerCase().contains('match') ? Icons.sports_soccer_rounded :
      title.toLowerCase().contains('issue') ? Icons.support_agent_rounded :
      title.toLowerCase().contains('prospect') ? Icons.person_search_rounded :
      title.toLowerCase().contains('profile') ? Icons.badge_rounded :
      title.toLowerCase().contains('caught') ? Icons.check_circle_rounded :
      title.toLowerCase().contains('report') ? Icons.insert_chart_rounded :
      title.toLowerCase().contains('transaction') ? Icons.receipt_long_rounded :
      title.toLowerCase().contains('match') ? Icons.calendar_month_rounded :
      title.toLowerCase().contains('interest') ? Icons.sports_rounded :
      title.toLowerCase().contains('change') ? Icons.history_rounded :
      title.toLowerCase().contains('archived') ? Icons.archive_rounded :
      title.toLowerCase().contains('follow-up') ? Icons.event_available_rounded : Icons.group_add_rounded
    );
    return Center(child: Padding(padding: EdgeInsets.all(compact ? 18 : 28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: compact ? 76 : 112, height: compact ? 76 : 112, child: Stack(alignment: Alignment.center, children: [
        Container(width: compact ? 76 : 112, height: compact ? 76 : 112, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: emerald.withValues(alpha: .13), width: 2))),
        Container(width: compact ? 58 : 82, height: compact ? 58 : 82, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: emerald.withValues(alpha: .28), width: 2))),
        Container(width: compact ? 38 : 52, height: compact ? 38 : 52, decoration: const BoxDecoration(color: Color(0xFF173126), shape: BoxShape.circle), child: Icon(illustration, size: compact ? 20 : 27, color: emerald)),
      ])),
      const SizedBox(height: 17),
      Text(title, textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: compact ? 16 : 20, color: const Color(0xFFE8F0EC))),
      const SizedBox(height: 7),
      ConstrainedBox(constraints: const BoxConstraints(maxWidth: 290), child: Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 13, height: 1.5))),
      if (action != null) ...[const SizedBox(height: 20), FilledButton.icon(onPressed: action, icon: const Icon(Icons.add_rounded), label: Text(title.toLowerCase().contains('dp') ? 'Record first DP' : title.toLowerCase().contains('bonus') ? 'Add first bonus' : 'Get started'))],
    ])));
  }
}
