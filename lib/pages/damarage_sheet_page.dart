import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../data/app_database.dart';
import '../data/quiz_database.dart';

class DamarageSheetPage extends StatefulWidget {
  const DamarageSheetPage({super.key});

  @override
  State<DamarageSheetPage> createState() => _DamarageSheetPageState();
}

class _DamarageSheetPageState extends State<DamarageSheetPage> {
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final superName = TextEditingController(text: 'জোভান খান');
  final agentName = TextEditingController();
  final agentId = TextEditingController();
  final wifiAmount = TextEditingController(text: '1000');
  final commissionAmount = TextEditingController();
  final companyCompensation = TextEditingController();
  final newSimNumbers = List.generate(3, (_) => TextEditingController());
  final customExpenses = <_ExpenseInput>[];
  final simLocks = <_SimLockInput>[_SimLockInput(number: '01')];

  List<_BonusLine> offlineRows = [];
  List<_BonusLine> quizRows = [];
  bool proofGiven = true;
  bool loading = true;
  bool saving = false;

  String get monthKey => DateFormat('yyyy-MM').format(selectedMonth);
  String get monthLabel => DateFormat('MMMM yyyy').format(selectedMonth);

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  @override
  void dispose() {
    superName.dispose();
    agentName.dispose();
    agentId.dispose();
    wifiAmount.dispose();
    commissionAmount.dispose();
    companyCompensation.dispose();
    for (final c in newSimNumbers) {
      c.dispose();
    }
    for (final e in customExpenses) {
      e.dispose();
    }
    for (final e in simLocks) {
      e.dispose();
    }
    super.dispose();
  }

  double _amount(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return 0;
    return double.tryParse(value) ?? 0;
  }

  bool _validAmount(TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isEmpty) return true;
    final parsed = double.tryParse(value);
    return parsed != null && parsed.isFinite && parsed >= 0;
  }

  String _formatAmount(num value) =>
      value.toStringAsFixed(value % 1 == 0 ? 0 : 2);

  double get offlineTotal =>
      offlineRows.fold(0, (sum, row) => sum + row.amount);
  double get quizTotal => quizRows.fold(0, (sum, row) => sum + row.amount);
  double get simLockTotal => simLocks.fold(
        0,
        (sum, row) =>
            sum + _amount(row.bkash) + _amount(row.nagad) + _amount(row.rocket),
      );
  double get otherExpensesTotal =>
      _amount(wifiAmount) +
      _amount(commissionAmount) +
      customExpenses.fold(0, (sum, row) => sum + _amount(row.amount));
  double get finalTotal => quizTotal + simLockTotal + otherExpensesTotal;

  Future<void> _loadMonth() async {
    setState(() => loading = true);
    try {
      final saved = await AppDatabase.instance.getDamarageSheet(monthKey);
      if (saved == null) {
        _resetManualFields();
      } else {
        superName.text = (saved['superName'] as String?) ?? 'জোভান খান';
        agentName.text = (saved['agentName'] as String?) ?? '';
        agentId.text = (saved['agentId'] as String?) ?? '';
        wifiAmount.text = (saved['wifiAmount'] ?? 1000).toString();
        commissionAmount.text = (saved['commissionAmount'] ?? '').toString();
        companyCompensation.text =
            (saved['companyCompensation'] ?? '').toString();
        proofGiven = saved['proofGiven'] != false;

        final savedExpenses = saved['customExpenses'];
        for (final row in customExpenses) {
          row.dispose();
        }
        customExpenses.clear();
        if (savedExpenses is List) {
          for (final item in savedExpenses.whereType<Map>()) {
            customExpenses.add(_ExpenseInput(
              name: item['name']?.toString() ?? '',
              amount: item['amount']?.toString() ?? '',
            ));
          }
        }

        final savedNumbers = saved['newSimNumbers'];
        for (var i = 0; i < newSimNumbers.length; i++) {
          newSimNumbers[i].text = savedNumbers is List && i < savedNumbers.length
              ? savedNumbers[i]?.toString() ?? ''
              : '';
        }

        final savedLocks = saved['simLocks'];
        for (final row in simLocks) {
          row.dispose();
        }
        simLocks.clear();
        if (savedLocks is List) {
          for (final item in savedLocks.whereType<Map>()) {
            simLocks.add(_SimLockInput(
              number: item['number']?.toString() ?? '',
              bkash: item['bkash']?.toString() ?? '',
              nagad: item['nagad']?.toString() ?? '',
              rocket: item['rocket']?.toString() ?? '',
            ));
          }
        }
        if (simLocks.isEmpty) simLocks.add(_SimLockInput(number: '01'));
      }

      final deposits = await AppDatabase.instance.getMonthlyBonusBreakdown(
        selectedMonth,
        reason: 'Deposit',
      );
      final specialUsers = await AppDatabase.instance.getMonthlyBonusBreakdown(
        selectedMonth,
        reason: 'Special',
      );
      final specialParticipants =
          await QuizDatabase.instance.getMonthlyQuizBonusBreakdown(
        selectedMonth,
        reason: 'Special',
      );

      offlineRows = deposits
          .map((row) => _BonusLine(
                id: row['user_id'].toString(),
                name: row['user_name']?.toString() ?? '',
                phone: row['user_phone']?.toString() ?? '',
                amount: (row['total_amount'] as num?)?.toDouble() ?? 0,
                count: (row['record_count'] as num?)?.toInt() ?? 0,
              ))
          .toList();

      quizRows = [
        ...specialUsers.map((row) => _BonusLine(
              id: row['user_id'].toString(),
              name: row['user_name']?.toString() ?? '',
              phone: row['user_phone']?.toString() ?? '',
              amount: (row['total_amount'] as num?)?.toDouble() ?? 0,
              count: (row['record_count'] as num?)?.toInt() ?? 0,
            )),
        ...specialParticipants.map((row) => _BonusLine(
              id: 'Q${row['participant_id']}',
              name: row['user_name']?.toString() ?? '',
              phone: row['user_phone']?.toString() ?? '',
              amount: (row['total_amount'] as num?)?.toDouble() ?? 0,
              count: (row['record_count'] as num?)?.toInt() ?? 0,
            )),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {
      if (mounted) {
        _message('Could not load this month’s sheet data.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _resetManualFields() {
    superName.text = 'জোভান খান';
    agentName.clear();
    agentId.clear();
    wifiAmount.text = '1000';
    commissionAmount.clear();
    companyCompensation.clear();
    proofGiven = true;
    for (final row in customExpenses) {
      row.dispose();
    }
    customExpenses.clear();
    for (final row in simLocks) {
      row.dispose();
    }
    simLocks
      ..clear()
      ..add(_SimLockInput(number: '01'));
    for (final controller in newSimNumbers) {
      controller.clear();
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  Map<String, Object?> _buildData() => {
        'superName': superName.text.trim(),
        'agentName': agentName.text.trim(),
        'agentId': agentId.text.trim(),
        'wifiAmount': _amount(wifiAmount),
        'commissionAmount': _amount(commissionAmount),
        'companyCompensation': _amount(companyCompensation),
        'proofGiven': proofGiven,
        'customExpenses': customExpenses
            .map((row) => {
                  'name': row.name.text.trim(),
                  'amount': _amount(row.amount),
                })
            .toList(),
        'newSimNumbers': newSimNumbers.map((c) => c.text.trim()).toList(),
        'simLocks': simLocks
            .map((row) => {
                  'number': row.number.text.trim(),
                  'bkash': _amount(row.bkash),
                  'nagad': _amount(row.nagad),
                  'rocket': _amount(row.rocket),
                })
            .toList(),
      };

  Future<bool> _save({bool showMessage = true}) async {
    final controllers = <TextEditingController>[
      wifiAmount,
      commissionAmount,
      companyCompensation,
      ...customExpenses.map((row) => row.amount),
      ...simLocks.expand((row) => [row.bkash, row.nagad, row.rocket]),
    ];
    if (controllers.any((controller) => !_validAmount(controller))) {
      _message('Enter valid non-negative amounts in all amount fields.');
      return false;
    }
    if (superName.text.trim().isEmpty || agentName.text.trim().isEmpty ||
        agentId.text.trim().isEmpty) {
      _message('Enter the super name, agent name and agent ID.');
      return false;
    }

    setState(() => saving = true);
    try {
      await AppDatabase.instance.saveDamarageSheet(
        monthKey: monthKey,
        data: _buildData(),
      );
      if (showMessage) _message('Damarage sheet saved for $monthLabel.');
      return true;
    } catch (_) {
      _message('Could not save the Damarage sheet.');
      return false;
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _chooseMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Choose any date in the month',
    );
    if (picked == null) return;
    setState(() => selectedMonth = DateTime(picked.year, picked.month));
    await _loadMonth();
  }

  Future<void> _generatePdf() async {
    if (saving) return;
    final saved = await _save(showMessage: false);
    if (!saved || !mounted) return;
    try {
      final pdf = pw.Document();
      final expenseRows = <List<String>>[
        ['WiFi bill', _formatAmount(_amount(wifiAmount))],
        ['Commission', _formatAmount(_amount(commissionAmount))],
        ...customExpenses.map((row) => [
              row.name.text.trim().isEmpty ? 'Other expense' : row.name.text.trim(),
              _formatAmount(_amount(row.amount)),
            ]),
      ];
      final lockRows = simLocks.map((row) {
        final total = _amount(row.bkash) + _amount(row.nagad) + _amount(row.rocket);
        return [
          row.number.text.trim(),
          _formatAmount(_amount(row.bkash)),
          _formatAmount(_amount(row.nagad)),
          _formatAmount(_amount(row.rocket)),
          _formatAmount(total),
        ];
      }).toList();

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text('DAMARAGE SHEET',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text('Month: $monthLabel'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Super name', 'Agent name', 'Agent ID'],
            data: [[superName.text.trim(), agentName.text.trim(), agentId.text.trim()]],
          ),
          pw.SizedBox(height: 16),
          pw.Text('OFFLINE COINS (USER DEPOSIT BONUSES)',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _pdfBonusTable(offlineRows),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Offline coins total: ${_formatAmount(offlineTotal)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 14),
          pw.Text('QUIZ MONEY (SPECIAL BONUSES)',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _pdfBonusTable(quizRows),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Quiz total: ${_formatAmount(quizTotal)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 14),
          pw.Text('OTHER EXPENSES',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Expense', 'Coins'],
            data: expenseRows,
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Other expenses total: ${_formatAmount(otherExpensesTotal)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 14),
          pw.Text('NEW SIM NUMBERS',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Text(newSimNumbers.asMap().entries
              .map((entry) => '${entry.key + 1}. ${entry.value.text.trim()}')
              .join('     ')),
          pw.SizedBox(height: 14),
          pw.Text('SIM LOCK DETAILS',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['Number', 'Bkash', 'Nagad', 'Rocket', 'Total'],
            data: lockRows.isEmpty ? [['-', '0', '0', '0', '0']] : lockRows,
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('SIM lock total: ${_formatAmount(simLockTotal)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 14),
          pw.Text('Proof given to super: ${proofGiven ? 'YES' : 'NO'}'),
          pw.Text('Company SIM compensation: ${_formatAmount(_amount(companyCompensation))}'),
          pw.Divider(),
          pw.Text(
            'GRAND TOTAL = QUIZ + SIM LOCK + OTHER EXPENSES = ${_formatAmount(finalTotal)} COINS',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Offline coins are listed separately and are not included in the grand total.',
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ));

      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/damarage-sheet-${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}.pdf',
      );
      await file.writeAsBytes(await pdf.save(), flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: 'Damarage sheet · $monthLabel',
      ));
    } catch (_) {
      _message('Could not generate the PDF. Please try again.');
    }
  }

  pw.Widget _pdfBonusTable(List<_BonusLine> rows) {
    return pw.TableHelper.fromTextArray(
      headers: ['ID', 'Name', 'WhatsApp', 'Coins'],
      data: rows.isEmpty
          ? [['-', 'No records', '-', '0']]
          : rows
              .map((row) => [
                    row.id,
                    row.name,
                    row.phone,
                    _formatAmount(row.amount),
                  ])
              .toList(),
    );
  }

  Widget _sectionTitle(String title, String subtitle) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7C8490))),
        ]),
      );

  Widget _card({required Widget child}) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      );

  Widget _amountField(String label, TextEditingController controller,
          {String? hint}) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, hintText: hint),
      );

  Widget _bonusSection(String title, String subtitle, List<_BonusLine> rows,
      double total, {required bool offline}) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(title, subtitle),
        Row(children: [
          Expanded(
            child: Text(
              '${rows.length} users/participants · ${_formatAmount(total)} coins',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE9782A)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const Text('No matching bonus records for this month.',
              style: TextStyle(color: Color(0xFF7C8490)))
        else
          ...rows.map((row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: const Color(0xFFFFF0E7),
                    child: Text(row.id.length > 3 ? row.id.substring(0, 3) : row.id,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFE9782A))),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(row.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${row.id} · ${row.phone.isEmpty ? 'No phone' : row.phone}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF7C8490))),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Copy phone number',
                    visualDensity: VisualDensity.compact,
                    onPressed: row.phone.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: row.phone));
                            _message('Phone number copied.');
                          },
                    icon: const Icon(Icons.copy_rounded, size: 17),
                  ),
                  Text(_formatAmount(row.amount),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              )),
        const Divider(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Section total', style: TextStyle(fontWeight: FontWeight.w700)),
          Text('${_formatAmount(total)} coins',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Damarage Sheet Generator')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Damarage Sheet Generator'),
        actions: [
          IconButton(
            tooltip: 'Reload month data',
            onPressed: _loadMonth,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('Sheet month', 'Each month has its own saved sheet.'),
              OutlinedButton.icon(
                onPressed: _chooseMonth,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(monthLabel),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: superName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Super name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: agentName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Agent name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: agentId,
                decoration: const InputDecoration(labelText: 'Agent ID'),
              ),
            ]),
          ),
          _bonusSection(
            'Offline Coins',
            'Only regular-user bonus records marked Deposit in $monthLabel. Grouped by user.',
            offlineRows,
            offlineTotal,
            offline: true,
          ),
          _bonusSection(
            'Quiz Money',
            'Special bonus records for regular users and quiz participants in $monthLabel.',
            quizRows,
            quizTotal,
            offline: false,
          ),
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('Other expenses', 'WiFi starts at 1,000 coins. Edit it whenever needed.'),
              _amountField('WiFi bill (coins)', wifiAmount),
              const SizedBox(height: 10),
              _amountField('Commission (coins)', commissionAmount),
              const SizedBox(height: 12),
              ...customExpenses.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: entry.value.name,
                          decoration: InputDecoration(labelText: 'Expense ${entry.key + 1}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _amountField('Coins', entry.value.amount),
                      ),
                      IconButton(
                        tooltip: 'Remove expense',
                        onPressed: () => setState(() {
                          entry.value.dispose();
                          customExpenses.removeAt(entry.key);
                        }),
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                      ),
                    ]),
                  )),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => customExpenses.add(_ExpenseInput())),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add another expense'),
                ),
              ),
              const Divider(),
              _totalLine('Other expenses total', otherExpensesTotal),
            ]),
          ),
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('New SIM numbers', 'Add up to three new SIM numbers.'),
              Row(children: List.generate(3, (index) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
                  child: TextField(
                    controller: newSimNumbers[index],
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: 'SIM ${index + 1}'),
                  ),
                ),
              ))),
            ]),
          ),
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('SIM lock details', 'Add one or more locked SIM records.'),
              ...simLocks.asMap().entries.map((entry) {
                final row = entry.value;
                final total = _amount(row.bkash) + _amount(row.nagad) + _amount(row.rocket);
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9EBEF)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: row.number,
                          decoration: const InputDecoration(labelText: 'SIM / phone number'),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove SIM lock entry',
                        onPressed: simLocks.length == 1 ? null : () => setState(() {
                          row.dispose();
                          simLocks.removeAt(entry.key);
                        }),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      ),
                    ]),
                    const SizedBox(height: 9),
                    Row(children: [
                      Expanded(child: _amountField('Bkash balance', row.bkash)),
                      const SizedBox(width: 8),
                      Expanded(child: _amountField('Nagad balance', row.nagad)),
                    ]),
                    const SizedBox(height: 9),
                    _amountField('Rocket balance', row.rocket),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('SIM total: ${_formatAmount(total)} coins',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ]),
                );
              }),
              TextButton.icon(
                onPressed: () => setState(() => simLocks.add(
                    _SimLockInput(number: (simLocks.length + 1).toString().padLeft(2, '0')))),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add another SIM lock'),
              ),
              _totalLine('Total SIM lock', simLockTotal),
            ]),
          ),
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('Proof and compensation', 'These details are shown separately in the PDF.'),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Proof given to super'),
                subtitle: Text(proofGiven ? 'Yes' : 'No'),
                value: proofGiven,
                onChanged: (value) => setState(() => proofGiven = value),
              ),
              const SizedBox(height: 8),
              _amountField('Company SIM compensation (coins)', companyCompensation),
              const SizedBox(height: 6),
              const Text('Company compensation is displayed separately and is not deducted from the grand total.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF7C8490))),
            ]),
          ),
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Grand total',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(
                'Quiz + SIM lock + Other expenses',
                style: const TextStyle(color: Color(0xFF7C8490), fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text('${_formatAmount(finalTotal)} coins',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFE9782A))),
              const SizedBox(height: 5),
              Text('Offline coins: ${_formatAmount(offlineTotal)} coins (not included)',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7C8490))),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: saving ? null : _save,
                icon: saving
                    ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: const Text('Save this month’s sheet'),
              ),
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: saving ? null : _generatePdf,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Save and generate PDF'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, double total) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${_formatAmount(total)} coins',
              style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
      );
}

class _BonusLine {
  const _BonusLine({
    required this.id,
    required this.name,
    required this.phone,
    required this.amount,
    required this.count,
  });

  final String id;
  final String name;
  final String phone;
  final double amount;
  final int count;
}

class _ExpenseInput {
  _ExpenseInput({String name = '', String amount = ''})
      : name = TextEditingController(text: name),
        amount = TextEditingController(text: amount);

  final TextEditingController name;
  final TextEditingController amount;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

class _SimLockInput {
  _SimLockInput({
    String number = '',
    String bkash = '',
    String nagad = '',
    String rocket = '',
  })  : number = TextEditingController(text: number),
        bkash = TextEditingController(text: bkash),
        nagad = TextEditingController(text: nagad),
        rocket = TextEditingController(text: rocket);

  final TextEditingController number;
  final TextEditingController bkash;
  final TextEditingController nagad;
  final TextEditingController rocket;

  void dispose() {
    number.dispose();
    bkash.dispose();
    nagad.dispose();
    rocket.dispose();
  }
}
