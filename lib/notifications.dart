import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

final notifications = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() async {
  WidgetsFlutterBinding.ensureInitialized();

  timezone_data.initializeTimeZones();

  final zone = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation(zone.identifier));

  const settings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  await notifications.initialize(settings);

  final android = notifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await android?.requestNotificationsPermission();
}

int notificationId(String id) {
  int value = 0;
  for (final c in id.codeUnits) {
    value = (value * 31 + c) & 0x7fffffff;
  }
  return value;
}

Future<void> scheduleTaskNotification(TaskItem task) async {
  final id = notificationId(task.id);

  try {
    await notifications.cancel(id);

    final minutes = task.reminder;
    if (task.done || task.notDone || minutes == null) return;

    final reminder = task.start.subtract(Duration(minutes: minutes));
    if (!reminder.isAfter(DateTime.now())) return;

    final body = minutes == 0
        ? '${task.title} الان شروع می‌شود'
        : '${task.title} تا $minutes دقیقه دیگر شروع می‌شود';

    final AndroidNotificationDetails details;

    if (task.reminderType == 'alarm') {
      details = AndroidNotificationDetails(
        'task_alarms',
        'هشدار کارها',
        channelDescription: 'هشدار قوی با صدا و لرزش برای کارهای مهم',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 700, 300, 700, 300, 700]),
      );
    } else {
      details = const AndroidNotificationDetails(
        'task_reminders',
        'یادآوری کارها',
        channelDescription: 'یادآوری قبل از شروع کار',
        importance: Importance.high,
        priority: Priority.high,
      );
    }

    await notifications.zonedSchedule(
      id,
      'یادآوری کار',
      body,
      tz.TZDateTime.from(reminder, tz.local),
      NotificationDetails(android: details),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  } catch (_) {
    // اگر زمان‌بندی اعلان خطا داد، برنامه نباید از کار بیفتد
  }
}
