import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'editor_page.dart';
import 'focus_page.dart';
import 'mine_page.dart';
import 'models.dart';
import 'notifications.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initNotifications();
  } catch (_) {
    // اگر اعلان‌ها راه نیفتادند، برنامه همچنان باید باز شود
  }

  runApp(const PlannerApp());
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'برنامه‌ریز',
        locale: const Locale('fa', 'IR'),
        supportedLocales: const [Locale('fa', 'IR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<TaskItem> tasks = [];
  List<Completion> completions = [];
  Map<String, int> focus = {};
  List<String> categories = ['کاری', 'شخصی', 'آرزوها'];
  String? filter;
  int tab = 0;
  Jalali shown = Jalali.now();
  bool loading = true;
  final Set<String> collapsed = {};
  final Map<String, Uint8List> _thumbCache = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------- storage ----------------

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();

    final raw = p.getString('tasks_v1');
    if (raw != null) {
      try {
        tasks = (jsonDecode(raw) as List)
            .map((e) => TaskItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        tasks = [];
      }
    }

    final rawC = p.getString('completions_v1');
    if (rawC != null) {
      try {
        completions = (jsonDecode(rawC) as List)
            .map((e) => Completion.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        completions = [];
      }
    } else {
      // نسخه‌ی قدیمی: برای کارهای انجام‌شده سابقه می‌سازیم تا در آمار بیایند
      completions = tasks
          .where((t) => t.done)
          .map((t) => Completion(
                taskId: t.id,
                category: t.category,
                at: t.start,
              ))
          .toList();
    }

    final rawF = p.getString('focus_v1');
    if (rawF != null) {
      try {
        final m = jsonDecode(rawF) as Map;
        focus = m.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      } catch (_) {
        focus = {};
      }
    }

    final cats = p.getStringList('categories_v1');
    if (cats != null) categories = cats;

    for (final task in tasks) {
      await scheduleTaskNotification(task);
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();

    await p.setString(
      'tasks_v1',
      jsonEncode(tasks.map((e) => e.toJson()).toList()),
    );
    await p.setString(
      'completions_v1',
      jsonEncode(completions.map((e) => e.toJson()).toList()),
    );
    await p.setString('focus_v1', jsonEncode(focus));
    await p.setStringList('categories_v1', categories);
  }

  // ---------------- actions ----------------

  Future<void> _openEditor([TaskItem? old]) async {
    final result = await Navigator.of(context).push<EditorResult>(
      MaterialPageRoute(
        builder: (_) => TaskEditorPage(
          existing: old,
          categories: categories,
          initialCategory: filter,
          initialDate: tab == 1 ? shown.toDateTime() : null,
        ),
      ),
    );

    if (result == null) return;

    if (result.delete) {
      if (old != null) await _delete(old);
      return;
    }

    final t = result.task;
    if (t == null) return;

    setState(() {
      final i = tasks.indexWhere((e) => e.id == t.id);
      if (i < 0) {
        tasks.add(t);
      } else {
        tasks[i] = t;
      }
    });

    await _save();
    await scheduleTaskNotification(t);
  }

  void _removeLastCompletion(String id) {
    final i = completions.lastIndexWhere((c) => c.taskId == id);
    if (i >= 0) completions.removeAt(i);
  }

  Future<void> _toggleDone(TaskItem t) async {
    final i = tasks.indexWhere((e) => e.id == t.id);
    if (i < 0) return;

    TaskItem updated;

    if (t.done) {
      _removeLastCompletion(t.id);
      updated = t.copy(done: false);
    } else {
      completions.add(
        Completion(taskId: t.id, category: t.category, at: DateTime.now()),
      );

      if (t.repeat != 'none') {
        updated = nextOccurrence(t);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'کار بعدی برای ${shortDateText(updated.start)} تنظیم شد',
              ),
            ),
          );
        }
      } else {
        updated = t.copy(done: true, notDone: false);
      }
    }

    setState(() => tasks[i] = updated);

    await _save();
    await scheduleTaskNotification(updated);
  }

  Future<void> _toggleNotDone(TaskItem t) async {
    final i = tasks.indexWhere((e) => e.id == t.id);
    if (i < 0) return;

    if (t.done) _removeLastCompletion(t.id);

    final updated = t.copy(done: false, notDone: !t.notDone);

    setState(() => tasks[i] = updated);

    await _save();
    await scheduleTaskNotification(updated);
  }

  Future<void> _toggleFlag(TaskItem t) async {
    final i = tasks.indexWhere((e) => e.id == t.id);
    if (i < 0) return;

    setState(() => tasks[i] = t.copy(flag: !t.flag));
    await _save();
  }

  Future<void> _delete(TaskItem t) async {
    setState(() => tasks.removeWhere((e) => e.id == t.id));

    await _save();
    await notifications.cancel(notificationId(t.id));
  }

  Future<void> _startFocus() async {
    final secs = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => const FocusPage()),
    );

    if (secs == null || secs <= 0) return;

    final k = dayKey(DateTime.now());
    setState(() => focus[k] = (focus[k] ?? 0) + secs);
    await _save();
  }

  void _addCategory(String name) {
    setState(() => categories.add(name));
    _save();
  }

  void _removeCategory(String name) {
    setState(() {
      categories.remove(name);
      tasks = tasks
          .map((t) => t.category == name ? t.copy(clearCategory: true) : t)
          .toList();
      if (filter == name) filter = null;
    });
    _save();
  }

  Future<void> _manageCategories() async {
    final ctrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('دسته‌ها'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in categories)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(c),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          _removeCategory(c);
                          setD(() {});
                        },
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          decoration: const InputDecoration(
                            hintText: 'دسته جدید',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          final n = ctrl.text.trim();
                          if (n.isEmpty || categories.contains(n)) return;
                          _addCategory(n);
                          ctrl.clear();
                          setD(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('بستن'),
            ),
          ],
        ),
      ),
    );
  }

  void _changeMonth(int delta) {
    var y = shown.year;
    var m = shown.month + delta;

    while (m > 12) {
      m -= 12;
      y++;
    }
    while (m < 1) {
      m += 12;
      y--;
    }

    final len = Jalali(y, m, 1).monthLength;
    setState(() => shown = Jalali(y, m, shown.day > len ? len : shown.day));
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: tab == 0
            ? _tasksTab()
            : tab == 1
                ? _calendarTab()
                : MinePage(
                    tasks: tasks,
                    completions: completions,
                    focus: focus,
                    onStartFocus: _startFocus,
                  ),
      ),
      floatingActionButton: tab == 2
          ? null
          : FloatingActionButton(
              onPressed: () => _openEditor(),
              backgroundColor: kAccent,
              foregroundColor: kOnAccent,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 32),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'کارها'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month),
            label: 'تقویم',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'من'),
        ],
      ),
    );
  }

  // ---------------- tasks tab ----------------

  Widget _catChip(String label, String? value) {
    final selected = filter == value;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: GestureDetector(
        onTap: () => setState(() => filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kAccent : kChip,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: selected ? kOnAccent : kDim,
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryBar() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _catChip('همه', null),
                    for (final c in categories) _catChip(c, c),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'مدیریت دسته‌ها',
              onPressed: _manageCategories,
              icon: const Icon(Icons.more_vert, color: kDim),
            ),
          ],
        ),
      );

  Widget _groupHeader(String key, int count, Color color) {
    final isCollapsed = collapsed.contains(key);

    return InkWell(
      onTap: () => setState(() {
        if (isCollapsed) {
          collapsed.remove(key);
        } else {
          collapsed.add(key);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(
              '$key ($count)',
              style: TextStyle(fontSize: 18, color: color),
            ),
            const SizedBox(width: 8),
            Icon(
              isCollapsed ? Icons.expand_more : Icons.expand_less,
              color: kDim,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tasksTab() {
    final today = dayOnly(DateTime.now());
    final tomorrow = DateTime(today.year, today.month, today.day + 1);

    final list = tasks
        .where((t) => filter == null || t.category == filter)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final groups = <String, List<TaskItem>>{
      'عقب‌افتاده': [],
      'امروز': [],
      'فردا': [],
      'بعداً': [],
      'پایان‌یافته': [],
    };

    for (final t in list) {
      if (t.done || t.notDone) {
        groups['پایان‌یافته']!.add(t);
        continue;
      }

      final d = dayOnly(t.start);

      if (d.isBefore(today)) {
        groups['عقب‌افتاده']!.add(t);
      } else if (d == today) {
        groups['امروز']!.add(t);
      } else if (d == tomorrow) {
        groups['فردا']!.add(t);
      } else {
        groups['بعداً']!.add(t);
      }
    }

    final children = <Widget>[];

    groups.forEach((key, items) {
      if (items.isEmpty) return;

      children.add(
        _groupHeader(key, items.length, key == 'عقب‌افتاده' ? kRed : kText),
      );

      if (!collapsed.contains(key)) {
        for (final t in items) {
          children.add(_taskCard(t));
        }
      }
    });

    return Column(
      children: [
        _categoryBar(),
        Expanded(
          child: children.isEmpty
              ? const Center(
                  child: Text(
                    'هنوز کاری ثبت نشده است',
                    style: TextStyle(color: kDim),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: children,
                ),
        ),
      ],
    );
  }

  void _showImage(Uint8List bytes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: InteractiveViewer(child: Image.memory(bytes)),
        ),
      ),
    );
  }

  Widget _thumb(TaskItem t, int i) {
    const size = 52.0;
    final a = t.attachments[i];

    if (a['image'] == true) {
      final data = a['data'] as String;
      final key = '${t.id}:$i:${data.length}';
      final bytes = _thumbCache.putIfAbsent(key, () => base64Decode(data));

      return GestureDetector(
        onTap: () => _showImage(bytes),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: 160,
            gaplessPlayback: true,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kBarBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 20, color: kDim),
          Text(
            a['name'].toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: kDim, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _thumbs(TaskItem t) {
    final count = t.attachments.length;
    final shownCount = count > 4 ? 4 : count;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < shownCount; i++) _thumb(t, i),
          if (count > 4)
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kBarBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '+${count - 4}',
                style: const TextStyle(color: kDim),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusButton({
    required IconData icon,
    required Color color,
    required String tip,
    required VoidCallback onTap,
  }) =>
      IconButton(
        tooltip: tip,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 28),
      );

  Widget _taskCard(TaskItem t) {
    final finished = t.done || t.notDone;
    final subDone = t.subtasks.where((s) => s.done).length;
    const metaStyle = TextStyle(color: kDim, fontSize: 12.5);
    const off = Color(0xFF6C7396);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openEditor(t),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(
                    t.done
                        ? Icons.check_circle
                        : t.notDone
                            ? Icons.cancel
                            : Icons.radio_button_unchecked,
                    color: t.done
                        ? kGreen
                        : t.notDone
                            ? kRed
                            : kDim,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: TextStyle(
                            fontSize: 16,
                            color: finished ? kDim : kText,
                            decoration:
                                finished ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${shortDateText(t.start)} • ${timeText(t.start)} - ${timeText(t.end)}',
                              style: metaStyle,
                            ),
                            if (t.reminder != null)
                              const Icon(
                                Icons.notifications_none,
                                size: 16,
                                color: kDim,
                              ),
                            if (t.attachments.isNotEmpty)
                              const Icon(
                                Icons.attach_file,
                                size: 16,
                                color: kDim,
                              ),
                            if (t.repeat != 'none')
                              const Icon(Icons.repeat, size: 16, color: kDim),
                            if (t.flag)
                              const Icon(Icons.flag, size: 16, color: kAmber),
                            if (t.subtasks.isNotEmpty)
                              Text(
                                '☑ $subDone/${t.subtasks.length}',
                                style: metaStyle,
                              ),
                            if (t.category != null)
                              Text(
                                t.category!,
                                style: const TextStyle(
                                  color: kAccent,
                                  fontSize: 12.5,
                                ),
                              ),
                          ],
                        ),
                        if (t.attachments.isNotEmpty) _thumbs(t),
                      ],
                    ),
                  ),
                ),
                _statusButton(
                  icon: Icons.check_circle,
                  color: t.done ? kGreen : off,
                  tip: 'انجام شد',
                  onTap: () => _toggleDone(t),
                ),
                _statusButton(
                  icon: Icons.cancel,
                  color: t.notDone ? kRed : off,
                  tip: 'انجام نشد',
                  onTap: () => _toggleNotDone(t),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: kDim),
                  padding: EdgeInsets.zero,
                  onSelected: (v) {
                    if (v == 'edit') _openEditor(t);
                    if (v == 'flag') _toggleFlag(t);
                    if (v == 'delete') _delete(t);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                    PopupMenuItem(
                      value: 'flag',
                      child: Text(t.flag ? 'برداشتن علامت مهم' : 'علامت مهم'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('حذف')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- calendar tab ----------------

  Widget _calendarTab() {
    final dayTasks = tasks.where((t) {
      final j = t.start.toJalali();
      return j.year == shown.year &&
          j.month == shown.month &&
          j.day == shown.day;
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${months[shown.month - 1]} ${shown.year}',
                    style: const TextStyle(fontSize: 21, color: kText),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: List.generate(
              7,
              (i) => Expanded(
                child: Center(
                  child: Text(
                    weekdaysShort[i],
                    style: const TextStyle(color: kDim, fontSize: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
        _monthGrid(),
        const Divider(height: 1, color: kTrack),
        Expanded(
          child: dayTasks.isEmpty
              ? const Center(
                  child: Text(
                    'برای این روز کاری ثبت نشده',
                    style: TextStyle(color: kDim),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  children: dayTasks.map(_taskCard).toList(),
                ),
        ),
      ],
    );
  }

  Widget _monthGrid() {
    final first = Jalali(shown.year, shown.month, 1);
    final offset = first.weekDay - 1;
    final count = first.monthLength;
    final now = Jalali.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1.25,
        ),
        itemCount: ((offset + count + 6) ~/ 7) * 7,
        itemBuilder: (_, i) {
          final day = i - offset + 1;

          if (day < 1 || day > count) return const SizedBox();

          final selected = day == shown.day;
          final isToday = now.year == shown.year &&
              now.month == shown.month &&
              now.day == day;

          final has = tasks.any((t) {
            final j = t.start.toJalali();
            return j.year == shown.year &&
                j.month == shown.month &&
                j.day == day;
          });

          return InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => setState(
              () => shown = Jalali(shown.year, shown.month, day),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? kAccent : null,
                    shape: BoxShape.circle,
                    border: (isToday && !selected)
                        ? Border.all(color: kAccent, width: 1.5)
                        : null,
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      color: selected ? kOnAccent : kText,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (has)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: kAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
