import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotiService {
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  static const String medTakenActionId = 'med_taken_action';
  static const String medForgotActionId = 'med_forgot_action';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initNotification() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    // Request notification permission
    final status = await Permission.notification.request();
    if (status.isDenied) {
      return;
    }
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    // Initialize notification channels with actions
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'daily_medicine_reminder',
      'Daily Medicine Reminder',
      description: 'Daily Medicine Reminder',
      importance: Importance.max,
      playSound: true,
    );

    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Initialize with action handling
    const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    var initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [        DarwinNotificationCategory(
          'med_reminder_category',
          actions: [
            DarwinNotificationAction.plain(
              medTakenActionId,
              'I TOOK THE MEDICATION',
              options: {
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              medForgotActionId,
              'I Forgot',
              options: {
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
        )
      ],
    );

    var initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    await notificationsPlugin.initialize(
      initSettings,      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.actionId == medTakenActionId) {
          // Handle medication taken action
          debugPrint('Medication taken confirmed');
          // You can add your logic here to mark medication as taken
        } else if (response.actionId == medForgotActionId) {
          // Handle medication forgot action
          debugPrint('Medication forgot confirmed');
          // You can add your logic here to handle missed medication
        }
      },
    );

    _isInitialized = true;
  }
  NotificationDetails _notificationDetails() {
    // Android actions
    const AndroidNotificationAction medTakenAction = AndroidNotificationAction(
      medTakenActionId,
      'I TOOK THE MEDICATION',
      cancelNotification: true, // This will dismiss the notification when tapped
    );

    const AndroidNotificationAction medForgotAction = AndroidNotificationAction(
      medForgotActionId,
      'I Forgot',
      cancelNotification: true, // This will dismiss the notification when tapped
    );

    // Android details
    const androidDetails = AndroidNotificationDetails(
      "daily_medicine_reminder",
      "Daily Medicine Reminder",
      channelDescription: "Daily Medicine Reminder",
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      playSound: true,
      ongoing: true, // Makes notification persistent
      autoCancel: false, // Notification won't auto dismiss
      actions: [medTakenAction, medForgotAction], // Add action buttons
    );

    // iOS details
    const iosDetails = DarwinNotificationDetails(
      sound: 'notification_sound.wav',
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
      categoryIdentifier: 'med_reminder_category',
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
    String? payload,
  }) async {
    await notificationsPlugin.show(
      id,
      title,
      body,
      _notificationDetails(),
      payload: payload,
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      if (!_isInitialized) await initNotification();
      final medName = body.replaceFirst('Time to take ', '');
      final id = '${medName}_${hour}_$minute'.hashCode;

      final scheduledDate = _nextInstanceOfTime(hour, minute);

      debugPrint("""
        Scheduling notification:
        - Now: ${tz.TZDateTime.now(tz.local)}
        - Scheduled: $scheduledDate
        - Timezone: ${tz.local.name}
        """);

      await notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        _notificationDetails(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: jsonEncode({
          'medicine': medName,
          'hour': hour,
          'minute': minute,
          'scheduled_time': scheduledDate.toIso8601String(),
        }),
      );
      debugPrint("Notification scheduled successfully for $hour:$minute");
    } catch (e) {
      debugPrint("Error scheduling notification: $e");
      rethrow;
    }
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  Future<void> cancelNotification(int id) async {
    await notificationsPlugin.cancelAll();
  }

  Future<List<PendingNotificationRequest>> getScheduledNotifications() async {
    return await notificationsPlugin.pendingNotificationRequests();
  }

  Future<List<TimeOfDay>> getScheduledTimesForMedicine(
      String medicineName) async {
    final notifications = await getScheduledNotifications();
    final medicineTimes = <TimeOfDay>[];

    for (var notification in notifications) {
      if (notification.body?.contains(medicineName) ?? false) {
        try {
          // Parse payload if it exists
          final payload = notification.payload != null
              ? jsonDecode(notification.payload!)
              : null;

          if (payload != null && payload is Map<String, dynamic>) {
            medicineTimes.add(TimeOfDay(
              hour: payload['hour'] ?? 0,
              minute: payload['minute'] ?? 0,
            ));
          }
        } catch (e) {
          print('Error parsing notification payload: $e');
        }
      }
    }
    return medicineTimes;
  }

  Future<List<Map<String, dynamic>>> getScheduledReminders(
      String medicineName) async {
    final notifications =
        await notificationsPlugin.pendingNotificationRequests();
    final reminders = <Map<String, dynamic>>[];

    for (final notification in notifications) {
      try {
        if (notification.payload != null) {
          final payload =
              jsonDecode(notification.payload!) as Map<String, dynamic>;
          if (payload['medicine'] == medicineName) {
            reminders.add({
              'id': notification.id,
              'hour': payload['hour'],
              'minute': payload['minute'],
            });
          }
        }
      } catch (e) {
        print('Error parsing notification payload: $e');
      }
    }
    return reminders;
  }

  Future<List<Map<String, dynamic>>> getAllRemindersForToday() async {
    final now = tz.TZDateTime.now(tz.local);
    final notifications =
        await notificationsPlugin.pendingNotificationRequests();
    final todayReminders = <Map<String, dynamic>>[];

    for (final notification in notifications) {
      try {
        if (notification.payload != null) {
          final payload =
              jsonDecode(notification.payload!) as Map<String, dynamic>;
          final hour = payload['hour'] as int;
          final minute = payload['minute'] as int;
          final medicine = payload['medicine'] as String;

          // Create a TZDateTime for today at the scheduled time
          final scheduledTime = tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day,
            hour,
            minute,
          );

          todayReminders.add({
            'id': notification.id,
            'medicine': medicine,
            'hour': hour,
            'minute': minute,
            'time': TimeOfDay(hour: hour, minute: minute),
            'scheduledTime': scheduledTime,
            'isPast': scheduledTime.isBefore(now),
          });
        }
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }

    // Sort by time (earliest first)
    todayReminders.sort((a, b) {
      final aTime = a['scheduledTime'] as tz.TZDateTime;
      final bTime = b['scheduledTime'] as tz.TZDateTime;
      return aTime.compareTo(bTime);
    });

    return todayReminders;
  }

  Future<List<Map<String, dynamic>>> getRemainingRemindersForToday() async {
    final now = tz.TZDateTime.now(tz.local);
    final allReminders = await getAllRemindersForToday();

    // Filter to only include reminders that are today and not in the past
    return allReminders.where((reminder) {
      final scheduledTime = reminder['scheduledTime'] as tz.TZDateTime;
      // Include if it's either in the future or within the last 30 minutes
      return scheduledTime.isAfter(now.subtract(const Duration(minutes: 30)));
    }).toList();
  }
}
