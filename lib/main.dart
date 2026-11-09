import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UserHubApp());
}

class UserHubApp extends StatelessWidget {
  const UserHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    const emerald = Color(0xFF27D3A2);
    return MaterialApp(
      title: 'User Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: emerald,
          brightness: Brightness.dark,
          surface: const Color(0xFF17232B),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D151B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D151B),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF263640)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Color(0xFF121D24),
          indicatorColor: emerald.withValues(alpha: 0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          elevation: 0,
        ),
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [
    DashboardPage(),
    UsersPage(),
    ActivityPage(),
    AlertsPage(),
    MorePage(),
  ];

  static const _titles = [
    'Good evening',
    'Users',
    'Activity',
    'Smart alerts',
    'More',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titles[_index], style: const TextStyle(fontWeight: FontWeight.w800)),
            if (_index == 0)
              const Text(
                'Your customer overview',
                style: TextStyle(fontSize: 12, color: Color(0xFF9AADB5), fontWeight: FontWeight.w400),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () {},
            icon: const Icon(Icons.search_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF183B36),
              child: Icon(Icons.person_rounded, color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        child: _pages[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), selectedIcon: Icon(Icons.people_alt_rounded), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.timeline_rounded), label: 'Activity'),
          NavigationDestination(icon: Icon(Icons.notifications_none_rounded), selectedIcon: Icon(Icons.notifications_rounded), label: 'Alerts'),
          NavigationDestination(icon: Icon(Icons.apps_rounded), label: 'More'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('dashboard'),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF27D3A2), Color(0xFF168F79)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('USER HUB', style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
              SizedBox(height: 12),
              Text('Your users,\none clear picture.', style: TextStyle(color: Colors.white, fontSize: 25, height: 1.15, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text('Track activity, preferences and relationships.', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const SectionHeading('Overview', trailing: 'All time'),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(child: MetricCard(label: 'Registered users', value: '0', icon: Icons.people_alt_rounded, tint: Color(0xFF183B36))),
            SizedBox(width: 12),
            Expanded(child: MetricCard(label: 'Potential users', value: '0', icon: Icons.person_add_alt_1_rounded, tint: Color(0xFF202F4A))),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(child: MetricCard(label: 'DP this month', value: '0', icon: Icons.account_balance_wallet_rounded, tint: Color(0xFF183B3B))),
            SizedBox(width: 12),
            Expanded(child: MetricCard(label: 'Follow-ups due', value: '0', icon: Icons.event_note_rounded, tint: Color(0xFF403324))),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeading('Quick actions'),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(child: QuickAction(icon: Icons.person_add_alt_1_rounded, label: 'Add user')),
            SizedBox(width: 10),
            Expanded(child: QuickAction(icon: Icons.add_chart_rounded, label: 'Record DP')),
            SizedBox(width: 10),
            Expanded(child: QuickAction(icon: Icons.group_add_rounded, label: 'Add lead')),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeading('Today’s attention'),
        const SizedBox(height: 12),
        const EmptyStateCard(
          icon: Icons.notifications_active_outlined,
          title: 'You’re all caught up',
          subtitle: 'Match reminders and follow-ups will appear here.',
        ),
      ],
    );
  }
}

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(
    key: ValueKey('users'),
    icon: Icons.people_alt_outlined,
    title: 'Your users',
    subtitle: 'Registered users, DP levels and searchable profiles will live here.',
  );
}

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(
    key: ValueKey('activity'),
    icon: Icons.timeline_rounded,
    title: 'Activity timeline',
    subtitle: 'DP, bonuses, contacts, notes and other recorded events in one timeline.',
  );
}

class AlertsPage extends StatelessWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(
    key: ValueKey('alerts'),
    icon: Icons.notifications_active_outlined,
    title: 'Smart alerts',
    subtitle: 'Favourite-team matches, usual DP-time reminders and follow-ups.',
  );
}

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) => const PlaceholderPage(
    key: ValueKey('more'),
    icon: Icons.apps_rounded,
    title: 'More tools',
    subtitle: 'Potential users, DP & bonuses, sports, relationships, reports and settings.',
  );
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9AADB5), height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        if (trailing != null) Text(trailing!, style: const TextStyle(fontSize: 12, color: Color(0xFF9AADB5))),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.label, required this.value, required this.icon, required this.tint});

  final String label;
  final String value;
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFF27D3A2), size: 19),
            ),
            const SizedBox(height: 14),
            Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9AADB5))),
          ],
        ),
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  const QuickAction({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE8EFEB))),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(height: 7),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({super.key, required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 30, color: const Color(0xFF27D3A2)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9AADB5), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
