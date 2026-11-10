import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'data/app_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UserHubApp());
  unawaited(AppDatabase.instance.createDailyBackupIfNeeded().catchError((_) {}));
}

const emerald = Color(0xFF3DDC97);
const amber = Color(0xFFF5B94A);
const muted = Color(0xFF8B9B94);
const panel = Color(0xFF111B18);
const bg = Color(0xFF0A110F);
const panelBorder = Color(0xFF1D2A25);

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
      DashboardPage(key: ValueKey('home-$revision')),
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
          Padding(padding: const EdgeInsets.only(right: 18), child: CircleAvatar(
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
  const DashboardPage({super.key});
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
        final previousDp = previousTotals?['dp']?.toDouble() ?? 0;
        final delta = previousDp > 0 ? ((dpMonth.toDouble() - previousDp) / previousDp) * 100 : null;
        final recent = <Map<String, Object?>>[
          ...dpRows.take(8).map((r) => <String, Object?>{'kind': 'DP', 'name': r['user_name'], 'date': r['entry_date'], 'amount': r['total']}),
          ...bonusRows.take(8).map((r) => <String, Object?>{'kind': 'Bonus', 'name': r['user_name'], 'date': r['entry_date'], 'amount': r['amount']}),
        ]..sort((a, b) => (b['date'] as String? ?? '').compareTo(a['date'] as String? ?? ''));
        final trend = dpRows.take(7).toList().reversed.map((r) => (r['total'] as num?)?.toDouble() ?? 0).toList();
        return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 132), children: [
          HeroKpiCard(label: 'DP this month', value: dpMonth, delta: delta, sparkline: trend, loading: snap.connectionState == ConnectionState.waiting),
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
            Expanded(child: MetricCard(label: 'Bonus this month', value: bonusMonth.toStringAsFixed(bonusMonth % 1 == 0 ? 0 : 2), icon: Icons.card_giftcard_rounded, dotColor: amber, amberValue: true)),
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
    final points = values.length < 2 ? [0.35, 0.48, 0.42, 0.66, 0.59, 0.78, 0.72] : values;
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
String dpLevel(double amount, {required bool monthly}) {
  if (monthly) {
    if (amount >= 5000) return 'High';
    if (amount >= 1500) return 'Medium';
    if (amount >= 200) return 'Low';
    return 'Neighborly';
  }
  if (amount >= 10000) return 'High';
  if (amount >= 3000) return 'Medium';
  if (amount >= 500) return 'Low';
  return 'Neighborly';
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<UsersPage> createState() => _UsersPageState();
}
class _UsersPageState extends State<UsersPage> {
  final search = TextEditingController();
  String lifetimeFilter = 'All';
  String monthlyFilter = 'All';
  late Future<List<Map<String, Object?>>> future;
  @override
  void initState() {
    super.initState();
    load();
    search.addListener(load);
  }
  void load() => setState(() => future = AppDatabase.instance.getUsers(search: search.text));
  @override
  void dispose() { search.removeListener(load); search.dispose(); super.dispose(); }
  Future<void> edit(Map<String, Object?>? user) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => UserFormDialog(user: user));
    if (ok == true) { load(); widget.onChanged(); }
  }
  Future<void> archive(Map<String, Object?> user) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Archive user?'),
      content: Text('Archive ${user['name']}? Their profile will be hidden from this list.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive')),
      ],
    ));
    if (ok == true) { await AppDatabase.instance.archiveUser(user['id'] as int); load(); widget.onChanged(); }
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 8), child: TextField(
      controller: search, decoration: const InputDecoration(hintText: 'Search by name or phone', prefixIcon: Icon(Icons.search)),
    )),
    Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 10), child: Row(children: [
      Expanded(child: DropdownButtonFormField<String>(
        initialValue: lifetimeFilter,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Lifetime level', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        items: const ['All', 'High', 'Medium', 'Low', 'Neighborly'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => lifetimeFilter = v ?? 'All'),
      )),
      const SizedBox(width: 10),
      Expanded(child: DropdownButtonFormField<String>(
        initialValue: monthlyFilter,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Monthly level', contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        items: const ['All', 'High', 'Medium', 'Low', 'Neighborly'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => monthlyFilter = v ?? 'All'),
      )),
    ])),
    Expanded(child: FutureBuilder<List<Map<String, Object?>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final allRows = snap.data ?? [];
        final rows = allRows.where((user) {
          final lifetime = dpLevel((user['lifetime_dp'] as num).toDouble(), monthly: false);
          final monthly = dpLevel((user['monthly_dp'] as num).toDouble(), monthly: true);
          return (lifetimeFilter == 'All' || lifetime == lifetimeFilter) &&
              (monthlyFilter == 'All' || monthly == monthlyFilter);
        }).toList();
        if (rows.isEmpty) {
          return EmptyState(
          title: search.text.isEmpty ? 'No users yet' : 'No matching users',
          subtitle: search.text.isEmpty ? 'Tap Add user to create your first local profile.' : 'Try another name or phone number.',
            action: search.text.isEmpty ? () => edit(null) : null,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 100),
          itemCount: rows.length, separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final user = rows[i];
            final name = user['name'] as String;
            return Card(child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              leading: CircleAvatar(backgroundColor: const Color(0xFF183B36), child: Text(name[0].toUpperCase(), style: const TextStyle(color: emerald, fontWeight: FontWeight.bold))),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['phone'] as String, style: const TextStyle(color: muted)),
                  const SizedBox(height: 4),
                  Text(
                    'Lifetime: ${dpLevel((user['lifetime_dp'] as num).toDouble(), monthly: false)}  •  Month: ${dpLevel((user['monthly_dp'] as num).toDouble(), monthly: true)}',
                    style: const TextStyle(color: emerald, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => UserProfilePage(userId: user['id'] as int, onChanged: () { load(); widget.onChanged(); }),
              )),
              trailing: PopupMenuButton<String>(
                onSelected: (v) { if (v == 'edit') edit(user); if (v == 'archive') archive(user); },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit profile')),
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              ),
            ));
          },
        );
      },
    )),
  ]);
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
    ]);
  }
  Future<void> edit(Map<String, Object?> user) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => UserFormDialog(user: user));
    if (saved == true && mounted) { setState(load); widget.onChanged(); }
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
        final name = user['name'] as String? ?? 'User';
        final lastDp = user['last_dp_date'] as String?;
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
                Text('Last DP: ${lastDp ?? 'Never'}', style: const TextStyle(color: muted, fontSize: 12)),
                Text('Last contact: ${lastContact ?? 'Not recorded'}', style: const TextStyle(color: muted, fontSize: 12)),
              ]),
            )),
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
            const SizedBox(height: 20),
            const SizedBox(height: 8),
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
  bool saving = false;
  @override
  void dispose() { name.dispose(); phone.dispose(); notes.dispose(); super.dispose(); }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      if (widget.user == null) {
        await AppDatabase.instance.addUser(name: name.text, phone: phone.text, notes: notes.text);
      } else {
        await AppDatabase.instance.updateUser(id: widget.user!['id'] as int, name: name.text, phone: phone.text, notes: notes.text);
      }
      if (mounted) Navigator.pop(context, true);
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
      const SizedBox(height: 12),
      TextFormField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes (optional)')),
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
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        child: Row(children: [
          Expanded(child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'dp', label: Text('DP'), icon: Icon(Icons.account_balance_wallet_outlined)),
              ButtonSegment(value: 'bonus', label: Text('Bonuses'), icon: Icon(Icons.card_giftcard_rounded)),
            ],
            selected: {section},
            onSelectionChanged: (value) => setState(() => section = value.first),
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
              subtitle: isDp ? 'Record a DP entry to build the activity history.' : 'Add a bonus record to keep its history separate from DP.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
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
    users = AppDatabase.instance.getUsers();
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
        return Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(
            initialValue: userId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'User'),
            items: rows.map((u) => DropdownMenuItem<int>(value: u['id'] as int, child: Text(u['name'] as String, overflow: TextOverflow.ellipsis))).toList(),
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
    users = AppDatabase.instance.getUsers();
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
        await AppDatabase.instance.updateDpEntry(id: existing['id'] as int, amounts: values, contacted: contacted, notes: notes.text);
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
        return Form(key: form, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<int>(
            initialValue: userId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'User'),
            items: rows.map((u) => DropdownMenuItem<int>(value: u['id'] as int, child: Text(u['name'] as String, overflow: TextOverflow.ellipsis))).toList(),
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
        if (contacts.isEmpty && prospects.isEmpty) return const EmptyState(title: 'You are all caught up', subtitle: 'There are no overdue or due follow-ups.');
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

class ContactLogDialog extends StatefulWidget {
  const ContactLogDialog({super.key, required this.users});
  final List<Map<String, Object?>> users;
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

  @override
  void initState() {
    super.initState();
    userId = widget.users.first['id'] as int;
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
              onChanged: (v) => setState(() => userId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: channel,
              decoration: const InputDecoration(labelText: 'Contact channel'),
              items: const ['WhatsApp', 'Phone', 'Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
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
        subtitle: 'Save user interests and manage a manual match calendar',
        onTap: () => open(context, const SportsMatchesPage()),
      ),
      const SizedBox(height: 10),
      _MoreTile(
        icon: Icons.backup_outlined,
        title: 'Backup & restore',
        subtitle: 'Export a local database backup or restore one',
        onTap: () => open(context, const BackupRestorePage()),
      ),
      const SizedBox(height: 10),
      _MoreTile(
        icon: Icons.summarize_outlined,
        title: 'Reports & export',
        subtitle: 'Review period totals and export transaction history',
        onTap: () => open(context, const ReportsPage()),
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
              label: Text(exporting ? 'Preparing CSV…' : 'Export transaction CSV'),
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
  void initState() { super.initState(); load(); search.addListener(load); }
  void load() {
    matches = AppDatabase.instance.getMatches(search: search.text);
    interests = AppDatabase.instance.getSportsInterests();
  }
  @override
  void dispose() { search.removeListener(load); search.dispose(); super.dispose(); }
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
    appBar: AppBar(title: const Text('Sports & matches')),
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
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: TextField(
          controller: search,
          decoration: const InputDecoration(hintText: 'Search teams, sport or competition', prefixIcon: Icon(Icons.search)),
        )),
      Expanded(child: section == 'matches'
        ? FutureBuilder<List<Map<String, Object?>>>(future: matches, builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return const EmptyState(title: 'Could not load matches', subtitle: 'Please try again.');
            final rows = snap.data ?? [];
            if (rows.isEmpty) return const EmptyState(title: 'No matches saved', subtitle: 'Add fixtures manually. Match coverage is not automatically sourced.');
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
                  trailing: Icon(row['match_alerts'] == 1 ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, color: row['match_alerts'] == 1 ? emerald : muted),
                ));
              },
            );
          })),
    ]),
  );
}

class MatchDialog extends StatefulWidget {
  const MatchDialog({super.key});
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
  const SportsInterestDialog({super.key, required this.users});
  final List<Map<String, Object?>> users;

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
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save sports interests'),
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
                onChanged: saving ? null : (value) => setState(() => userId = value),
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
          child: Text(saving ? 'Saving…' : 'Save interests'),
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
      if (mounted) setState(() => status = 'Backup restored successfully. Your saved records are now loaded.');
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
  const SectionHeading(this.title, {super.key, this.trailing});
  final String title; final String? trailing;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
    if (trailing != null) Text(trailing!, style: const TextStyle(fontSize: 12, color: muted)),
  ]);
}
class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.label, required this.value, required this.icon});
  final String label; final String value; final IconData icon;
  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(15),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: const Color(0xFF183B36), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: emerald, size: 19)),
      const SizedBox(height: 14),
      Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(fontSize: 11, color: muted)),
    ]),
  ));
}
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.subtitle, this.action});
  final String title; final String subtitle; final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(28),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.people_outline_rounded, size: 38, color: emerald),
      const SizedBox(height: 14),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      const SizedBox(height: 6),
      Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12, height: 1.5)),
      if (action != null) ...[const SizedBox(height: 16), FilledButton.icon(onPressed: action, icon: const Icon(Icons.person_add_alt_1), label: const Text('Add user'))],
    ]),
  ));
}
