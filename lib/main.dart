import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'data/app_database.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UserHubApp());
}

const emerald = Color(0xFF27D3A2);
const muted = Color(0xFF9AADB5);
const panel = Color(0xFF17232B);
const bg = Color(0xFF0D151B);

class UserHubApp extends StatelessWidget {
  const UserHubApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'User Hub',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: emerald, brightness: Brightness.dark, surface: panel),
      scaffoldBackgroundColor: bg,
      appBarTheme: const AppBarTheme(backgroundColor: bg, surfaceTintColor: Colors.transparent),
      cardTheme: CardThemeData(
        color: panel, elevation: 0, margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFF263640))),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: const Color(0xFF101B22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF121D24), indicatorColor: emerald.withValues(alpha: .14),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    ),
    home: const MainShell(),
  );
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
    const titles = ['Good evening', 'Users', 'Activity', 'Contact history', 'More'];
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titles[index], style: const TextStyle(fontWeight: FontWeight.w800)),
          if (index == 0) const Text('Your customer overview', style: TextStyle(fontSize: 12, color: muted)),
        ]),
        actions: [
          if (index == 1) IconButton(onPressed: addUser, icon: const Icon(Icons.person_add_alt_1_rounded)),
          const Padding(padding: EdgeInsets.only(right: 12), child: CircleAvatar(radius: 18, backgroundColor: Color(0xFF183B36), child: Icon(Icons.person, color: emerald))),
        ],
      ),
      body: AnimatedSwitcher(duration: const Duration(milliseconds: 220), child: pages[index]),
      floatingActionButton: index == 0 ? FloatingActionButton.extended(onPressed: addUser, icon: const Icon(Icons.person_add_alt_1), label: const Text('Add user')) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt_rounded), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.timeline_rounded), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum_rounded), label: 'Contacts'),
          NavigationDestination(icon: Icon(Icons.apps_rounded), label: 'More'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<num>>(
    future: Future.wait<num>([
      AppDatabase.instance.countUsers(),
      AppDatabase.instance.countPotentialUsers(),
      AppDatabase.instance.monthDpTotal(),
      AppDatabase.instance.monthBonusTotal(),
      AppDatabase.instance.countOpenCustomerIssues(),
      AppDatabase.instance.todayDpTotal(),
      AppDatabase.instance.todayDpTransactions(),
      AppDatabase.instance.countFollowUpsDue(),
    ]),
    builder: (context, snap) {
      final count = snap.data?[0].toInt() ?? 0;
      final potentialCount = snap.data?[1].toInt() ?? 0;
      final dpMonth = snap.data?[2] ?? 0;
      final bonusMonth = snap.data?[3] ?? 0;
      final openIssues = snap.data?[4].toInt() ?? 0;
      final dpToday = snap.data?[5] ?? 0;
      final dpTransactionsToday = snap.data?[6].toInt() ?? 0;
      final followUpsDue = snap.data?[7].toInt() ?? 0;
      return ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 100), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF27D3A2), Color(0xFF168F79)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('USER HUB', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
            SizedBox(height: 12),
            Text('Your users,\none clear picture.', style: TextStyle(color: Colors.white, fontSize: 25, height: 1.15, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('A private workspace stored on this device.', style: TextStyle(color: Colors.white, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 22),
        const SectionHeading('Overview', trailing: 'All time'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: MetricCard(label: 'Registered users', value: snap.connectionState == ConnectionState.waiting ? '—' : '$count', icon: Icons.people_alt_rounded)),
          const SizedBox(width: 12),
          Expanded(child: MetricCard(label: 'Potential users', value: snap.data == null ? '—' : '$potentialCount', icon: Icons.person_add_alt_1_rounded)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: MetricCard(
            label: 'DP this month',
            value: snap.data == null ? '—' : dpMonth.toStringAsFixed(dpMonth % 1 == 0 ? 0 : 2),
            icon: Icons.account_balance_wallet_rounded,
          )),
          const SizedBox(width: 12),
          Expanded(child: MetricCard(
            label: 'Bonus this month',
            value: snap.data == null ? '—' : bonusMonth.toStringAsFixed(bonusMonth % 1 == 0 ? 0 : 2),
            icon: Icons.card_giftcard_rounded,
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: MetricCard(
            label: 'DP today',
            value: snap.data == null ? '—' : dpToday.toStringAsFixed(dpToday % 1 == 0 ? 0 : 2),
            icon: Icons.today_rounded,
          )),
          const SizedBox(width: 12),
          Expanded(child: MetricCard(
            label: 'DP transactions today',
            value: snap.data == null ? '—' : '$dpTransactionsToday',
            icon: Icons.receipt_long_rounded,
          )),
        ]),
        const SizedBox(height: 12),
        Card(child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          leading: const CircleAvatar(backgroundColor: Color(0xFF183B36), child: Icon(Icons.event_available_rounded, color: emerald)),
          title: const Text('Follow-ups due', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(snap.data == null ? 'Checking scheduled follow-ups…' : '$followUpsDue follow-ups due today or earlier', style: const TextStyle(color: muted)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FollowUpsPage())),
        )),
        const SizedBox(height: 12),
        Card(child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          leading: const CircleAvatar(backgroundColor: Color(0xFF3A2A20), child: Icon(Icons.support_agent_rounded, color: Color(0xFFFFC36B))),
          title: const Text('Customer issues', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(snap.data == null ? 'Checking unresolved requests…' : '$openIssues open or awaiting resolution', style: const TextStyle(color: muted)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerIssuesPage())),
        )),
        const SizedBox(height: 22),
        Card(child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const Icon(Icons.lock_outline, color: emerald),
            const SizedBox(width: 12),
            Expanded(child: Text(count == 0 ? 'Add your first user. Their profile is saved locally on this device.' : '$count user profiles saved locally on this device.', style: const TextStyle(color: muted, height: 1.4))),
          ]),
        )),
      ]);
    },
  );
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
                trailing: Text(
                  amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2),
                  style: TextStyle(color: isDp ? emerald : const Color(0xFFFFC36B), fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ));
            },
          );
        },
      )),
    ]);
  }
}

class BonusEntryDialog extends StatefulWidget {
  const BonusEntryDialog({super.key});
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
      await AppDatabase.instance.addBonusEntry(
        userId: userId!,
        date: DateTime.now(),
        amount: double.parse(amount.text.trim()),
        reason: reason,
        relatedDp: relatedDp.text.trim().isEmpty ? null : double.parse(relatedDp.text.trim()),
        notes: notes.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on Exception {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save this bonus record.')));
    }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add bonus record'),
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
      FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save bonus')),
    ],
  );
}

class DpEntryDialog extends StatefulWidget {
  const DpEntryDialog({super.key});
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
  void initState() { super.initState(); users = AppDatabase.instance.getUsers(); }
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
      await AppDatabase.instance.addDpEntry(userId: userId!, date: DateTime.now(), amounts: values, contacted: contacted, notes: notes.text);
      if (mounted) Navigator.pop(context, true);
    } on Exception {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save this DP record.')));
    }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record daily DP'),
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
      FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save DP')),
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
                    if (v == 'convert') await convert(row);
                    if (v == 'interested') { await AppDatabase.instance.updatePotentialStatus(row['id'] as int, 'Interested'); load(); }
                    if (v == 'not_interested') { await AppDatabase.instance.updatePotentialStatus(row['id'] as int, 'Not Interested'); load(); }
                    if (v == 'do_not_contact') { await AppDatabase.instance.updatePotentialStatus(row['id'] as int, 'Do Not Contact'); load(); }
                  },
                  itemBuilder: (_) => const [
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
  const PotentialUserDialog({super.key});
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
  bool permission = false;
  bool saving = false;
  @override
  void dispose() { name.dispose(); phone.dispose(); source.dispose(); language.dispose(); sports.dispose(); notes.dispose(); super.dispose(); }
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      await AppDatabase.instance.addPotentialUser(
        name: name.text, phone: phone.text, source: source.text,
        language: language.text, sports: sports.text, notes: notes.text,
        status: status, contactPermission: permission,
      );
      if (mounted) Navigator.pop(context, true);
    } on DatabaseException catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.isUniqueConstraintError() ? 'This phone number is already in your prospects.' : 'Could not save this prospect.')));
    }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add potential user'),
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
      FilledButton(onPressed: saving ? null : save, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save prospect')),
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
