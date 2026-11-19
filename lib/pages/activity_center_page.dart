import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/app_database.dart';
import '../data/quiz_database.dart';

class ActivityCenterPage extends StatefulWidget {
  const ActivityCenterPage({super.key, required this.onOpenUser, this.initialFilter = 'All', this.initialRange = 'All'});
  final ValueChanged<int> onOpenUser;
  final String initialFilter;
  final String initialRange;
  @override
  State<ActivityCenterPage> createState() => _ActivityCenterPageState();
}

class _ActivityCenterPageState extends State<ActivityCenterPage> {
  final search = TextEditingController();
  late Future<List<Map<String, Object?>>> future;
  late String typeFilter;
  late String rangeFilter;
  static const types = ['All', 'DP', 'Bonus', 'Contact', 'Task', 'Quiz', 'Issue', 'Prospect', 'System'];
  static const ranges = ['Today', '7 days', '30 days', 'All'];

  @override
  void initState() {
    super.initState();
    typeFilter = types.contains(widget.initialFilter) ? widget.initialFilter : 'All';
    rangeFilter = ranges.contains(widget.initialRange) ? widget.initialRange : 'All';
    future = load();
  }

  Future<List<Map<String, Object?>>> load() async {
    final results = await Future.wait<List<Map<String, Object?>>>([
      AppDatabase.instance.getUnifiedActivityEvents(limit: 500),
      QuizDatabase.instance.getActivityEvents(limit: 250),
    ]);
    final rows = <Map<String, Object?>>[...results[0], ...results[1]];
    rows.sort((a, b) => (b['created_at'] as String? ?? b['event_date'] as String? ?? '').compareTo(
      a['created_at'] as String? ?? a['event_date'] as String? ?? '',
    ));
    return rows;
  }

  @override
  void dispose() { search.dispose(); super.dispose(); }

  String _category(Map<String, Object?> row) {
    final kind = row['kind'] as String? ?? '';
    if (kind == 'DP') return 'DP';
    if (kind.contains('Bonus')) return 'Bonus';
    if (kind.startsWith('Potential')) return 'Prospect';
    if (kind.contains('Contact')) return 'Contact';
    if (kind == 'Task') return 'Task';
    if (kind.startsWith('Quiz')) return 'Quiz';
    if (kind == 'Issue') return 'Issue';
    return 'System';
  }

  List<Map<String, Object?>> _filtered(List<Map<String, Object?>> rows) {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final term = search.text.trim().toLowerCase();
    return rows.where((row) {
      if (typeFilter != 'All' && _category(row) != typeFilter) return false;
      final raw = row['event_date'] as String? ?? '';
      final date = raw.length >= 10 ? raw.substring(0, 10) : raw;
      if (rangeFilter == 'Today' && date != today) return false;
      if (rangeFilter == '7 days' || rangeFilter == '30 days') {
        final parsed = DateTime.tryParse(date);
        final days = rangeFilter == '7 days' ? 7 : 30;
        if (parsed == null || parsed.isBefore(DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1)))) return false;
      }
      if (term.isNotEmpty) {
        final haystack = '${row['name'] ?? ''} ${row['title'] ?? ''} ${row['detail'] ?? ''}'.toLowerCase();
        if (!haystack.contains(term)) return false;
      }
      return true;
    }).toList();
  }

  IconData _icon(String kind) {
    if (kind == 'DP') return Icons.account_balance_wallet_outlined;
    if (kind.contains('Bonus')) return Icons.card_giftcard_outlined;
    if (kind.contains('Contact')) return Icons.chat_bubble_outline_rounded;
    if (kind == 'Task') return Icons.check_circle_outline_rounded;
    if (kind.startsWith('Quiz')) return Icons.quiz_outlined;
    if (kind == 'Issue') return Icons.support_agent_outlined;
    if (kind.startsWith('Potential')) return Icons.person_search_outlined;
    return Icons.history_rounded;
  }

  Future<void> _showDetails(Map<String, Object?> row) async {
    final amount = row['amount'] as num?;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(row['title'] as String? ?? row['kind'] as String? ?? 'Activity'),
        content: Text([
          if ((row['name'] as String? ?? '').isNotEmpty) row['name'],
          if ((row['detail'] as String? ?? '').isNotEmpty) row['detail'],
          if (amount != null) '${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)} coins',
          row['event_date'] ?? '',
        ].join('\n')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activity Center')),
    body: FutureBuilder<List<Map<String, Object?>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Padding(
          padding: EdgeInsets.all(24), child: Text('Could not load the activity history. Please try again.'),
        ));
        final rows = _filtered(snapshot.data ?? const []);
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(hintText: 'Search activity, user or details', prefixIcon: Icon(Icons.search_rounded)),
            ),
          ),
          SizedBox(height: 44, child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: ranges.map((value) => Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(label: Text(value), selected: rangeFilter == value, onSelected: (_) => setState(() => rangeFilter = value)),
            )).toList(),
          )),
          SizedBox(height: 44, child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: types.map((value) => Padding(
              padding: const EdgeInsets.only(right: 7),
              child: ChoiceChip(label: Text(value), selected: typeFilter == value, onSelected: (_) => setState(() => typeFilter = value)),
            )).toList(),
          )),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
            child: Row(children: [
              Expanded(child: Text('${rows.length} activities', style: const TextStyle(fontWeight: FontWeight.w700))),
              IconButton(tooltip: 'Refresh activity', onPressed: () => setState(() => future = load()), icon: const Icon(Icons.refresh_rounded)),
            ]),
          ),
          Expanded(child: rows.isEmpty
            ? const Center(child: Text('No activity matches these filters.'))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 7),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final kind = row['kind'] as String? ?? 'Activity';
                  final amount = row['amount'] as num?;
                  final rawDate = row['created_at'] as String? ?? row['event_date'] as String? ?? '';
                  final date = DateTime.tryParse(rawDate)?.toLocal();
                  final dateLabel = date == null ? (row['event_date']?.toString() ?? '') : DateFormat('d MMM · h:mm a').format(date);
                  final userId = row['user_id'] as int?;
                  return Card(child: ListTile(
                    leading: CircleAvatar(child: Icon(_icon(kind))),
                    title: Text(row['title'] as String? ?? kind, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      if ((row['name'] as String? ?? '').isNotEmpty) row['name'],
                      if ((row['detail'] as String? ?? '').isNotEmpty) row['detail'],
                      dateLabel,
                    ].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: amount == null ? const Icon(Icons.chevron_right_rounded) : Text(
                      '${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)} coins',
                      style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary),
                    ),
                    onTap: userId != null ? () => widget.onOpenUser(userId) : () => _showDetails(row),
                  ));
                },
              )),
        ]);
      },
    ),
  );
}
