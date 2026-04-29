import "package:flutter/services.dart";
import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:flutter_timezone/flutter_timezone.dart";
import "package:timezone/data/latest.dart" as tz_data;
import "package:timezone/timezone.dart" as tz;
import "package:timetable_app/data/models/reminder_models.dart";
import "package:timetable_app/data/reminders/reminder_schedule.dart";
import "package:timetable_app/data/reminders/reminder_scheduler.dart";

class FlutterLocalNotificationsReminderScheduler implements ReminderScheduler {
  FlutterLocalNotificationsReminderScheduler({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = "class_reminders";
  static const String _channelName = "Class reminders";
  static const String _channelDescription =
      "Reminder notifications before scheduled timetable meetings.";

  static bool _timeZonesInitialized = false;

  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialized = false;

  @override
  Future<void> cancelAll() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }

  @override
  Future<ReminderPermissionStatus> getPermissionStatus() async {
    await _ensureInitialized();

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final enabled = await androidImplementation.areNotificationsEnabled();
      return enabled == true
          ? ReminderPermissionStatus.granted
          : ReminderPermissionStatus.denied;
    }

    final iosImplementation = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      final permissions = await iosImplementation.checkPermissions();
      return permissions?.isEnabled == true
          ? ReminderPermissionStatus.granted
          : ReminderPermissionStatus.denied;
    }

    return ReminderPermissionStatus.unsupported;
  }

  @override
  Future<ReminderPermissionStatus> requestPermissions() async {
    await _ensureInitialized();

    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      final granted =
          await androidImplementation.requestNotificationsPermission();
      if (granted != null) {
        return granted
            ? ReminderPermissionStatus.granted
            : ReminderPermissionStatus.denied;
      }

      return getPermissionStatus();
    }

    final iosImplementation = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      final granted = await iosImplementation.requestPermissions(
        alert: true,
        sound: true,
      );
      if (granted != null) {
        return granted
            ? ReminderPermissionStatus.granted
            : ReminderPermissionStatus.denied;
      }

      return getPermissionStatus();
    }

    return ReminderPermissionStatus.unsupported;
  }

  @override
  Future<void> replaceSchedule(List<ScheduledReminder> reminders) async {
    await _ensureInitialized();

    final permissionStatus = await getPermissionStatus();
    if (permissionStatus != ReminderPermissionStatus.granted) {
      await _plugin.cancelAll();
      return;
    }

    await _plugin.cancelAll();
    for (final reminder in reminders) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: reminder.title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.scheduledAt, tz.local),
        notificationDetails: _notificationDetails,
        payload: reminder.payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    if (!_timeZonesInitialized) {
      tz_data.initializeTimeZones();
      _timeZonesInitialized = true;
    }

    await _configureTimeZone();
    await _plugin.initialize(settings: _initializationSettings);
    _initialized = true;
  }

  Future<void> _configureTimeZone() async {
    try {
      final localTimeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTimeZone.identifier));
    } on MissingPluginException catch (_) {
      tz.setLocalLocation(tz.UTC);
    } on Exception catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  InitializationSettings get _initializationSettings {
    return const InitializationSettings(
      android: AndroidInitializationSettings("@mipmap/ic_launcher"),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
  }

  NotificationDetails get _notificationDetails {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        category: AndroidNotificationCategory.reminder,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }
}
