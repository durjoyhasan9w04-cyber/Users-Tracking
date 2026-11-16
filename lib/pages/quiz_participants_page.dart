// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/app_database.dart';
import '../data/quiz_database.dart';

class QuizParticipantsPage extends StatefulWidget {
  const QuizParticipantsPage({super.key});
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


  Future<void> deleteSelectedQuiz() async {
    final id = selectedQuizId;
    if (id == null) return;
    final rows = await QuizDatabase.instance.getQuizzes();
    Map<String, Object?>? quiz;
    for (final row in rows) { if (row['id'] == id) quiz = row; }
    if (quiz == null || !mounted) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete this quiz?'),
      content: Text('Delete “${quiz['title']}” and its participation records? Participants and their bonus/user records will remain. This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete quiz')),
      ],
    ));
    if (confirmed != true) return;
    await QuizDatabase.instance.deleteQuiz(id);
    selectedQuizId = null;
    await refresh();
    await _loadInitialData();
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
        FilledButton(onPressed: () {
          if (name.text.trim().isEmpty || phone.text.trim().length < 5) {
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter a name and valid phone number.')));
            return;
          }
          Navigator.pop(ctx, true);
        }, child: const Text('Save'))],
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

  Future<void> addParticipantBonus(Map<String, Object?> participant) async {
    final amount = TextEditingController();
    final relatedDp = TextEditingController();
    final notes = TextEditingController();
    String reason = 'Deposit';
    bool saving = false;
    final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) => AlertDialog(
      title: Text('Bonus · ${participant['name']}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Quiz participant · ${participant['phone'] ?? ''}', style: const TextStyle(color: Color(0xFF7C8490), fontSize: 12)),
        const SizedBox(height: 12),
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Bonus amount (coins)')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: reason,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Reason'),
          items: const ['Deposit', 'Special', 'Promotional', 'Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: saving ? null : (v) => setDialog(() => reason = v ?? 'Other'),
        ),
        const SizedBox(height: 10),
        TextField(controller: relatedDp, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Related DP (optional)')),
        const SizedBox(height: 10),
        TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
      ])),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: saving ? null : () async {
          final value = double.tryParse(amount.text.trim());
          final dp = relatedDp.text.trim().isEmpty ? null : double.tryParse(relatedDp.text.trim());
          if (value == null || !value.isFinite || value <= 0 || (relatedDp.text.trim().isNotEmpty && (dp == null || !dp.isFinite || dp < 0))) {
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter a valid bonus amount and related DP.')));
            return;
          }
          setDialog(() => saving = true);
          try {
            await QuizDatabase.instance.addQuizBonus(
              participantId: participant['id'] as int,
              date: DateTime.now(), amount: value, reason: reason,
              relatedDp: dp, notes: notes.text,
            );
            if (ctx.mounted) Navigator.pop(ctx, true);
          } catch (_) {
            if (ctx.mounted) {
              setDialog(() => saving = false);
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Could not save this quiz bonus.')));
            }
          }
        }, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save bonus')),
      ],
    )));
    amount.dispose(); relatedDp.dispose(); notes.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quiz participant bonus saved.')));
      await refresh();
    }
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
    final fullName = TextEditingController(text: p['name'] as String? ?? '');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Convert to regular user'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Enter the participant’s full name for the new Users profile. No DP record will be created.'),
        const SizedBox(height: 12),
        TextField(controller: fullName, textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'New full name', hintText: 'Enter full name')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          if (fullName.text.trim().isEmpty) {
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter the full name first.')));
            return;
          }
          Navigator.pop(ctx, true);
        }, child: const Text('Convert'))],
    ));
    if (ok != true || fullName.text.trim().isEmpty) { fullName.dispose(); return null; }
    try {
      final id = await AppDatabase.instance.addUser(
        name: fullName.text.trim(), phone: phone,
        notes: 'Converted from Quiz Participants. ${p['notes'] ?? ''}'.trim(),
      );
      await QuizDatabase.instance.linkRegularUser(p['id'] as int, id);
      return id;
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not convert. This phone may already exist in Users or Potential users.')));
      return null;
    } finally {
      fullName.dispose();
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
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(child: DropdownButtonFormField<int>(
          initialValue: current,
          decoration: const InputDecoration(hintText: 'Select quiz', floatingLabelBehavior: FloatingLabelBehavior.never),
          items: rows.map((r) => DropdownMenuItem<int>(value: r['id'] as int, child: Text('${r['title']} · ${r['participant_count']} joined', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { selectedQuizId = v; loadParticipants(); },
        )),
          IconButton(
            tooltip: 'Delete selected quiz',
            onPressed: deleteSelectedQuiz,
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          ),
        ]);
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
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['phone'] ?? 'No phone'} · ${p['quiz_count'] ?? 0} quizzes · ${linked ? 'Regular user' : 'Quiz-only'}'),
                if ((p['phone'] as String? ?? '').trim().isNotEmpty)
                  InkWell(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: (p['phone'] as String).trim()));
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number copied')));
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.copy, size: 14, color: Color(0xFFE9782A)),
                        SizedBox(width: 5),
                        Text('Copy phone number', style: TextStyle(fontSize: 12, color: Color(0xFFE9782A), fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ]),
              trailing: selectedQuizId == null ? null : Checkbox(value: joined, onChanged: (v) async {
                await QuizDatabase.instance.setParticipated(quizId: selectedQuizId!, participantId: p['id'] as int, participated: v ?? false);
                await refresh();
              }),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              child: Wrap(alignment: WrapAlignment.end, spacing: 4, children: [
                TextButton.icon(
                  onPressed: () => addParticipantBonus(p),
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('Add bonus'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final id = await ensureRegularUser(p);
                    if (id != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Participant converted to a regular user. No DP was added.')));
                      await refresh();
                    }
                  },
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Convert to user'),
                ),
              ]),
            ),
          ]));
        }).toList());
      }),
      const SizedBox(height: 8),
      const Text('Quiz-only participants can receive bonuses directly. Their bonus records are kept in the separate quiz database and do not create a Users profile or DP record.', style: TextStyle(color: Color(0xFF7C8490), fontSize: 12)),
    ]),
  );
}

String formatQuizDate(DateTime d) {
  final day = d.day.toString().padLeft(2, '0');
  final month = d.month.toString().padLeft(2, '0');
  return '$day/$month/${d.year}';
}
