// ignore_for_file: deprecated_member_use
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
  final manualGrandTotal = TextEditingController();
  String wifiUnit = 'টাকা';
  String commissionUnit = 'টাকা';
  bool useManualGrandTotal = false;
  final newSimNumbers = List.generate(3, (_) => TextEditingController());
  final customExpenses = <_ExpenseInput>[];
  final simLocks = <_SimLockInput>[_SimLockInput(number: '01')];

  List<_BonusLine> offlineRows = [];
  List<_BonusLine> quizRows = [];
  bool proofGiven = true;
  bool loading = true;
  bool saving = false;

  String get monthKey => DateFormat('yyyy-MM').format(selectedMonth);
  String get monthLabel => '${_bnMonths[selectedMonth.month - 1]} ${_bnDigits(selectedMonth.year)}';
  static const _bnMonths = ['জানুয়ারি','ফেব্রুয়ারি','মার্চ','এপ্রিল','মে','জুন','জুলাই','আগস্ট','সেপ্টেম্বর','অক্টোবর','নভেম্বর','ডিসেম্বর'];
  String _bnDigits(Object value) => value.toString().replaceAll('0','০').replaceAll('1','১').replaceAll('2','২').replaceAll('3','৩').replaceAll('4','৪').replaceAll('5','৫').replaceAll('6','৬').replaceAll('7','৭').replaceAll('8','৮').replaceAll('9','৯');
  double _toTaka(double amount, String unit) => unit == 'কয়েন' ? amount * 100 : amount;
  String get displayGrandTotal => _formatAmount(useManualGrandTotal ? _amount(manualGrandTotal) : finalTotal);

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
    manualGrandTotal.dispose();
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
  double get otherExpensesTotal => _toTaka(_amount(wifiAmount), wifiUnit) + _toTaka(_amount(commissionAmount), commissionUnit) + customExpenses.fold(0, (sum, row) => sum + _toTaka(_amount(row.amount), row.unit));
  double get finalTotal => quizTotal * 100 + simLockTotal + otherExpensesTotal;

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
        companyCompensation.text = (saved['companyCompensation'] ?? '').toString();
        wifiUnit = saved['wifiUnit']?.toString() ?? 'টাকা';
        commissionUnit = saved['commissionUnit']?.toString() ?? 'টাকা';
        useManualGrandTotal = saved['useManualGrandTotal'] == true;
        manualGrandTotal.text = (saved['manualGrandTotal'] ?? '').toString();
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
              unit: item['unit']?.toString() ?? 'টাকা',
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
              ))
          .toList();

      quizRows = [
        ...specialUsers.map((row) => _BonusLine(
              id: row['user_id'].toString(),
              name: row['user_name']?.toString() ?? '',
              phone: row['user_phone']?.toString() ?? '',
              amount: (row['total_amount'] as num?)?.toDouble() ?? 0,
            )),
        ...specialParticipants.map((row) => _BonusLine(
              id: 'Q${row['participant_id']}',
              name: row['user_name']?.toString() ?? '',
              phone: row['user_phone']?.toString() ?? '',
              amount: (row['total_amount'] as num?)?.toDouble() ?? 0,
            )),
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {
      if (mounted) {
        _message('এই মাসের হিসাব লোড করা যায়নি।');
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
    manualGrandTotal.clear();
    wifiUnit = 'টাকা';
    commissionUnit = 'টাকা';
    useManualGrandTotal = false;
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
        'wifiUnit': wifiUnit,
        'commissionUnit': commissionUnit,
        'useManualGrandTotal': useManualGrandTotal,
        'manualGrandTotal': _amount(manualGrandTotal),
        'proofGiven': proofGiven,
        'customExpenses': customExpenses
            .map((row) => {
                  'name': row.name.text.trim(),
                  'amount': _amount(row.amount),
                  'unit': row.unit,
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
      manualGrandTotal,
      ...customExpenses.map((row) => row.amount),
      ...simLocks.expand((row) => [row.bkash, row.nagad, row.rocket]),
    ];
    if (useManualGrandTotal && manualGrandTotal.text.trim().isEmpty) {
      _message('নিজে মোট লিখলে পরিমাণ দিতে হবে।');
      return false;
    }
    if (controllers.any((controller) => !_validAmount(controller))) {
      _message('সব টাকার ঘরে সঠিক শূন্য বা তার বেশি পরিমাণ লিখুন।');
      return false;
    }
    if (superName.text.trim().isEmpty || agentName.text.trim().isEmpty ||
        agentId.text.trim().isEmpty) {
      _message('সুপারের নাম, এজেন্টের নাম ও এজেন্ট আইডি লিখুন।');
      return false;
    }

    setState(() => saving = true);
    try {
      await AppDatabase.instance.saveDamarageSheet(
        monthKey: monthKey,
        data: _buildData(),
      );
      if (showMessage) _message('$monthLabel মাসের হিসাব সংরক্ষণ হয়েছে।');
      return true;
    } catch (_) {
      _message('হিসাব সংরক্ষণ করা যায়নি।');
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
        ['ওয়াইফাই বিল', '${_formatAmount(_amount(wifiAmount))} $wifiUnit'],
        ['কমিশন', '${_formatAmount(_amount(commissionAmount))} $commissionUnit'],
        ...customExpenses.map((row) => [
              row.name.text.trim().isEmpty ? 'অন্যান্য খরচ' : row.name.text.trim(),
              '${_formatAmount(_amount(row.amount))} ${row.unit}',
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
          pw.Text('ডেমারেজের বিস্তারিত হিসাব',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Text('মাস: $monthLabel'),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['সুপারের নাম', 'এজেন্টের নাম', 'এজেন্ট আইডি'],
            data: [[superName.text.trim(), agentName.text.trim(), agentId.text.trim()]],
          ),
          pw.SizedBox(height: 16),
          pw.Text('অফলাইন থেকে কয়েন দিতে বলা হলে',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _pdfBonusTable(offlineRows),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('মোট কয়েন: ${_formatAmount(offlineTotal)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 14),
          pw.Text('কুইজের টাকার হিসাব',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _pdfBonusTable(quizRows),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('মোট কয়েন: ${_formatAmount(quizTotal)}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 14),
          pw.Text('অন্যান্য খরচ হিসাব',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['খরচের বিবরণ', 'পরিমাণ'],
            data: expenseRows,
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('অন্যান্য খরচের মোট: ${_formatAmount(otherExpensesTotal)} টাকা',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 14),
          pw.Text('নতুন সিমের নাম্বার',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.Text(newSimNumbers.asMap().entries
              .map((entry) => '${entry.key + 1}. ${entry.value.text.trim()}')
              .join('     ')),
          pw.SizedBox(height: 14),
          pw.Text('সিম লকের বিস্তারিত হিসাব',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['নাম্বার', 'বিকাশ', 'নগদ', 'রকেট', 'মোট (টাকা)'],
            data: lockRows.isEmpty ? [['-', '0', '0', '0', '0']] : lockRows,
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('সিম লকের মোট: ${_formatAmount(simLockTotal)} টাকা',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 14),
          pw.Text('প্রমাণ সুপারকে দেওয়া হয়েছে: ${proofGiven ? 'হ্যাঁ' : 'না'}'),
          pw.Text('কোম্পানি সিম ক্ষতিপূরণ: ${_formatAmount(_amount(companyCompensation))} টাকা'),
          pw.Divider(),
          pw.Text(
            'মোট= কুইজ+সিম লক+অন্যান্য খরচ = ${displayGrandTotal} টাকা',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('অফলাইন কয়েন আলাদাভাবে দেখানো হয়েছে; মোটের মধ্যে অন্তর্ভুক্ত নয়।',
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
        text: 'ডেমারেজের হিসাব · $monthLabel',
      ));
    } catch (_) {
      _message('PDF তৈরি করা যায়নি। আবার চেষ্টা করুন।');
    }
  }

  pw.Widget _pdfBonusTable(List<_BonusLine> rows) {
    return pw.TableHelper.fromTextArray(
      headers: ['আইডি', 'নাম', 'হোয়াটসঅ্যাপ', 'কয়েন'],
      data: rows.isEmpty
          ? [['-', 'কোনো তথ্য নেই', '-', '০']]
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
      double total) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle(title, subtitle),
        Row(children: [
          Expanded(
            child: Text(
              '${_bnDigits(rows.length)} জন · ${_formatAmount(total)} কয়েন',
              style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE9782A)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          const Text('এই মাসে কোনো বোনাস রেকর্ড পাওয়া যায়নি।',
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
                    tooltip: 'ফোন নাম্বার কপি করুন',
                    visualDensity: VisualDensity.compact,
                    onPressed: row.phone.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: row.phone));
                            _message('ফোন নাম্বার কপি হয়েছে।');
                          },
                    icon: const Icon(Icons.copy_rounded, size: 17),
                  ),
                  Text(_formatAmount(row.amount),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              )),
        const Divider(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('সর্বমোট', style: TextStyle(fontWeight: FontWeight.w700)),
          Text('${_formatAmount(total)} $unit',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('ডেমারেজ শিট তৈরি')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('ডেমারেজ শিট তৈরি'),
        actions: [
          IconButton(
            tooltip: 'তথ্য রিফ্রেশ করুন',
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
              _sectionTitle('মাস নির্বাচন', 'প্রতিটি মাসের হিসাব আলাদাভাবে সংরক্ষিত থাকবে।'),
              OutlinedButton.icon(
                onPressed: _chooseMonth,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(monthLabel),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: superName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'সুপারের নাম'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: agentName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'এজেন্টের নাম'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: agentId,
                decoration: const InputDecoration(labelText: 'এজেন্ট আইডি'),
              ),
            ]),
          ),
          _bonusSection(
            'অফলাইন থেকে কয়েন দিতে বলা হলে',
            '$monthLabel মাসের সাধারণ ইউজারের Deposit বোনাস থেকে হিসাব।',
            offlineRows,
            offlineTotal,
          ),
          _bonusSection(
            'কুইজের টাকার হিসাব',
            '$monthLabel মাসের Special বোনাসের হিসাব।',
            quizRows,
            quizTotal,
          ),
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('অন্যান্য খরচ হিসাব', 'প্রতিটি খরচ টাকা অথবা কয়েনে লিখুন।'),
              _amountField('ওয়াইফাই বিল', wifiAmount),
              DropdownButtonFormField<String>(value: wifiUnit, decoration: const InputDecoration(labelText: 'ওয়াইফাই বিলের একক'), items: const [DropdownMenuItem(value: 'টাকা', child: Text('টাকা')), DropdownMenuItem(value: 'কয়েন', child: Text('কয়েন'))], onChanged: (v) => setState(() => wifiUnit = v ?? 'টাকা')),
              const SizedBox(height: 10),
              _amountField('কমিশন', commissionAmount),
              DropdownButtonFormField<String>(value: commissionUnit, decoration: const InputDecoration(labelText: 'কমিশনের একক'), items: const [DropdownMenuItem(value: 'টাকা', child: Text('টাকা')), DropdownMenuItem(value: 'কয়েন', child: Text('কয়েন'))], onChanged: (v) => setState(() => commissionUnit = v ?? 'টাকা')),
              const SizedBox(height: 12),
              ...customExpenses.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: entry.value.name,
                          decoration: InputDecoration(labelText: 'খরচের বিবরণ ${_bnDigits(entry.key + 1)}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _amountField('পরিমাণ', entry.value.amount),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: entry.value.unit,
                          decoration: const InputDecoration(labelText: 'একক'),
                          items: const [DropdownMenuItem(value: 'টাকা', child: Text('টাকা')), DropdownMenuItem(value: 'কয়েন', child: Text('কয়েন'))],
                          onChanged: (v) => setState(() => entry.value.unit = v ?? 'টাকা'),
                        ),
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
                  label: const Text('আরও খরচ যোগ করুন'),
                ),
              ),
              const Divider(),
              _totalLine('অন্যান্য খরচের মোট', otherExpensesTotal, unit: 'টাকা'),
            ]),
          ),
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('নতুন সিমের নাম্বার', 'সর্বোচ্চ তিনটি নতুন সিমের নাম্বার লিখুন।'),
              Row(children: List.generate(3, (index) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
                  child: TextField(
                    controller: newSimNumbers[index],
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: 'সিম ${_bnDigits(index + 1)}'),
                  ),
                ),
              ))),
            ]),
          ),
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('সিম লকের বিস্তারিত হিসাব', 'এক বা একাধিক সিমের হিসাব যোগ করুন।'),
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
                          decoration: const InputDecoration(labelText: 'সিম / ফোন নাম্বার'),
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
                      Expanded(child: _amountField('বিকাশের ব্যালেন্স (টাকা)', row.bkash)),
                      const SizedBox(width: 8),
                      Expanded(child: _amountField('নগদের ব্যালেন্স (টাকা)', row.nagad)),
                    ]),
                    const SizedBox(height: 9),
                    _amountField('রকেটের ব্যালেন্স (টাকা)', row.rocket),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text('সিমের মোট: ${_formatAmount(total)} টাকা',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ]),
                );
              }),
              TextButton.icon(
                onPressed: () => setState(() => simLocks.add(
                    _SimLockInput(number: (simLocks.length + 1).toString().padLeft(2, '0')))),
                icon: const Icon(Icons.add_rounded),
                label: const Text('আরও সিম যোগ করুন'),
              ),
              _totalLine('সিম লকের মোট', simLockTotal, unit: 'টাকা'),
            ]),
          ),
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionTitle('প্রমাণ ও ক্ষতিপূরণ', 'এই তথ্যগুলো আলাদাভাবে দেখানো হবে।'),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('প্রমাণ সুপারকে দেওয়া হয়েছে'),
                subtitle: Text(proofGiven ? 'হ্যাঁ' : 'না'),
                value: proofGiven,
                onChanged: (value) => setState(() => proofGiven = value),
              ),
              const SizedBox(height: 8),
              _amountField('কোম্পানি সিম ক্ষতিপূরণ (টাকা)', companyCompensation),
              const SizedBox(height: 6),
              const Text('কোম্পানির ক্ষতিপূরণ আলাদাভাবে দেখানো হবে এবং মোটের সঙ্গে যোগ হবে না।',
                  style: TextStyle(fontSize: 12, color: Color(0xFF7C8490))),
            ]),
          ),
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('মোট= কুইজ+সিম লক+অন্যান্য খরচ =',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(
                '১ কয়েন = ১০০ টাকা · মোট টাকায় দেখানো হবে',
                style: const TextStyle(color: Color(0xFF7C8490), fontSize: 12),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, title: const Text('মোট নিজে লিখব'), value: useManualGrandTotal, onChanged: (v) => setState(() { useManualGrandTotal = v; if (!v) manualGrandTotal.text = _formatAmount(finalTotal); })),
              if (useManualGrandTotal) _amountField('নিজে নির্ধারণ করা মোট (টাকা)', manualGrandTotal),
              Text('${displayGrandTotal} টাকা',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFFE9782A))),
              const SizedBox(height: 5),
              Text('অফলাইন কয়েন: ${_formatAmount(offlineTotal)} (মোটে যোগ হবে না)',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF7C8490))),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: saving ? null : () => _save(),
                icon: saving
                    ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded),
                label: const Text('এই মাসের হিসাব সংরক্ষণ করুন'),
              ),
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: saving ? null : _generatePdf,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('PDF তৈরি ও শেয়ার করুন'),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, double total, {String unit = 'কয়েন'}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${_formatAmount(total)} $unit',
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
  });

  final String id;
  final String name;
  final String phone;
  final double amount;
}

class _ExpenseInput {
  _ExpenseInput({String name = '', String amount = '', this.unit = 'টাকা'})
      : name = TextEditingController(text: name),
        amount = TextEditingController(text: amount);

  final TextEditingController name;
  final TextEditingController amount;
  String unit;

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
