import 'package:shamsi_date/shamsi_date.dart';

const months = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر',
  'مرداد', 'شهریور', 'مهر', 'آبان',
  'آذر', 'دی', 'بهمن', 'اسفند'
];

const weekdays = [
  'شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه',
  'چهارشنبه', 'پنجشنبه', 'جمعه'
];

const weekdaysShort = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String two(int v) => v.toString().padLeft(2, '0');

String dayKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

String timeText(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String dateText(DateTime d) {
  final j = d.toJalali();
  return '${j.day} ${months[j.month - 1]} ${j.year}';
}

String shortDateText(DateTime d) {
  final j = d.toJalali();
  return '${j.day} ${months[j.month - 1]}';
}

/// شروع هفته (شنبه) برای تاریخ داده‌شده
DateTime weekStartOf(DateTime d) {
  final wd = d.toJalali().weekDay; // شنبه = ۱
  return DateTime(d.year, d.month, d.day - (wd - 1));
}

class SubTask {
  SubTask({required this.title, this.done = false});

  String title;
  bool done;

  Map<String, dynamic> toJson() => {'title': title, 'done': done};

  factory SubTask.fromJson(Map<String, dynamic> j) => SubTask(
        title: (j['title'] ?? '').toString(),
        done: j['done'] == true,
      );
}

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.done = false,
    this.notDone = false,
    this.attachments = const [],
    this.category,
    this.subtasks = const [],
    this.notes = '',
    this.repeat = 'none', // none | daily | weekly | monthly
    this.reminder = 5, // دقیقه قبل از شروع؛ null یعنی بدون یادآور
    this.reminderType = 'standard', // standard | alarm
    this.flag = false,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool done;
  final bool notDone;
  final List<Map<String, dynamic>> attachments;
  final String? category;
  final List<SubTask> subtasks;
  final String notes;
  final String repeat;
  final int? reminder;
  final String reminderType;
  final bool flag;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'done': done,
        'notDone': notDone,
        'attachments': attachments,
        'category': category,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'notes': notes,
        'repeat': repeat,
        'reminder': reminder,
        'reminderType': reminderType,
        'flag': flag,
      };

  factory TaskItem.fromJson(Map<String, dynamic> j) => TaskItem(
        id: j['id'],
        title: j['title'],
        start: DateTime.parse(j['start']),
        end: DateTime.parse(j['end']),
        done: j['done'] ?? false,
        notDone: j['notDone'] ?? false,
        attachments: List<Map<String, dynamic>>.from(
          (j['attachments'] ?? []).map(
            (e) => Map<String, dynamic>.from(e),
          ),
        ),
        category: j['category'] as String?,
        subtasks: ((j['subtasks'] ?? []) as List)
            .map((e) => SubTask.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        notes: (j['notes'] ?? '').toString(),
        repeat: (j['repeat'] ?? 'none').toString(),
        // کارهای قدیمی که این کلید را ندارند، ۵ دقیقه قبل یادآوری داشتند
        reminder: j.containsKey('reminder') ? j['reminder'] as int? : 5,
        reminderType: (j['reminderType'] ?? 'standard').toString(),
        flag: j['flag'] == true,
      );

  TaskItem copy({
    String? title,
    DateTime? start,
    DateTime? end,
    bool? done,
    bool? notDone,
    List<SubTask>? subtasks,
    bool? flag,
    bool clearCategory = false,
  }) =>
      TaskItem(
        id: id,
        title: title ?? this.title,
        start: start ?? this.start,
        end: end ?? this.end,
        done: done ?? this.done,
        notDone: notDone ?? this.notDone,
        attachments: attachments,
        category: clearCategory ? null : category,
        subtasks: subtasks ?? this.subtasks,
        notes: notes,
        repeat: repeat,
        reminder: reminder,
        reminderType: reminderType,
        flag: flag ?? this.flag,
      );
}

/// ثبت انجام یک کار (برای آمار، نمودارها و نقشه سالانه)
class Completion {
  Completion({required this.taskId, this.category, required this.at});

  final String taskId;
  final String? category;
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'id': taskId,
        'cat': category,
        'at': at.toIso8601String(),
      };

  factory Completion.fromJson(Map<String, dynamic> j) => Completion(
        taskId: (j['id'] ?? '').toString(),
        category: j['cat'] as String?,
        at: DateTime.parse(j['at']),
      );
}

DateTime _shift(DateTime d, String repeat) {
  switch (repeat) {
    case 'daily':
      return DateTime(d.year, d.month, d.day + 1, d.hour, d.minute);
    case 'weekly':
      return DateTime(d.year, d.month, d.day + 7, d.hour, d.minute);
    case 'monthly':
      final j = d.toJalali();
      var y = j.year;
      var m = j.month + 1;
      if (m > 12) {
        m = 1;
        y++;
      }
      final len = Jalali(y, m, 1).monthLength;
      final day = j.day > len ? len : j.day;
      final g = Jalali(y, m, day).toDateTime();
      return DateTime(g.year, g.month, g.day, d.hour, d.minute);
    default:
      return d;
  }
}

/// زمان بعدی یک کار تکرارشونده (حداقل از امروز به بعد)
TaskItem nextOccurrence(TaskItem t) {
  final length = t.end.difference(t.start);
  var s = _shift(t.start, t.repeat);
  final today = dayOnly(DateTime.now());
  var guard = 0;
  while (dayOnly(s).isBefore(today) && guard < 800) {
    s = _shift(s, t.repeat);
    guard++;
  }
  return t.copy(
    start: s,
    end: s.add(length),
    done: false,
    notDone: false,
    subtasks: t.subtasks.map((e) => SubTask(title: e.title)).toList(),
  );
}
