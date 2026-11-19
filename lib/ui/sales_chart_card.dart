import 'dart:math' as math;
import 'dart:ui' as ui;

// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum _SalesPeriod { weekly, monthly, yearly }

class SalesChartCard extends StatefulWidget {
  const SalesChartCard({
    super.key,
    required this.entries,
    this.loading = false,
  });

  /// Existing DP rows returned by AppDatabase.getDpEntries().
  /// This widget only reads them; it never writes to the database.
  final List<Map<String, Object?>> entries;
  final bool loading;

  @override
  State<SalesChartCard> createState() => _SalesChartCardState();
}

class _SalesChartCardState extends State<SalesChartCard>
    with SingleTickerProviderStateMixin {
  static const Color _orange = Color(0xFFFF7A3D);
  static const Color _green = Color(0xFF22C55E);
  static const Color _red = Color(0xFFEF4444);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);

  late final AnimationController _animation;
  _SalesPeriod _period = _SalesPeriod.monthly;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant SalesChartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entries.length != widget.entries.length ||
        oldWidget.loading != widget.loading) {
      _animation.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  double _amount(Map<String, Object?> row) =>
      (row['total'] as num?)?.toDouble() ?? 0;

  DateTime? _entryDate(Map<String, Object?> row) {
    final raw = row['entry_date'] as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  bool _inRange(DateTime date, DateTime start, DateTime endExclusive) =>
      !date.isBefore(start) && date.isBefore(endExclusive);

  double _sum(DateTime start, DateTime endExclusive) {
    var total = 0.0;
    for (final row in widget.entries) {
      final date = _entryDate(row);
      if (date != null && _inRange(date, start, endExclusive)) {
        total += _amount(row);
      }
    }
    return total;
  }

  _SalesChartData _chartData() {
    final today = _today;
    late List<String> labels;
    late List<String> dates;
    late List<double> values;
    late double currentTotal;
    late double previousTotal;

    switch (_period) {
      case _SalesPeriod.weekly:
        final start = today.subtract(const Duration(days: 6));
        labels = [];
        dates = [];
        values = [];
        for (var i = 0; i < 7; i++) {
          final day = start.add(Duration(days: i));
          final next = day.add(const Duration(days: 1));
          labels.add(DateFormat('EEE').format(day));
          dates.add(DateFormat('d MMM').format(day));
          values.add(_sum(day, next));
        }
        currentTotal = _sum(start, today.add(const Duration(days: 1)));
        final previousStart = start.subtract(const Duration(days: 7));
        previousTotal = _sum(previousStart, start);
        break;

      case _SalesPeriod.monthly:
        final start = DateTime(today.year, today.month);
        final nextMonth = DateTime(today.year, today.month + 1);
        final monthDays = DateUtils.getDaysInMonth(today.year, today.month);
        const ranges = <(int, int)>[
          (1, 3), (4, 6), (7, 9), (10, 12), (13, 15),
          (16, 18), (19, 21), (22, 25), (26, 28), (29, 31),
        ];
        labels = [];
        dates = [];
        values = [];
        for (final range in ranges) {
          final firstDay = range.$1;
          if (firstDay > monthDays) continue;
          final lastDay = range.$2 < monthDays ? range.$2 : monthDays;
          labels.add('$firstDay-${range.$2}');
          dates.add('$firstDay ${DateFormat('MMM').format(start)} – $lastDay ${DateFormat('MMM').format(start)}');
          values.add(_sum(
            DateTime(today.year, today.month, firstDay),
            DateTime(today.year, today.month, lastDay + 1),
          ));
        }
        currentTotal = _sum(start, nextMonth);
        final previousStart = DateTime(today.year, today.month - 1);
        previousTotal = _sum(previousStart, start);
        break;

      case _SalesPeriod.yearly:
        final start = DateTime(today.year);
        labels = [];
        dates = [];
        values = [];
        for (var month = 1; month <= 12; month++) {
          final monthStart = DateTime(today.year, month);
          final next = DateTime(today.year, month + 1);
          labels.add(DateFormat('MMM').format(monthStart));
          dates.add(DateFormat('MMMM yyyy').format(monthStart));
          values.add(_sum(monthStart, next));
        }
        currentTotal = _sum(start, DateTime(today.year + 1));
        previousTotal = _sum(DateTime(today.year - 1), start);
        break;
    }

    final maxValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    return _SalesChartData(
      labels: labels,
      dates: dates,
      values: values,
      dotIndexes: _dotIndexes(values.length),
      yMax: _niceMaximum(maxValue),
      currentTotal: currentTotal,
      previousTotal: previousTotal,
    );
  }

  List<int> _dotIndexes(int count) {
    if (count <= 0) return const [];
    if (count <= 7) return List<int>.generate(count, (i) => i);
    if (_period == _SalesPeriod.monthly) {
      return [0, 3, 5, 8, count - 1];
    }
    return [0, 3, 6, count - 1].where((i) => i < count).toList();
  }

  double _niceMaximum(double value) {
    if (value <= 0) return 0;
    final power = math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    final scaled = value / power;
    final step = scaled <= 1
        ? 1.0
        : scaled <= 2
            ? 2.0
            : scaled <= 5
                ? 5.0
                : 10.0;
    return step * power;
  }

  double? _change(_SalesChartData data) {
    if (data.previousTotal <= 0) return null;
    return ((data.currentTotal - data.previousTotal) /
            data.previousTotal) *
        100;
  }

  Future<void> _choosePeriod() async {
    final selected = await showModalBottomSheet<_SalesPeriod>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9DDE4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chart period',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final period in _SalesPeriod.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _periodLabel(period),
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: _period == period
                      ? const Icon(Icons.check_circle, color: _orange)
                      : const Icon(Icons.circle_outlined, color: _muted),
                  onTap: () => Navigator.pop(sheetContext, period),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != _period && mounted) {
      setState(() {
        _period = selected;
        _selectedIndex = 0;
      });
      _animation.forward(from: 0);
    }
  }

  static String _periodLabel(_SalesPeriod period) {
    switch (period) {
      case _SalesPeriod.weekly:
        return 'Weekly';
      case _SalesPeriod.monthly:
        return 'Monthly';
      case _SalesPeriod.yearly:
        return 'Yearly';
    }
  }

  String _money(num value) => '৳${NumberFormat('#,##0.##').format(value)}';

  @override
  Widget build(BuildContext context) {
    final data = _chartData();
    final change = _change(data);
    final hasRecords = data.values.any((value) => value > 0);

    if (data.values.isNotEmpty) {
      _selectedIndex = _selectedIndex.clamp(0, data.values.length - 1).toInt();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12111827),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Sales',
                style: TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (change != null) ...[
                const SizedBox(width: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: change >= 0
                        ? const Color(0xFFE8F8EE)
                        : const Color(0xFFFFECEC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        change >= 0
                            ? Icons.north_east_rounded
                            : Icons.south_east_rounded,
                        size: 13,
                        color: change >= 0 ? _green : _red,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${change >= 0 ? '+' : ''}${change.abs().toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: change >= 0 ? _green : _red,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _choosePeriod,
                icon: const Icon(Icons.calendar_month_outlined, size: 14),
                label: Text(_periodLabel(_period)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _muted,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFE3E6EC)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 190,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE8EAEE)),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.loading
                ? const Center(
                    child: SizedBox(
                      width: 110,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: _orange,
                        backgroundColor: Color(0xFFF0F1F4),
                      ),
                    ),
                  )
                : !hasRecords
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.show_chart_rounded,
                              color: Color(0xFFB8BEC8),
                              size: 28,
                            ),
                            SizedBox(height: 5),
                            Text(
                              'No data yet',
                              style: TextStyle(
                                color: _muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final size = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (details) {
                              final next = _nearestPoint(
                                details.localPosition,
                                size,
                                data.values,
                                data.yMax,
                              );
                              if (next != null && next != _selectedIndex) {
                                setState(() => _selectedIndex = next);
                              }
                            },
                            child: AnimatedBuilder(
                              animation: _animation,
                              builder: (context, _) => CustomPaint(
                                size: size,
                                painter: _SalesChartPainter(
                                  labels: data.labels,
                                  values: data.values,
                                  dates: data.dates,
                                  dotIndexes: data.dotIndexes,
                                  selectedIndex: _selectedIndex,
                                  yMax: data.yMax,
                                  progress: Curves.easeOutCubic
                                      .transform(_animation.value),
                                  money: _money,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  int? _nearestPoint(
    Offset tap,
    Size size,
    List<double> values,
    double yMax,
  ) {
    if (values.isEmpty || yMax <= 0) return null;
    const left = 47.0;
    const right = 10.0;
    const top = 38.0;
    const bottom = 30.0;
    final plotWidth = size.width - left - right;
    final plotHeight = size.height - top - bottom;
    var nearest = -1;
    var nearestDistance = double.infinity;

    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? left + plotWidth / 2
          : left + plotWidth * i / (values.length - 1);
      final y = top + plotHeight * (1 - values[i] / yMax);
      final distance = (tap - Offset(x, y)).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = i;
      }
    }
    return nearestDistance <= 42 ? nearest : null;
  }
}

class _SalesChartData {
  const _SalesChartData({
    required this.labels,
    required this.dates,
    required this.values,
    required this.dotIndexes,
    required this.yMax,
    required this.currentTotal,
    required this.previousTotal,
  });

  final List<String> labels;
  final List<String> dates;
  final List<double> values;
  final List<int> dotIndexes;
  final double yMax;
  final double currentTotal;
  final double previousTotal;
}

class _SalesChartPainter extends CustomPainter {
  const _SalesChartPainter({
    required this.labels,
    required this.values,
    required this.dates,
    required this.dotIndexes,
    required this.selectedIndex,
    required this.yMax,
    required this.progress,
    required this.money,
  });

  final List<String> labels;
  final List<double> values;
  final List<String> dates;
  final List<int> dotIndexes;
  final int selectedIndex;
  final double yMax;
  final double progress;
  final String Function(num) money;

  static const Color _orange = Color(0xFFFF7A3D);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _grid = Color(0xFFE3E6EC);

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final delta = b - a;
    final length = delta.distance;
    if (length == 0) return;
    final direction = delta / length;
    const dash = 2.0;
    const gap = 3.0;
    var distance = 0.0;
    while (distance < length) {
      final end = math.min(distance + dash, length).toDouble();
      canvas.drawLine(
        a + direction * distance,
        a + direction * end,
        paint,
      );
      distance += dash + gap;
    }
  }

  TextPainter _text(
    String value, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w400,
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
    )..layout();
    return painter;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || yMax <= 0) return;

    const left = 47.0;
    const right = 10.0;
    const top = 38.0;
    const bottom = 30.0;
    final plotLeft = left;
    final plotRight = size.width - right;
    final plotTop = top;
    final plotBottom = size.height - bottom;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;
    final gridPaint = Paint()
      ..color = _grid
      ..strokeWidth = .7
      ..style = PaintingStyle.stroke;

    for (var step = 0; step <= 4; step++) {
      final y = plotBottom - plotHeight * step / 4;
      _dashedLine(
        canvas,
        Offset(plotLeft, y),
        Offset(plotRight, y),
        gridPaint,
      );
      final label = money(yMax * step / 4);
      final painter = _text(
        label,
        size: 9,
        color: _muted,
        align: TextAlign.right,
      );
      painter.paint(canvas, Offset(plotLeft - painter.width - 7, y - 5));
    }

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? plotLeft + plotWidth / 2
          : plotLeft + plotWidth * i / (values.length - 1);
      final y = plotBottom - plotHeight * (values[i] / yMax);
      points.add(Offset(x, y));
      _dashedLine(
        canvas,
        Offset(x, plotTop),
        Offset(x, plotBottom),
        gridPaint,
      );
      final label = _text(
        labels[i],
        size: 8,
        color: _muted,
        align: TextAlign.center,
      );
      label.paint(canvas, Offset(x - label.width / 2, plotBottom + 8));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i == 0 ? i : i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2 < points.length ? i + 2 : i + 1];
      final control1 = p1 + (p2 - p0) / 6;
      final control2 = p2 - (p3 - p1) / 6;
      path.cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        p2.dx,
        p2.dy,
      );
    }

    final metrics = path.computeMetrics().toList();
    final animatedPath = Path();
    for (final metric in metrics) {
      animatedPath.addPath(
        metric.extractPath(0, metric.length * progress.clamp(0, 1).toDouble()),
        Offset.zero,
      );
    }
    canvas.drawPath(
      animatedPath,
      Paint()
        ..color = _orange
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (final index in dotIndexes) {
      if (index < 0 || index >= points.length) continue;
      canvas.drawCircle(
        points[index],
        3.6,
        Paint()..color = _orange,
      );
      canvas.drawCircle(
        points[index],
        3.6,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    if (selectedIndex >= 0 && selectedIndex < points.length) {
      final point = points[selectedIndex];
      canvas.drawCircle(point, 5.0, Paint()..color = Colors.white);
      canvas.drawCircle(point, 3.8, Paint()..color = _orange);

      final valueText = _text(
        money(values[selectedIndex]),
        size: 11,
        color: _ink,
        weight: FontWeight.w800,
        align: TextAlign.center,
      );
      final dateText = _text(
        dates[selectedIndex],
        size: 8,
        color: _muted,
        align: TextAlign.center,
      );
      final boxWidth = math.max(
        66.0,
        math.max(valueText.width, dateText.width) + 16,
      ).toDouble();
      const boxHeight = 39.0;
      final boxLeft = (point.dx - boxWidth / 2)
          .clamp(3.0, size.width - boxWidth - 3.0)
          .toDouble();
      final boxTop = math.max(2.0, point.dy - 49).toDouble();
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(boxLeft, boxTop, boxWidth, boxHeight),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = const Color(0xFFE8EAEE)
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8,
      );
      final pointerX = point.dx.clamp(boxLeft + 9, boxLeft + boxWidth - 9).toDouble();
      final pointer = Path()
        ..moveTo(pointerX - 4, boxTop + boxHeight - 1)
        ..lineTo(pointerX, boxTop + boxHeight + 5)
        ..lineTo(pointerX + 4, boxTop + boxHeight - 1)
        ..close();
      canvas.drawPath(pointer, Paint()..color = Colors.white);
      canvas.drawLine(
        Offset(pointerX - 4, boxTop + boxHeight),
        Offset(pointerX, boxTop + boxHeight + 5),
        Paint()
          ..color = const Color(0xFFE8EAEE)
          ..strokeWidth = .8,
      );
      canvas.drawLine(
        Offset(pointerX, boxTop + boxHeight + 5),
        Offset(pointerX + 4, boxTop + boxHeight),
        Paint()
          ..color = const Color(0xFFE8EAEE)
          ..strokeWidth = .8,
      );
      valueText.paint(
        canvas,
        Offset(boxLeft + (boxWidth - valueText.width) / 2, boxTop + 5),
      );
      dateText.paint(
        canvas,
        Offset(boxLeft + (boxWidth - dateText.width) / 2, boxTop + 23),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SalesChartPainter oldDelegate) =>
      oldDelegate.labels != labels ||
      oldDelegate.values != values ||
      oldDelegate.dates != dates ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.yMax != yMax ||
      oldDelegate.progress != progress;
}
