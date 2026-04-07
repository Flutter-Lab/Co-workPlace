import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages local (on-device) push notifications.
///
/// Call [initialize] once at app start.
/// Users can toggle the daily reminder via [scheduleDailyReminder] /
/// [cancelDailyReminder].
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _kDailyReminderId = 1;
  static const _kChannelId = 'daily_reminder';
  static const _kChannelName = 'Daily Reminder';
  static const _kChannelDesc =
      'Reminds you to complete tasks before the day resets at midnight.';

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(settings: initSettings);
  }

  /// Requests OS-level notification permission.
  /// Returns true if granted, false otherwise.
  static Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  /// Schedules a daily notification at 23:00 local device time.
  /// Safe to call repeatedly — cancels any previous daily reminder first.
  static Future<void> scheduleDailyReminder() async {
    await cancelDailyReminder();

    const notifDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: _kChannelDesc,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.periodicallyShowWithDuration(
      id: _kDailyReminderId,
      title: '⏰ Tasks pending!',
      body: "Day resets at midnight — don't forget to complete your tasks.",
      repeatDurationInterval: const Duration(hours: 24),
      notificationDetails: notifDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static Future<void> cancelDailyReminder() async {
    await _plugin.cancel(id: _kDailyReminderId);
  }

  static Future<bool> isDailyReminderActive() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.any((n) => n.id == _kDailyReminderId);
  }
}
