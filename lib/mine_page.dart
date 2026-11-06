import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

const _palette = [
  kAccent,
  kGreen,
  kAmber,
  kRed,
  Color(0xFFB08CF5),
  Color(0xFF5FD0D6),
];

Color _heatColor(int n) {
  if (n <= 0) return kTrack;
  if (n == 1) return const Color(0xFF3E5A94);
  if (n == 2) return const Color(0xFF4F79CC);
  return kAccent;
}

class MinePage extends StatefulWidget {
  const MinePage({
    super.key,
    required this.tasks,
    required this.completions,
    required this.focus,
    required this.onStartFocus,
  });

  final List<TaskItem> tasks;
  final List<Completion> completions;
  final Map<String, int> focus;
  final VoidCallback onStartFocus;

  @override
  State<MinePage> createState() => _MinePageState();
}

class _MinePageState extends State<MinePage> {
  int doneWeek = 0;
  int focusWeek = 0;
  int rangeDays = 30;
  int year = Jalali.now().year;
  final heatCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollHeat());
  }

  @override
  void dispose() {
    heatCtrl.dispose();
    super.dispose();
  }

  void _scrollHeat() {
    if (!heatCtrl.hasClients) return;

    double target = 0;
    final now = Jalali.now();

    if (year == now.year) {
      final doy = (now.month <= 6
              ? (now.month - 1) * 31
              : 186 + (now.month - 7) * 30) +
          now.day -
          1;
      target = doy / 7 * 18 - 120;
    }

    final maxExtent = heatCtrl.position.maxScrollExtent;
    if (target > maxExtent) target = maxExtent;
    if (target < 0) target = 0;
    heatCtrl.jumpTo(target);
  }

  // ---------- data ----------

  Map<String, int> get _perDay {
    final m = <String, int>{};
    for (final c in widget.completions) {
      final k = dayKey(c.at);
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }

  int get _streak {
    final m = _perDay;
    var d = dayOnly(DateTime.now());
    if (!m.containsKey(dayKey(d))) {
      d = DateTime(d.year, d.month, d.day - 1);
    }
    var n = 0;
    while (m.containsKey(dayKey(d))) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  DateTime _weekStart(int offset) {
    final s = weekStartOf(DateTime.now());
    return DateTime(s.year, s.month, s.day + offset * 7);
  }

  String _weekLabel(DateTime ws) {
    final we = DateTime(ws.year, ws.month, ws.day + 6);
    final a = ws.toJalali();
    final b = we.toJalali();
    return '${a.day} ${months[a.month - 1]} تا ${b.day} ${months[b.month - 1]}';
  }

  // ---------- small widgets ----------

  Widget _title(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: kText,
        ),
      );

  Widget _weekNav(int offset, void Function(int) onChange, DateTime ws) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onChange(offset - 1),
          icon: const Icon(Icons.chevron_left, color: kDim),
        ),
        Text(_weekLabel(ws), style: const TextStyle(color: kText, fontSize: 13)),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: offset >= 0 ? null : () => onChange(offset + 1),
          icon: const Icon(Icons.chevron_right, color: kDim),
        ),
      ],
    );
  }

  Widget _statCard(String label, int value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Text(label, style: const TextStyle(color: kDim, fontSize: 15)),
              const SizedBox(height: 10),
              Text(
                '$value',
                style: const TextStyle(fontSize: 42, color: kText),
              ),
            ],
          ),
        ),
      );

  // ---------- sections ----------

  Widget _header() {
    final n = _streak;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18, top: 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 36,
            backgroundColor: kChip,
            child: Icon(Icons.person, color: kDim, size: 40),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'برنامه‌ریز شخصی',
                  style: TextStyle(fontSize: 21, color: kText),
                ),
                const SizedBox(height: 4),
                Text(
                  n == 0
                      ? 'امروز با یک کار کوچک شروع کن!'
                      : '$n روز پیاپی به برنامه‌ات پایبند بودی!',
                  style: const TextStyle(color: kDim, fontSize: 15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heatmap() {
    final y = year;
    final perDay = _perDay;
    final first = Jalali(y, 1, 1);
    final g = first.toDateTime();
    final date0 = DateTime(g.year, g.month, g.day);
    final wd0 = first.weekDay - 1;

    var total = 0;
    for (var m = 1; m <= 12; m++) {
      total += Jalali(y, m, 1).monthLength;
    }

    final cols = (wd0 + total + 6) ~/ 7;
    final today = dayOnly(DateTime.now());
    const cell = 15.0;
    const gap = 3.0;

    final columns = <Widget>[];

    for (var c = 0; c < cols; c++) {
      var label = '';
      final cells = <Widget>[];

      for (var r = 0; r < 7; r++) {
        final idx = c * 7 + r - wd0;

        if (idx < 0 || idx >= total) {
          cells.add(const SizedBox(width: cell, height: cell + gap));
          continue;
        }

        final d = DateTime(date0.year, date0.month, date0.day + idx);
        final j = d.toJalali();

        if (j.day == 1 && label.isEmpty) label = months[j.month - 1];

        final n = perDay[dayKey(d)] ?? 0;

        cells.add(
          Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: Container(
              width: cell,
              height: cell,
              decoration: BoxDecoration(
                color: _heatColor(n),
                borderRadius: BorderRadius.circular(4),
                border: d == today ? Border.all(color: kText, width: 1.2) : null,
              ),
            ),
          ),
        );
      }

      columns.add(
        Padding(
          padding: const EdgeInsets.only(left: gap),
          child: Column(
            children: [
              SizedBox(
                height: 16,
                width: cell,
                child: OverflowBox(
                  maxWidth: 70,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    label,
                    softWrap: false,
                    style: const TextStyle(color: kDim, fontSize: 10),
                  ),
                ),
              ),
              ...cells,
            ],
          ),
        ),
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _title('نقشه سالانه'),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => year--);
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollHeat());
                },
                icon: const Icon(Icons.chevron_left, color: kDim),
              ),
              Text('$year', style: const TextStyle(color: kText)),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  setState(() => year++);
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollHeat());
                },
                icon: const Icon(Icons.chevron_right, color: kDim),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const SizedBox(height: 16),
                  for (final w in weekdaysShort)
                    SizedBox(
                      height: cell + gap,
                      width: 20,
                      child: Center(
                        child: Text(
                          w,
                          style: const TextStyle(color: kDim, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: heatCtrl,
                  scrollDirection: Axis.horizontal,
                  child: Row(children: columns),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _byCategory() {
    final since = DateTime.now().subtract(Duration(days: rangeDays));
    final counts = <String, int>{};

    for (final c in widget.completions) {
      if (c.at.isBefore(since)) continue;
      final k = c.category ?? 'بدون دسته';
      counts[k] = (counts[k] ?? 0) + 1;
    }

    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _title('کارهای انجام‌شده'),
              const Spacer(),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: rangeDays,
                  dropdownColor: kCard,
                  style: const TextStyle(color: kDim, fontSize: 14),
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('۷ روز اخیر')),
                    DropdownMenuItem(value: 30, child: Text('۳۰ روز اخیر')),
                    DropdownMenuItem(value: 90, child: Text('۹۰ روز اخیر')),
                  ],
                  onChanged: (v) => setState(() => rangeDays = v ?? 30),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: DonutPainter(
                    entries.map((e) => e.value.toDouble()).toList(),
                    _palette,
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: entries.isEmpty
                    ? const Text(
                        'کار انجام‌شده‌ای نیست',
                        style: TextStyle(color: kDim),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < entries.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _palette[i % _palette.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      entries[i].key,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: kText),
                                    ),
                                  ),
                                  Text(
                                    '${entries[i].value}',
                                    style: const TextStyle(color: kDim),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dailyDone() {
    final ws = _weekStart(doneWeek);
    final perDay = _perDay;
    final counts = List<int>.generate(7, (i) {
      final d = DateTime(ws.year, ws.month, ws.day + i);
      return perDay[dayKey(d)] ?? 0;
    });

    final sum = counts.fold<int>(0, (a, b) => a + b);
    var maxCount = 0;
    var bestIndex = 0;
    for (var i = 0; i < 7; i++) {
      if (counts[i] > maxCount) {
        maxCount = counts[i];
        bestIndex = i;
      }
    }

    final scale = maxCount < 4 ? 4 : maxCount;

    final weekEnd = DateTime(ws.year, ws.month, ws.day + 7);
    final pending = widget.tasks.where((t) {
      if (t.done) return false;
      return !t.start.isBefore(ws) && t.start.isBefore(weekEnd);
    }).length;

    final rate = (sum + pending) == 0 ? 0 : (sum * 100 / (sum + pending)).round();

    final message = sum == 0
        ? 'هنوز کاری انجام نشده؛ از یک کار کوچک شروع کن.'
        : sum <= 3
            ? 'هفته‌ی سبک—جای نفس‌کشیدن زیاد هست.'
            : sum <= 10
                ? 'هفته‌ی متعادل، همین‌طور ادامه بده.'
                : 'هفته‌ی پرکار! آفرین.';

    const barHeight = 120.0;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _title('انجام‌شده در هر روز'),
              const Spacer(),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _weekNav(doneWeek, (v) => setState(() => doneWeek = v), ws),
          ),
          Text(message, style: const TextStyle(color: kDim)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        height: 16,
                        child: Text(
                          counts[i] > 0 ? '${counts[i]}' : '',
                          style: const TextStyle(color: kText, fontSize: 12),
                        ),
                      ),
                      SizedBox(
                        height: barHeight,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              width: 14,
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: kTrack,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            Container(
                              width: 14,
                              height: barHeight * counts[i] / scale,
                              decoration: BoxDecoration(
                                color: kAccent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        weekdaysShort[i],
                        style: const TextStyle(color: kDim, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('نرخ تکمیل کارها  ', style: TextStyle(color: kDim)),
              Text(
                '$rate٪',
                style: const TextStyle(color: kAccent, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('پربازده‌ترین روز  ', style: TextStyle(color: kDim)),
              Text(
                maxCount > 0 ? weekdays[bestIndex] : '--',
                style: const TextStyle(color: kAccent, fontSize: 17),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _focusCard() {
    final ws = _weekStart(focusWeek);
    var totalSecs = 0;
    final values = List<double>.generate(7, (i) {
      final d = DateTime(ws.year, ws.month, ws.day + i);
      final s = widget.focus[dayKey(d)] ?? 0;
      totalSecs += s;
      return s / 60;
    });

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('تمرکز'),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _weekNav(focusWeek, (v) => setState(() => focusWeek = v), ws),
          ),
          Row(
            children: [
              const Text('مجموع تمرکز این هفته  ', style: TextStyle(color: kDim)),
              Text(
                '${totalSecs ~/ 60} دقیقه',
                style: const TextStyle(color: kAccent, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            width: double.infinity,
            child: CustomPaint(painter: LinePainter(values)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final w in weekdaysShort)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(color: kDim, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onStartFocus,
              icon: const Icon(Icons.timer_outlined),
              label: const Text('شروع تمرکز'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextDays() {
    final today = dayOnly(DateTime.now());
    final until = DateTime(today.year, today.month, today.day + 7);

    final list = widget.tasks
        .where((t) =>
            !t.done &&
            !t.notDone &&
            !t.start.isBefore(today) &&
            t.start.isBefore(until))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('کارهای ۷ روز آینده'),
          const SizedBox(height: 10),
          if (list.isEmpty)
            const Text('کاری برای این بازه ثبت نشده', style: TextStyle(color: kDim))
          else
            for (final t in list)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.title,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kText, fontSize: 15),
                      ),
                    ),
                    Text(
                      '${shortDateText(t.start)} • ${timeText(t.start)}',
                      style: const TextStyle(color: kDim, fontSize: 13),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending =
        widget.tasks.where((t) => !t.done && !t.notDone).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _header(),
        Row(
          children: [
            _statCard('انجام‌شده', widget.completions.length),
            const SizedBox(width: 12),
            _statCard('در انتظار', pending),
          ],
        ),
        const SizedBox(height: 14),
        _heatmap(),
        _byCategory(),
        _dailyDone(),
        _focusCard(),
        _nextDays(),
      ],
    );
  }
}
