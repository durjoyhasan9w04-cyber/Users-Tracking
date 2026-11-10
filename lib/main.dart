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
      const PlaceholderPage(icon: Icons.notifications_active_outlined, title: 'Smart alerts', subtitle: 'Match reminders and follow-ups will appear here when configured.'),
      const PlaceholderPage(icon: Icons.apps_rounded, title: 'More tools', subtitle: 'Potential users, DP & bonuses, sports, relationships, reports and settings.'),
    ];
    const titles = ['Good evening', 'Users', 'Activity', 'Smart alerts', 'More'];
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
          NavigationDestination(icon: Icon(Icons.notifications_none_rounded), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.apps_rounded), label: 'More'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<int>(
    future: AppDatabase.instance.countUsers(),
    builder: (context, snap) {
      final count = snap.data ?? 0;
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
          const Expanded(child: MetricCard(label: 'Potential users', value: '0', icon: Icons.person_add_alt_1_rounded)),
        ]),
        const SizedBox(height: 12),
        const Row(children: [
          Expanded(child: MetricCard(label: 'DP this month', value: '—', icon: Icons.account_balance_wallet_rounded)),
          SizedBox(width: 12),
          Expanded(child: MetricCard(label: 'Follow-ups due', value: '—', icon: Icons.event_note_rounded)),
        ]),
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

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<UsersPage> createState() => _UsersPageState();
}
class _UsersPageState extends State<UsersPage> {
  final search = TextEditingController();
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
    Padding(padding: const EdgeInsets.fromLTRB(18, 8, 18, 12), child: TextField(
      controller: search, decoration: const InputDecoration(hintText: 'Search by name or phone', prefixIcon: Icon(Icons.search)),
    )),
    Expanded(child: FutureBuilder<List<Map<String, Object?>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final rows = snap.data ?? [];
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
              subtitle: Text(user['phone'] as String, style: const TextStyle(color: muted)),
              onTap: () => edit(user),
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
  late Future<List<Map<String, Object?>>> entries;
  @override
  void initState() { super.initState(); load(); }
  void load() => entries = AppDatabase.instance.getDpEntries();
  Future<void> addEntry() async {
    final saved = await showDialog<bool>(context: context, builder: (_) => const DpEntryDialog());
    if (!mounted) return;
    if (saved == true) setState(load);
  }
  @override
  Widget build(BuildContext context) => Column(children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Row(children: [
        const Expanded(child: Text('DP records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
        FilledButton.icon(onPressed: addEntry, icon: const Icon(Icons.add, size: 18), label: const Text('Record DP')),
      ]),
    ),
    Expanded(child: FutureBuilder<List<Map<String, Object?>>>(
      future: entries,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final rows = snap.data ?? [];
        if (rows.isEmpty) return const EmptyState(title: 'No DP records yet', subtitle: 'Record a DP entry to start building the user activity history.');
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 9),
          itemBuilder: (context, i) {
            final row = rows[i];
            final total = (row['total'] as num).toDouble();
            final date = row['entry_date'] as String;
            final count = row['dp_count'] as int;
            return Card(child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFF183B36), child: Icon(Icons.account_balance_wallet_outlined, color: emerald)),
              title: Text(row['user_name'] as String, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('$date  •  $count DP${count == 1 ? '' : 's'}', style: const TextStyle(color: muted)),
              trailing: Text(total.toStringAsFixed(total % 1 == 0 ? 0 : 2), style: const TextStyle(color: emerald, fontWeight: FontWeight.w800, fontSize: 16)),
            ));
          },
        );
      },
    )),
  ]);
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
