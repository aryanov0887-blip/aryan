import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'models.dart';
import 'theme.dart';

class EditorResult {
  const EditorResult.save(this.task) : delete = false;
  const EditorResult.remove()
      : task = null,
        delete = true;

  final TaskItem? task;
  final bool delete;
}

const _noCategory = '__none__';

String reminderLabel(int v) {
  if (v < 0) return 'بدون یادآور';
  if (v == 0) return 'سر وقت';
  if (v == 60) return 'یک ساعت قبل';
  if (v == 1440) return 'یک روز قبل';
  return '$v دقیقه قبل';
}

String repeatLabel(String v) {
  switch (v) {
    case 'daily':
      return 'هر روز';
    case 'weekly':
      return 'هر هفته';
    case 'monthly':
      return 'هر ماه';
    default:
      return 'بدون تکرار';
  }
}

class TaskEditorPage extends StatefulWidget {
  const TaskEditorPage({
    super.key,
    this.existing,
    required this.categories,
    this.initialCategory,
    this.initialDate,
  });

  final TaskItem? existing;
  final List<String> categories;
  final String? initialCategory;
  final DateTime? initialDate;

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  late TextEditingController title;
  late TextEditingController notes;
  late DateTime start;
  late DateTime end;
  late List<SubTask> subtasks;
  late List<Map<String, dynamic>> attachments;
  String? category;
  int reminder = 5; // -1 یعنی بدون یادآور
  String reminderType = 'standard';
  String repeat = 'none';
  bool flag = false;

  @override
  void initState() {
    super.initState();

    final t = widget.existing;
    title = TextEditingController(text: t?.title ?? '');
    notes = TextEditingController(text: t?.notes ?? '');

    category = t != null ? t.category : widget.initialCategory;
    if (category != null && !widget.categories.contains(category)) {
      category = null;
    }

    final base = widget.initialDate ?? DateTime.now();
    start = t?.start ?? DateTime(base.year, base.month, base.day, 9);
    end = t?.end ?? DateTime(base.year, base.month, base.day, 10);

    subtasks = t == null
        ? []
        : t.subtasks.map((s) => SubTask(title: s.title, done: s.done)).toList();

    attachments = List<Map<String, dynamic>>.from(t?.attachments ?? []);

    reminder = t == null ? 5 : (t.reminder ?? -1);
    reminderType = t?.reminderType ?? 'standard';
    repeat = t?.repeat ?? 'none';
    flag = t?.flag ?? false;
  }

  @override
  void dispose() {
    title.dispose();
    notes.dispose();
    super.dispose();
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------- helpers ----------

  Future<T?> _pick<T>(String heading, List<MapEntry<T, String>> options) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(heading),
        children: [
          for (final o in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, o.key),
              child: Text(o.value, style: const TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
  }

  Future<String?> _askText(String heading) async {
    final c = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(heading),
        content: TextField(
          controller: c,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('افزودن'),
          ),
        ],
      ),
    );
    return result?.trim();
  }

  Widget _pill(String text, VoidCallback onTap) => Material(
        color: kChip,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(text, style: const TextStyle(color: kText)),
          ),
        ),
      );

  Widget _row(IconData icon, String label, Widget trailing) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: kDim),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, color: kText),
              ),
            ),
            trailing,
          ],
        ),
      );

  Widget _divider() => const Divider(height: 1, color: kTrack);

  // ---------- date / time ----------

  Future<void> _chooseDate() async {
    final initial = start.toJalali();

    final picked = await showDialog<Jalali>(
      context: context,
      builder: (ctx) {
        int y = initial.year;
        int m = initial.month;
        int d = initial.day;

        return StatefulBuilder(
          builder: (ctx, setD) {
            final len = Jalali(y, m, 1).monthLength;
            final safeDay = d > len ? len : d;

            return AlertDialog(
              title: const Text('انتخاب تاریخ شمسی'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: m,
                          items: List.generate(
                            12,
                            (i) => DropdownMenuItem(
                              value: i + 1,
                              child: Text(months[i]),
                            ),
                          ),
                          onChanged: (v) => setD(() => m = v!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: y,
                          items: List.generate(
                            11,
                            (i) => DropdownMenuItem(
                              value: initial.year - 5 + i,
                              child: Text('${initial.year - 5 + i}'),
                            ),
                          ),
                          onChanged: (v) => setD(() => y = v!),
                        ),
                      ),
                    ],
                  ),
                  DropdownButton<int>(
                    value: safeDay,
                    items: List.generate(
                      len,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('${i + 1}'),
                      ),
                    ),
                    onChanged: (v) => setD(() => d = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('لغو'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, Jalali(y, m, safeDay)),
                  child: const Text('تأیید'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() {
        final g = picked.toDateTime();
        final duration = end.difference(start);
        final newStart = DateTime(g.year, g.month, g.day, start.hour, start.minute);

        start = newStart;
        end = newStart.add(
          duration.isNegative ? const Duration(hours: 1) : duration,
        );
      });
    }
  }

  Future<void> _chooseTime(bool isStart) async {
    final old = isStart ? start : end;

    final p = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(old),
      builder: (c, w) => Directionality(
        textDirection: TextDirection.rtl,
        child: w!,
      ),
    );

    if (p == null) return;

    setState(() {
      if (isStart) {
        final duration = end.difference(start);
        start = DateTime(start.year, start.month, start.day, p.hour, p.minute);
        end = start.add(
          duration.isNegative ? const Duration(hours: 1) : duration,
        );
      } else {
        end = DateTime(end.year, end.month, end.day, p.hour, p.minute);
      }
    });
  }

  // ---------- attachments ----------

  Future<void> _addFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.any,
    );

    if (res == null) return;

    for (final f in res.files) {
      if (f.bytes == null) continue;

      final isImg = RegExp(
        r'^(png|jpe?g|gif|webp|bmp)$',
      ).hasMatch((f.extension ?? '').toLowerCase());

      attachments.add({
        'name': f.name,
        'data': base64Encode(f.bytes!),
        'image': isImg,
      });
    }

    if (mounted) setState(() {});
  }

  Widget _attachmentView(int i) {
    final a = attachments[i];

    if (a['image'] == true) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(a['data']),
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () => setState(() => attachments.removeAt(i)),
              child: const CircleAvatar(
                radius: 11,
                backgroundColor: kBarBg,
                child: Icon(Icons.close, size: 14, color: kText),
              ),
            ),
          ),
        ],
      );
    }

    return InputChip(
      label: Text(a['name'].toString(), overflow: TextOverflow.ellipsis),
      onDeleted: () => setState(() => attachments.removeAt(i)),
    );
  }

  // ---------- save ----------

  void _save() {
    final name = title.text.trim();

    if (name.isEmpty) {
      _snack('عنوان کار را وارد کن');
      return;
    }

    if (!end.isAfter(start)) {
      _snack('زمان پایان باید بعد از شروع باشد');
      return;
    }

    final old = widget.existing;

    Navigator.pop(
      context,
      EditorResult.save(
        TaskItem(
          id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
          title: name,
          start: start,
          end: end,
          done: old?.done ?? false,
          notDone: old?.notDone ?? false,
          attachments: attachments,
          category: category,
          subtasks: subtasks,
          notes: notes.text.trim(),
          repeat: repeat,
          reminder: reminder < 0 ? null : reminder,
          reminderType: reminderType,
          flag: flag,
        ),
      ),
    );
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'مهم',
            onPressed: () => setState(() => flag = !flag),
            icon: Icon(
              flag ? Icons.flag : Icons.flag_outlined,
              color: flag ? kAmber : kDim,
            ),
          ),
          if (widget.existing != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') {
                  Navigator.pop(context, const EditorResult.remove());
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('حذف کار')),
              ],
            ),
          TextButton(onPressed: _save, child: const Text('ذخیره')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: kChip,
                borderRadius: BorderRadius.circular(30),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: category ?? _noCategory,
                  dropdownColor: kCard,
                  style: const TextStyle(color: kText, fontSize: 16),
                  items: [
                    const DropdownMenuItem(
                      value: _noCategory,
                      child: Text('بدون دسته'),
                    ),
                    for (final c in widget.categories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(
                    () => category = v == _noCategory ? null : v,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: title,
            maxLines: null,
            style: const TextStyle(fontSize: 22, color: kText),
            decoration: const InputDecoration(
              hintText: 'عنوان کار',
              hintStyle: TextStyle(color: kDim),
              border: InputBorder.none,
            ),
          ),
          for (var i = 0; i < subtasks.length; i++)
            Row(
              children: [
                Checkbox(
                  value: subtasks[i].done,
                  onChanged: (v) => setState(() => subtasks[i].done = v ?? false),
                ),
                Expanded(
                  child: Text(
                    subtasks[i].title,
                    style: TextStyle(
                      color: subtasks[i].done ? kDim : kText,
                      decoration:
                          subtasks[i].done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => subtasks.removeAt(i)),
                  icon: const Icon(Icons.close, color: kDim, size: 20),
                ),
              ],
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () async {
                final text = await _askText('زیرکار جدید');
                if (text != null && text.isNotEmpty) {
                  setState(() => subtasks.add(SubTask(title: text)));
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('افزودن زیرکار', style: TextStyle(fontSize: 16)),
            ),
          ),
          _divider(),
          _row(
            Icons.event,
            'تاریخ',
            _pill(dateText(start), _chooseDate),
          ),
          _divider(),
          _row(
            Icons.schedule,
            'ساعت شروع',
            _pill(timeText(start), () => _chooseTime(true)),
          ),
          _row(
            Icons.schedule_outlined,
            'ساعت پایان',
            _pill(timeText(end), () => _chooseTime(false)),
          ),
          _row(
            Icons.notifications_none,
            'یادآوری',
            _pill(reminderLabel(reminder), () async {
              final v = await _pick<int>('یادآوری', <MapEntry<int, String>>[
                MapEntry(-1, reminderLabel(-1)),
                MapEntry(0, reminderLabel(0)),
                MapEntry(5, reminderLabel(5)),
                MapEntry(10, reminderLabel(10)),
                MapEntry(30, reminderLabel(30)),
                MapEntry(60, reminderLabel(60)),
                MapEntry(1440, reminderLabel(1440)),
              ]);
              if (v != null) setState(() => reminder = v);
            }),
          ),
          if (reminder >= 0)
            _row(
              Icons.alarm,
              'نوع یادآوری',
              _pill(
                reminderType == 'alarm' ? 'هشدار قوی' : 'اعلان معمولی',
                () async {
                  final v = await _pick<String>(
                    'نوع یادآوری',
                    <MapEntry<String, String>>[
                      const MapEntry('standard', 'اعلان معمولی'),
                      const MapEntry('alarm', 'هشدار قوی (صدا و لرزش)'),
                    ],
                  );
                  if (v != null) setState(() => reminderType = v);
                },
              ),
            ),
          _divider(),
          _row(
            Icons.repeat,
            'تکرار کار',
            _pill(repeatLabel(repeat), () async {
              final v = await _pick<String>('تکرار', <MapEntry<String, String>>[
                MapEntry('none', repeatLabel('none')),
                MapEntry('daily', repeatLabel('daily')),
                MapEntry('weekly', repeatLabel('weekly')),
                MapEntry('monthly', repeatLabel('monthly')),
              ]);
              if (v != null) setState(() => repeat = v);
            }),
          ),
          _divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.sticky_note_2_outlined, color: kDim),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: notes,
                  minLines: 1,
                  maxLines: 6,
                  style: const TextStyle(color: kText),
                  decoration: const InputDecoration(
                    hintText: 'یادداشت',
                    hintStyle: TextStyle(color: kDim),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
          _divider(),
          _row(
            Icons.attach_file,
            'پیوست',
            TextButton(onPressed: _addFiles, child: const Text('افزودن')),
          ),
          if (attachments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var i = 0; i < attachments.length; i++)
                    _attachmentView(i),
                ],
              ),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('ذخیره', style: TextStyle(fontSize: 17)),
          ),
        ],
      ),
    );
  }
}
