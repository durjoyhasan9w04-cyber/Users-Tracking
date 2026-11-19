import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';

class QuickEntrySaved {
  const QuickEntrySaved({required this.kind, required this.id, required this.createdAt, required this.amount, required this.userName});
  final String kind;
  final int id;
  final String createdAt;
  final double amount;
  final String userName;
}

class QuickEntrySheet extends StatefulWidget {
  const QuickEntrySheet({super.key, this.initialUserId, this.initialType = 'DP'});
  final int? initialUserId;
  final String initialType;

  static Future<QuickEntrySaved?> show(BuildContext context, {int? initialUserId, String initialType = 'DP'}) =>
    showModalBottomSheet<QuickEntrySaved>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => FractionallySizedBox(heightFactor: .86, child: QuickEntrySheet(initialUserId: initialUserId, initialType: initialType)),
    );

  @override
  State<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends State<QuickEntrySheet> {
  static const _lastUserKey = 'user_hub_last_quick_entry_user';
  final amount = TextEditingController();
  final notes = TextEditingController();
  final search = TextEditingController();
  late Future<List<Map<String, Object?>>> usersFuture;
  List<Map<String, Object?>> users = [];
  int? selectedUserId;
  String mode = 'DP';
  String reason = 'Deposit';
  String query = '';
  bool contacted = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    mode = widget.initialType == 'Bonus' ? 'Bonus' : 'DP';
    selectedUserId = widget.initialUserId;
    usersFuture = _loadUsers();
    search.addListener(() => setState(() => query = search.text));
  }

  Future<List<Map<String, Object?>>> _loadUsers() async {
    final rows = await AppDatabase.instance.getUsers();
    if (selectedUserId == null || !rows.any((u) => u['id'] == selectedUserId)) {
      final prefs = await SharedPreferences.getInstance();
      final remembered = prefs.getInt(_lastUserKey);
      selectedUserId = rows.any((u) => u['id'] == remembered) ? remembered : null;
    }
    selectedUserId ??= rows.isEmpty ? null : rows.first['id'] as int;
    return rows;
  }

  @override
  void dispose() { amount.dispose(); notes.dispose(); search.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choose a user first.')));
      return;
    }
    final value = double.tryParse(amount.text.trim());
    if (value == null || !value.isFinite || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an amount greater than zero.')));
      return;
    }
    Map<String, Object?>? selected;
    for (final user in users) {
      if (user['id'] == selectedUserId) { selected = user; break; }
    }
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That user is no longer available. Refresh and try again.')));
      return;
    }
    setState(() => saving = true);
    final createdAt = DateTime.now().toIso8601String();
    try {
      final int id;
      if (mode == 'DP') {
        id = await AppDatabase.instance.addDpEntry(
          userId: selectedUserId!, date: DateTime.now(), amounts: [value],
          contacted: contacted, notes: notes.text, createdAt: createdAt,
        );
      } else {
        id = await AppDatabase.instance.addBonusEntry(
          userId: selectedUserId!, date: DateTime.now(), amount: value,
          reason: reason, notes: notes.text, createdAt: createdAt,
        );
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastUserKey, selectedUserId!);
      if (!mounted) return;
      Navigator.pop(context, QuickEntrySaved(
        kind: mode, id: id, createdAt: createdAt, amount: value,
        userName: selected['name'] as String? ?? 'User',
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save this entry: $error')));
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, Object?>>>(
    future: usersFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return const Center(child: Text('Could not load users. Please close and retry.'));
      users = snapshot.data ?? [];
      return _form(context);
    },
  );

  Widget _form(BuildContext context) {
    final filtered = users.where((u) => '${u['name']} ${u['phone']}'.toLowerCase().contains(query.toLowerCase())).toList();
    return SafeArea(child: Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(context).viewInsets.bottom + 18),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(
          color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(4),
        ))),
        const SizedBox(height: 14),
        Row(children: [
          const Expanded(child: Text('Quick Entry', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
          IconButton(onPressed: saving ? null : () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ]),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'DP', label: Text('DP'), icon: Icon(Icons.account_balance_wallet_outlined)),
            ButtonSegment(value: 'Bonus', label: Text('Bonus'), icon: Icon(Icons.card_giftcard_outlined)),
          ],
          selected: {mode},
          onSelectionChanged: saving ? null : (value) => setState(() { mode = value.first; amount.clear(); }),
        ),
        const SizedBox(height: 14),
        TextField(controller: search, decoration: const InputDecoration(labelText: 'Find user', prefixIcon: Icon(Icons.search_rounded))),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: filtered.any((u) => u['id'] == selectedUserId) ? selectedUserId : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'User'),
          items: filtered.map((u) => DropdownMenuItem<int>(
            value: u['id'] as int, child: Text('${u['name']} · ${u['phone']}', overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: saving ? null : (value) => setState(() => selectedUserId = value),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: mode == 'DP' ? 'DP amount (coins)' : 'Bonus amount (coins)', prefixIcon: const Icon(Icons.currency_exchange_rounded)),
        ),
        if (mode == 'Bonus') ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: reason,
            decoration: const InputDecoration(labelText: 'Bonus reason'),
            items: const ['Deposit', 'Special', 'Promotional', 'Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: saving ? null : (v) => setState(() => reason = v ?? 'Other'),
          ),
        ],
        if (mode == 'DP') CheckboxListTile(
          contentPadding: EdgeInsets.zero, value: contacted,
          onChanged: saving ? null : (v) => setState(() => contacted = v ?? false),
          title: const Text('Contacted today'), controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: saving || users.isEmpty ? null : _save,
          icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
          label: Text(saving ? 'Saving…' : 'Save $mode'),
        ),
      ])),
    ));
  }
}

void showQuickEntryUndo(BuildContext context, QuickEntrySaved saved, VoidCallback onChanged) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(SnackBar(
    content: Text('${saved.kind} saved for ${saved.userName} · ${saved.amount.toStringAsFixed(saved.amount % 1 == 0 ? 0 : 2)} coins'),
    duration: const Duration(seconds: 8),
    action: SnackBarAction(
      label: 'UNDO',
      onPressed: () async {
        final undone = saved.kind == 'DP'
            ? await AppDatabase.instance.undoQuickDpEntry(id: saved.id, createdAt: saved.createdAt)
            : await AppDatabase.instance.undoQuickBonusEntry(id: saved.id, createdAt: saved.createdAt);
        messenger.showSnackBar(SnackBar(content: Text(undone ? 'Entry undone and totals restored.' : 'Undo is no longer available for this entry.')));
        if (undone) onChanged();
      },
    ),
  ));
}
