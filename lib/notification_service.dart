import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Service for scheduling health record and medicine reminders.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _healthRecordChannelId = 'health_record_reminders';
  static const String _medicineChannelId = 'medicine_reminders';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    // Use flutter_timezone to get the real local timezone name (e.g. "Asia/Kuala_Lumpur")
    // This fixes DST issues and sub-hour offsets that broke scheduled alarms.
    try {
      final String timezoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneName));
    } catch (_) {
      // Fallback: derive from offset (less accurate but better than nothing)
      final offsetHours = DateTime.now().timeZoneOffset.inHours;
      final locationName =
          offsetHours >= 0 ? 'Etc/GMT-$offsetHours' : 'Etc/GMT+${-offsetHours}';
      try {
        tz.setLocalLocation(tz.getLocation(locationName));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
    );
    const initSettings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true);

    _createChannels();
    _initialized = true;
  }

  void _createChannels() {
    if (Platform.isAndroid) {
      _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _healthRecordChannelId,
              'Health Record Reminders',
              description: 'Reminders to take HR, HRV or BP measurements now!',
              importance: Importance.high,
            ),
          );
      _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _medicineChannelId,
              'Medicine Reminders',
              description: 'Reminders to take your BP medication!',
              importance: Importance.high,
            ),
          );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Could navigate to measurement screen if app is open
  }

  /// Schedule a daily reminder at [hour] and [minute].
  /// [id] must be unique. Use positive for health, negative for medicine.
  Future<void> scheduleDaily(
      int id, int hour, int minute, String title, String body,
      {bool isMedicine = false}) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextDailyTime(hour, minute),
      NotificationDetails(
        android: AndroidNotificationDetails(
          isMedicine ? _medicineChannelId : _healthRecordChannelId,
          isMedicine ? 'Medicine Reminders' : 'Health Record Reminders',
          channelDescription: isMedicine
              ? 'Take your medication'
              : 'Take your health measurement',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextDailyTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    // If the time has already passed today (including a 5-second buffer),
    // schedule for tomorrow instead.
    if (!scheduled.isAfter(now.add(const Duration(seconds: 5)))) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Schedule a weekly reminder. [dayOfWeek] 1=Mon, 7=Sun.
  Future<void> scheduleWeekly(
      int id, int hour, int minute, int dayOfWeek, String title, String body,
      {bool isMedicine = false}) async {
    final scheduled = _nextWeeklyTime(hour, minute, dayOfWeek);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isMedicine ? _medicineChannelId : _healthRecordChannelId,
          isMedicine ? 'Medicine Reminders' : 'Health Record Reminders',
          channelDescription: isMedicine
              ? 'Take your medication'
              : 'Take your health measurement',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextWeeklyTime(int hour, int minute, int dayOfWeek) {
    var now = tz.TZDateTime.now(tz.local);
    // Dart DateTime: weekday 1=Mon, 7=Sun
    var daysToAdd = dayOfWeek - now.weekday;
    if (daysToAdd < 0) daysToAdd += 7;
    if (daysToAdd == 0) {
      var s =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!s.isAfter(now.add(const Duration(seconds: 5)))) daysToAdd = 7;
    }
    final target = now.add(Duration(days: daysToAdd));
    return tz.TZDateTime(
        tz.local, target.year, target.month, target.day, hour, minute);
  }

  /// Ensure notification permission is granted. Call before scheduling.
  Future<bool> ensurePermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
      return granted ?? false;
    }
    return true;
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
