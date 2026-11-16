import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../data/quiz_database.dart';

class QuizParticipantsPage extends StatefulWidget {
  const QuizParticipantsPage({super.key, required this.onAddBonus});
  final Future<void> Function(int userId) onAddBonus;
  @override State<QuizParticipantsPage> createState() => _QuizParticipantsPageState();
}

class _QuizParticipantsPageState extends State<QuizParticipantsPage> {
  final search = TextEditingController();
  int? selectedQuizId;
  late Future<List<Map<String, Object?>>> quizzes;
  late Future<List<Map<String, Object?>>> participants;

  @override void initState() { super.initState(); load(); search.addListener(loadParticipants); }
  @override void dispose() { search.removeListener(loadParticipants); search.dispose(); super.dispose(); }
  void load() {
    quizzes = QuizDatabase.instance.getQuizzes();
    participants = Future.value(const <Map<String, Object?>>[]);
    _loadInitialData();
  }
  Future<void> _loadInitialData() async {
    final rows = await quizzes;
    if (!mounted) return;
    if (selectedQuizId == null && rows.isNotEmpty) selectedQuizId = rows.first['id'] as int;
    participants = QuizDatabase.instance.getParticipants(search: search.text, quizId: selectedQuizId);
    if (mounted) setState(() {});
  }
  void loadParticipants() {
    participants = QuizDatabase.instance.getParticipants(search: search.text, quizId: selectedQuizId);
    if (mounted) setState(() {});
  }
  Future<void> refresh() async {
    quizzes = QuizDatabase.instance.getQuizzes();
    participants = QuizDatabase.instance.getParticipants(search: search.text, quizId: selectedQuizId);
    if (mounted) setState(() {});
  }

  Future<void> createQuiz() async {
    final title = TextEditingController();
    final notes = TextEditingController();
    DateTime date = DateTime.now();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: const Text('Create quiz'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Quiz name')),
        const SizedBox(height: 10),
        OutlinedButton.icon(onPressed: () async {
          final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null) setDialog(() => date = picked);
        }, icon: const Icon(Icons.calendar_month), label: Text(formatQuizDate(date))),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, title.text.trim().isNotEmpty), child: const Text('Create'))],
    )));
    if (ok == true && title.text.trim().isNotEmpty) {
      selectedQuizId = await QuizDatabase.instance.addQuiz(title: title.text, date: date, notes: notes.text);
      await refresh();
    }
    title.dispose(); notes.dispose();
  }

  Future<void> addParticipant() async {
    final name = TextEditingController(), phone = TextEditingController(), notes = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add quiz participant'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number (required)', hintText: 'Needed to convert and award bonus')),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, name.text.trim().isNotEmpty && phone.text.trim().length >= 5), child: const Text('Save'))],
    ));
    if (ok == true && name.text.trim().isNotEmpty) {
      try {
        int? linked;
        final cleanPhone = phone.text.trim();
        if (cleanPhone.isNotEmpty) {
          final users = await AppDatabase.instance.getUsers(search: cleanPhone);
          for (final u in users) { if ((u['phone'] as String? ?? '').trim() == cleanPhone) linked = u['id'] as int; }
        }
        await QuizDatabase.instance.addParticipant(name: name.text, phone: cleanPhone, notes: notes.text, linkedUserId: linked);
        await refresh();
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add participant. This phone may already be in the quiz list.')));
      }
    }
    name.dispose(); phone.dispose(); notes.dispose();
  }

  Future<int?> ensureRegularUser(Map<String, Object?> p) async {
    final linked = p['linked_user_id'] as int?;
    if (linked != null) return linked;
    final phone = (p['phone'] as String? ?? '').trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a phone number before converting.')));
      return null;
    }
    final users = await AppDatabase.instance.getUsers(search: phone);
    for (final u in users) {
      if ((u['phone'] as String? ?? '').trim() == phone) {
        final id = u['id'] as int;
        await QuizDatabase.instance.linkRegularUser(p['id'] as int, id);
        return id;
      }
    }
    if (!mounted) return null;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Convert to regular user?'),
      content: Text('This adds ${p['name']} to the existing Users database so the current Bonus function can be used. No DP record will be created.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Convert'))],
    ));
    if (ok != true) return null;
    try {
      final id = await AppDatabase.instance.addUser(
        name: p['name'] as String, phone: phone,
        notes: 'Converted from Quiz Participants. ${p['notes'] ?? ''}'.trim(),
      );
      await QuizDatabase.instance.linkRegularUser(p['id'] as int, id);
      return id;
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not convert. This phone may already exist in Users or Potential users.')));
      return null;
    }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quiz Participants')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        Expanded(child: Text('Quizzes', style: Theme.of(context).textTheme.titleLarge)),
        FilledButton.icon(onPressed: createQuiz, icon: const Icon(Icons.add), label: const Text('New quiz')),
      ]),
      const SizedBox(height: 8),
      FutureBuilder<List<Map<String, Object?>>>(future: quizzes, builder: (context, snap) {
        final rows = snap.data ?? const [];
        if (rows.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Create a quiz to start recording participation.')));
        final current = rows.any((r) => r['id'] == selectedQuizId) ? selectedQuizId : rows.first['id'] as int;
        selectedQuizId = current;
        return DropdownButtonFormField<int>(
          value: current,
          decoration: const InputDecoration(labelText: 'Select quiz'),
          items: rows.map((r) => DropdownMenuItem<int>(value: r['id'] as int, child: Text('${r['title']} · ${r['participant_count']} joined', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { selectedQuizId = v; loadParticipants(); },
        );
      }),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(child: Text('Participant list', style: Theme.of(context).textTheme.titleLarge)),
        FilledButton.icon(onPressed: addParticipant, icon: const Icon(Icons.person_add_alt_1), label: const Text('Add')),
      ]),
      const SizedBox(height: 8),
      TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name or phone')),
      const SizedBox(height: 8),
      FutureBuilder<List<Map<String, Object?>>>(future: participants, builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        final rows = snap.data ?? const [];
        if (rows.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No participants yet.')));
        return Column(children: rows.map((p) {
          final joined = (p['joined_selected'] as int? ?? 0) > 0;
          final linked = p['linked_user_id'] != null;
          return Card(margin: const EdgeInsets.only(bottom: 8), child: Column(children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(p['name'] as String? ?? 'Participant', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${p['phone'] ?? 'No phone'} · ${p['quiz_count'] ?? 0} quizzes · ${linked ? 'Regular user' : 'Quiz-only'}'),
              trailing: selectedQuizId == null ? null : Checkbox(value: joined, onChanged: (v) async {
                await QuizDatabase.instance.setParticipated(quizId: selectedQuizId!, participantId: p['id'] as int, participated: v ?? false);
                await refresh();
              }),
            ),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: () async {
                final id = await ensureRegularUser(p);
                if (id != null && mounted) await widget.onAddBonus(id);
                await refresh();
              },
              icon: const Icon(Icons.card_giftcard), label: Text(linked ? 'Add bonus' : 'Convert & add bonus'),
            )),
          ]));
        }).toList());
      }),
      const SizedBox(height: 8),
      const Text('Quiz-only participants do not create DP records. To use your existing Bonus function, convert the participant to a regular user first. This creates a user profile only — no DP is added.', style: TextStyle(color: Color(0xFF7C8490), fontSize: 12)),
    ]),
  );
}

String formatQuizDate(DateTime d) {
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  return '$day/$month/${d.year}';
}
