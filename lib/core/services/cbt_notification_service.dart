import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../routes/app_routes.dart';

class CbtNotificationService {
  CbtNotificationService._();

  static final CbtNotificationService instance = CbtNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  GlobalKey<NavigatorState>? _navigatorKey;

  static const String _enabledKey = 'cbt_notifications_enabled';
  static const String _firstSetupDoneKey = 'cbt_notifications_first_setup_done';

  static const int _dailyCbtId = 9101;
  static const int _moodCheckInId = 9102;
  static const int _weeklyReviewId = 9103;

  String? _pendingPayload;

  Future<void> init({
    required GlobalKey<NavigatorState> navigatorKey,
  }) async {
    _navigatorKey = navigatorKey;

    await _initTimezone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final launchDetails =
        await _plugin.getNotificationAppLaunchDetails();

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNotificationPayload(response.payload);
      },
    );

    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingPayload =
          launchDetails?.notificationResponse?.payload ?? AppRoutes.cbt;
    }
  }

  Future<void> _initTimezone() async {
    tz_data.initializeTimeZones();

    try {
      final currentTimeZone = await FlutterTimezone.getLocalTimezone();
      final locationName = currentTimeZone.identifier;

      if (locationName.trim().isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(locationName));
      }
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<bool> requestPermission() async {
    final androidResult = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final iosResult = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    return androidResult ?? iosResult ?? true;
  }

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setupDefaultRemindersIfFirstTime() async {
    final prefs = await SharedPreferences.getInstance();

    final alreadyDone = prefs.getBool(_firstSetupDoneKey) ?? false;
    if (alreadyDone) return;

    await prefs.setBool(_firstSetupDoneKey, true);

    final allowed = await requestPermission();
    if (!allowed) {
      await prefs.setBool(_enabledKey, false);
      return;
    }

    await enableDefaultCbtReminders();
  }

  Future<void> enableDefaultCbtReminders() async {
    final prefs = await SharedPreferences.getInstance();

    final allowed = await requestPermission();
    if (!allowed) {
      await prefs.setBool(_enabledKey, false);
      return;
    }

    await prefs.setBool(_enabledKey, true);

    await cancelCbtReminders();

    await _scheduleDaily(
      id: _dailyCbtId,
      hour: 19,
      minute: 0,
      title: 'Your CBT activity is ready',
      body: 'Take a small moment for today’s wellness activity.',
      payload: AppRoutes.cbt,
    );

    await _scheduleDaily(
      id: _moodCheckInId,
      hour: 21,
      minute: 0,
      title: 'How are you feeling today?',
      body: 'Take a moment to check in with yourself.',
      payload: AppRoutes.moodCheckIn,
    );

    await _scheduleWeekly(
      id: _weeklyReviewId,
      weekday: DateTime.sunday,
      hour: 20,
      minute: 0,
      title: 'Your weekly reflection is ready',
      body: 'Look back on your week and notice your progress.',
      payload: AppRoutes.weeklyReview,
    );
  }

  Future<void> disableCbtReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
    await cancelCbtReminders();
  }

  Future<void> cancelCbtReminders() async {
    await _plugin.cancel(id: _dailyCbtId);
    await _plugin.cancel(id: _moodCheckInId);
    await _plugin.cancel(id: _weeklyReviewId);
  }

  Future<void> showTestNotification() async {
    await _plugin.show(
      id: 9999,
      title: 'EMLY reminder test',
      body: 'Your local notification system is working.',
      notificationDetails: _notificationDetails(),
      payload: AppRoutes.cbt,
    );
  }

  Future<void> handlePendingPayload() async {
    final payload = _pendingPayload;
    if (payload == null) return;

    _pendingPayload = null;
    _openRouteFromPayload(payload);
  }

  Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextDailyTime(hour, minute),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: payload,
    );
  }

  Future<void> _scheduleWeekly({
    required int id,
    required int weekday,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String payload,
  }) async {
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextWeeklyTime(weekday, hour, minute),
      notificationDetails: _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: payload,
    );
  }

  NotificationDetails _notificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      'emly_cbt_reminders',
      'CBT Reminders',
      channelDescription: 'Daily and weekly CBT activity reminders',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'EMLY CBT Reminder',
    );

    const iosDetails = DarwinNotificationDetails(
      threadIdentifier: 'emly_cbt_reminders',
    );

    return const NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  tz.TZDateTime _nextDailyTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);

    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  tz.TZDateTime _nextWeeklyTime(
    int weekday,
    int hour,
    int minute,
  ) {
    var scheduled = _nextDailyTime(hour, minute);

    while (scheduled.weekday != weekday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  void _handleNotificationPayload(String? payload) {
    final safePayload =
        payload == null || payload.trim().isEmpty ? AppRoutes.cbt : payload;

    _openRouteFromPayload(safePayload);
  }

  void _openRouteFromPayload(String payload) {
    final navigator = _navigatorKey?.currentState;

    if (navigator == null) {
      _pendingPayload = payload;
      return;
    }

    final route = _safeRoute(payload);

    navigator.pushNamed(route);
  }

  String _safeRoute(String payload) {
    switch (payload) {
      case AppRoutes.cbt:
      case AppRoutes.moodCheckIn:
      case AppRoutes.weeklyReview:
      case AppRoutes.gratitudeLog:
      case AppRoutes.sleepHabits:
      case AppRoutes.pleasantActivities:
      case AppRoutes.thoughtRecord:
      case AppRoutes.thinkingTraps:
      case AppRoutes.selfCompassion:
        return payload;
      default:
        return AppRoutes.cbt;
    }
  }
}