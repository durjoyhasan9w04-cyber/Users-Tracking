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
    participants = selectedQuizId == null ? Future.value(const <Map<String, Object?>>[]) : QuizDatabase.instance.getParticipantsForQuiz(quizId: selectedQuizId!, search: search.text);
    if (mounted) setState(() {});
  }
  void loadParticipants() {
    participants = selectedQuizId == null ? Future.value(const <Map<String, Object?>>[]) : QuizDatabase.instance.getParticipantsForQuiz(quizId: selectedQuizId!, search: search.text);
    if (mounted) setState(() {});
  }
  Future<void> refresh() async {
    quizzes = QuizDatabase.instance.getQuizzes();
    participants = selectedQuizId == null ? Future.value(const <Map<String, Object?>>[]) : QuizDatabase.instance.getParticipantsForQuiz(quizId: selectedQuizId!, search: search.text);
    if (mounted) setState(() {});
  }


  Future<void> deleteSelectedQuiz() async {
    final id = selectedQuizId;
    if (id == null) return;
    final rows = await QuizDatabase.instance.getQuizzes();
    Map<String, Object?>? quiz;
    for (final row in rows) { if (row['id'] == id) quiz = row; }
    final selectedQuiz = quiz;
    if (selectedQuiz == null || !mounted) return;
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete this quiz?'),
      content: Text('Delete “${selectedQuiz['title']}” and its participation records? Participants and their bonus/user records will remain. This cannot be undone.'),
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
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number (required)', hintText: 'Used to link or convert this participant')),
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
        final participantId = await QuizDatabase.instance.addParticipant(
          name: name.text, phone: cleanPhone, notes: notes.text, linkedUserId: linked,
        );
        final quizId = selectedQuizId;
        if (quizId != null) {
          await QuizDatabase.instance.setParticipated(
            quizId: quizId, participantId: participantId, participated: true,
          );
        }
        await refresh();
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add participant. This phone may already be in the quiz list.')));
      }
    }
    name.dispose(); phone.dispose(); notes.dispose();
  }

  Future<void> addExistingParticipant() async {
    final quizId = selectedQuizId;
    if (quizId == null) return;
    final all = await QuizDatabase.instance.getParticipants();
    final joined = await QuizDatabase.instance.getParticipantsForQuiz(quizId: quizId);
    final joinedIds = joined.map((p) => p['id']).toSet();
    final available = all.where((p) => !joinedIds.contains(p['id'])).toList();
    if (!mounted) return;
    final query = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) {
        final term = query.text.trim().toLowerCase();
        final filtered = available.where((p) =>
          '${p['name']} ${p['phone']}'.toLowerCase().contains(term)).toList();
        return AlertDialog(
          title: const Text('Add existing participant'),
          content: SizedBox(
            width: 420,
            height: 360,
            child: Column(children: [
              TextField(
                controller: query,
                onChanged: (_) => setDialog(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search name or phone',
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: filtered.isEmpty
                ? const Center(child: Text('No available participants.'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                        title: Text(p['name']?.toString() ?? 'Participant'),
                        subtitle: Text(p['phone']?.toString().isNotEmpty == true
                          ? p['phone'].toString() : 'No phone number'),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () async {
                          await QuizDatabase.instance.setParticipated(
                            quizId: quizId,
                            participantId: p['id'] as int,
                            participated: true,
                          );
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        },
                      );
                    },
                  )),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Close'))],
        );
      }),
    );
    query.dispose();
    if (added == true) await refresh();
  }

  Future<void> editParticipant(Map<String, Object?> participant) async {
    final name = TextEditingController(text: participant['name']?.toString() ?? '');
    final phone = TextEditingController(text: participant['phone']?.toString() ?? '');
    final notes = TextEditingController(text: participant['notes']?.toString() ?? '');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Edit quiz participant'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number')),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          if (name.text.trim().isEmpty || (phone.text.trim().isNotEmpty && phone.text.trim().length < 5)) {
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter a name and a valid phone number.')));
            return;
          }
          Navigator.pop(ctx, true);
        }, child: const Text('Save changes')),
      ],
    ));
    if (ok == true) {
      try {
        await QuizDatabase.instance.updateParticipant(
          id: participant['id'] as int,
          name: name.text.trim(), phone: phone.text.trim(), notes: notes.text.trim(),
        );
        await refresh();
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update participant. This phone number may already be used.')));
      }
    }
    name.dispose(); phone.dispose(); notes.dispose();
  }

  Future<void> deleteParticipant(Map<String, Object?> participant) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete participant?'),
      content: Text('Delete "${participant['name']}"? Their quiz participation and quiz-only bonus records will also be deleted. Any linked regular user profile will remain unchanged. This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
      ],
    ));
    if (confirmed != true) return;
    try {
      await QuizDatabase.instance.deleteParticipant(participant['id'] as int);
      await refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete participant.')));
    }
  }

  Future<void> addParticipantBonus(Map<String, Object?> participant) async {
    final users = await AppDatabase.instance.getUsers();
    final allParticipants = await QuizDatabase.instance.getParticipants();
    if (!mounted) return;
    final amount = TextEditingController();
    final relatedDp = TextEditingController();
    final notes = TextEditingController();
    final recipientSearchController = TextEditingController();
    String reason = 'Deposit';
    String ownerType = 'User';
    String recipientSearch = '';
    int? selectedUserId = users.isEmpty ? null : users.first['id'] as int;
    int? selectedParticipantId = participant['id'] as int;
    bool saving = false;
    final saved = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDialog) {
      final filteredUsers = users.where((u) =>
        '${u['name']} ${u['phone']}'.toLowerCase().contains(recipientSearch.toLowerCase())).toList();
      final filteredParticipants = allParticipants.where((p) =>
        '${p['name']} ${p['phone']}'.toLowerCase().contains(recipientSearch.toLowerCase())).toList();
      return AlertDialog(
        title: const Text('Add bonus'),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Award bonus to', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7C8490))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              ChoiceChip(label: const Text('Users'), selected: ownerType == 'User',
                onSelected: saving ? null : (_) => setDialog(() { ownerType = 'User'; recipientSearch = ''; recipientSearchController.clear(); })),
              ChoiceChip(label: const Text('Quiz Participants'), selected: ownerType == 'Quiz participant',
                onSelected: saving ? null : (_) => setDialog(() { ownerType = 'Quiz participant'; recipientSearch = ''; recipientSearchController.clear(); })),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: recipientSearchController,
              onChanged: (v) => setDialog(() => recipientSearch = v),
              decoration: InputDecoration(
                labelText: ownerType == 'User' ? 'Search user by name or number' : 'Search quiz participant by name or number',
                prefixIcon: const Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            if (ownerType == 'User') ...[
              if (filteredUsers.isEmpty)
                const Text('No matching users.')
              else
                DropdownButtonFormField<int>(
                  value: filteredUsers.any((u) => u['id'] == selectedUserId) ? selectedUserId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'User'),
                  items: filteredUsers.map((u) => DropdownMenuItem<int>(
                    value: u['id'] as int,
                    child: Text('${u['name']} · ${u['phone']}', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: saving ? null : (v) => setDialog(() => selectedUserId = v),
                ),
            ] else ...[
              if (filteredParticipants.isEmpty)
                const Text('No matching quiz participants. Add one from Track Quiz first.')
              else
                DropdownButtonFormField<int>(
                  value: filteredParticipants.any((p) => p['id'] == selectedParticipantId) ? selectedParticipantId : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Quiz participant'),
                  items: filteredParticipants.map((p) => DropdownMenuItem<int>(
                    value: p['id'] as int,
                    child: Text('${p['name']} · ${p['phone'] ?? 'No phone'}', overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: saving ? null : (v) => setDialog(() => selectedParticipantId = v),
                ),
            ],
            const SizedBox(height: 12),
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Bonus amount (coins)')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: reason,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: const ['Deposit', 'Special', 'Promotional', 'Other'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: saving ? null : (v) => setDialog(() => reason = v ?? 'Other'),
            ),
            const SizedBox(height: 10),
            TextField(controller: relatedDp, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Related DP (optional)')),
            const SizedBox(height: 10),
            TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optional)')),
          ],
        ))),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: saving ? null : () async {
            final value = double.tryParse(amount.text.trim());
            final dp = relatedDp.text.trim().isEmpty ? null : double.tryParse(relatedDp.text.trim());
            if (value == null || !value.isFinite || value <= 0 ||
                (relatedDp.text.trim().isNotEmpty && (dp == null || !dp.isFinite || dp < 0)) ||
                (ownerType == 'User' && selectedUserId == null) ||
                (ownerType == 'Quiz participant' && selectedParticipantId == null)) {
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Select a recipient and enter a valid bonus amount.')));
              return;
            }
            setDialog(() => saving = true);
            try {
              if (ownerType == 'User') {
                await AppDatabase.instance.addBonusEntry(
                  userId: selectedUserId!, date: DateTime.now(), amount: value,
                  reason: reason, relatedDp: dp, notes: notes.text,
                );
              } else {
                await QuizDatabase.instance.addQuizBonus(
                  participantId: selectedParticipantId!, date: DateTime.now(), amount: value,
                  reason: reason, relatedDp: dp, notes: notes.text,
                );
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (_) {
              if (ctx.mounted) {
                setDialog(() => saving = false);
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Could not save this bonus.')));
              }
            }
          }, child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save bonus')),
        ],
      );
    }));
    amount.dispose();
    relatedDp.dispose();
    notes.dispose();
    recipientSearchController.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bonus saved.')));
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
        Expanded(child: Text('Joined participants', style: Theme.of(context).textTheme.titleLarge)),
        OutlinedButton.icon(
          onPressed: selectedQuizId == null ? null : addExistingParticipant,
          icon: const Icon(Icons.person_search_outlined),
          label: const Text('Existing'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: addParticipant, icon: const Icon(Icons.person_add_alt_1), label: const Text('Add')),
      ]),
      const SizedBox(height: 8),
      TextField(controller: search, decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name or phone')),
      const SizedBox(height: 8),
      FutureBuilder<List<Map<String, Object?>>>(future: participants, builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
        final rows = snap.data ?? const [];
        if (rows.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('No one has joined this quiz yet. Add a participant to register them for this quiz.')));
        return Column(children: rows.map((p) {
          final linked = p['linked_user_id'] != null;
          return Card(margin: const EdgeInsets.only(bottom: 8), child: Column(children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(p['name'] as String? ?? 'Participant', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['phone'] ?? 'No phone'} · ${p['quiz_count'] ?? 0} quizzes · ${linked ? 'Regular user' : 'Quiz-only'}'),
                if (p['joined_at'] != null)
                  Text('Joined ${formatQuizJoinedAt(p['joined_at'].toString())}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7C8490))),
                if ((p['phone'] as String? ?? '').trim().isNotEmpty)
                  InkWell(
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: (p['phone'] as String).trim()));
                      if (!mounted) return;
                      messenger.showSnackBar(const SnackBar(content: Text('Phone number copied')));
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
              trailing: const Icon(Icons.check_circle, color: Color(0xFF3DDC97)),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              child: Wrap(alignment: WrapAlignment.end, spacing: 4, children: [
                TextButton.icon(
                  onPressed: () => editParticipant(p),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  onPressed: () => deleteParticipant(p),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                ),
                TextButton.icon(
                  onPressed: () => addParticipantBonus(p),
                  icon: const Icon(Icons.card_giftcard),
                  label: const Text('Add bonus'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final id = await ensureRegularUser(p);
                    if (id != null && mounted) {
                      messenger.showSnackBar(const SnackBar(content: Text('Participant converted to a regular user. No DP was added.')));
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

String formatQuizJoinedAt(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
  final minute = parsed.minute.toString().padLeft(2, '0');
  final period = parsed.hour >= 12 ? 'PM' : 'AM';
  return '$day/$month/${parsed.year} · $hour:$minute $period';
}
