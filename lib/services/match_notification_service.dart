import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../data/app_database.dart';

class MatchNotificationService {
  MatchNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'user_hub_match_reminders',
    'Match reminders',
    channelDescription: 'Local reminders for match interests and usual DP activity times',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const NotificationDetails _details =
      NotificationDetails(android: _androidDetails);

  static Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (error) {
      throw StateError('Could not read the device time zone. Check Android date, time, and time-zone settings, then reopen the app. Details: $error');
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Requests Android's special exact-alarm access so contact reminders can
  /// fire at the selected device-local clock time, including while idle.
  static Future<bool> requestExactAlarmPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    var allowed = await android.canScheduleExactNotifications() ?? false;
    if (!allowed) {
      await android.requestExactAlarmsPermission();
      allowed = await android.canScheduleExactNotifications() ?? false;
    }
    return allowed;
  }

  /// Prefer exact alarms, but do not leave a saved reminder without an
  /// Android alarm when special exact-alarm access has not been granted.
  /// Android may deliver the fallback a little late while the device is idle.
  static Future<AndroidScheduleMode> _scheduledNotificationMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final exactAllowed =
        await android?.canScheduleExactNotifications() ?? false;
    return exactAllowed
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  static tz.TZDateTime _deviceWallClock(DateTime localDateTime) =>
      tz.TZDateTime(
        tz.local,
        localDateTime.year,
        localDateTime.month,
        localDateTime.day,
        localDateTime.hour,
        localDateTime.minute,
        localDateTime.second,
      );

  static Future<void> initializeAndRestore() async {
    await initialize();
    await rescheduleAllUpcoming();
  }

  static Future<void> showTestNotification() async {
    await initialize();
    await _plugin.show(
      2147483000,
      'User Hub notifications are working',
      'Your device can display local match reminders.',
      _details,
    );
  }

  static Future<void> rescheduleAllUpcoming() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final matchEnabled = prefs.getBool('match_reminders_enabled') == true;
    final dpTimeEnabled = prefs.getBool('dp_time_reminders_enabled') == true;

    // Only cancel notifications created by these two repeating systems.
    // Never use cancelAll here: it also deletes independently scheduled contact
    // reminders and can race with a reminder being saved from the UI.
    await _cancelTrackedNotifications(prefs, 'scheduled_match_notification_ids');
    await _cancelTrackedNotifications(prefs, 'scheduled_dp_notification_ids');
    final scheduledMatchIds = <String>[];
    final scheduledDpIds = <String>[];
    if (matchEnabled) {
      final matches = await AppDatabase.instance.getMatches();
      final interests = await AppDatabase.instance.getSportsInterests();
      final now = DateTime.now();

      for (final match in matches) {
        if ((match['status'] as String? ?? 'Upcoming') != 'Upcoming') continue;
        final startAt = DateTime.tryParse(match['start_at'] as String? ?? '');
        if (startAt == null || !startAt.isAfter(now)) continue;

        final matchingUsers = interests.where((interest) =>
            isEligibleForMatchAlerts(interest) &&
            isRelevantMatch(match: match, interest: interest)).toList();
        if (matchingUsers.isEmpty) continue;

        var reminderAt = startAt.subtract(const Duration(minutes: 30));
        if (!reminderAt.isAfter(now)) reminderAt = startAt;
        reminderAt = applyQuietHours(
          reminderAt,
          startAt,
          enabled: prefs.getBool('quiet_hours_enabled') ?? false,
          quietStartMinute: prefs.getInt('quiet_hours_start_minute') ?? 1320,
          quietEndMinute: prefs.getInt('quiet_hours_end_minute') ?? 420,
        ) ?? DateTime(0);
        if (reminderAt.year == 0) continue;
        final scheduled = tz.TZDateTime.from(reminderAt, tz.local);
        final names = matchingUsers
            .map((interest) => interest['user_name'] as String? ?? 'User')
            .toSet()
            .take(4)
            .join(', ');
        final extra = matchingUsers.length > 4
            ? ' +${matchingUsers.length - 4} more'
            : '';
        final matchId = match['id'] as int;
        await _plugin.zonedSchedule(
          matchId,
          'Match reminder: ${match["home_team"]} vs ${match["away_team"]}',
          'Matches saved interests for $names$extra · ${match["sport"]}',
          scheduled,
          _details,
          androidScheduleMode: await _scheduledNotificationMode(),
        );
        scheduledMatchIds.add(matchId.toString());
      }
    }

    if (dpTimeEnabled) {
      final patterns = await AppDatabase.instance.getUsualDpTimePatterns();
      final now = DateTime.now();
      for (final pattern in patterns) {
        final minute = (pattern['usual_minute'] as num?)?.round();
        if (minute == null || minute < 0 || minute >= 1440) continue;
        var reminderAt = nextDailyReminderTime(minute, now);
        reminderAt = applyQuietHours(
          reminderAt,
          reminderAt.add(const Duration(days: 1)),
          enabled: prefs.getBool('quiet_hours_enabled') ?? false,
          quietStartMinute: prefs.getInt('quiet_hours_start_minute') ?? 1320,
          quietEndMinute: prefs.getInt('quiet_hours_end_minute') ?? 420,
        ) ?? DateTime(0);
        if (reminderAt.year == 0) continue;
        final userId = pattern['user_id'] as int;
        await _plugin.zonedSchedule(
          1000000000 + userId,
          'Usual DP time: ${pattern['user_name']}',
          'DP activity has often been recorded around ${formatMinuteOfDay(minute)}. Review the profile and contact preferences before any contact.',
          tz.TZDateTime.from(reminderAt, tz.local),
          _details,
          androidScheduleMode: await _scheduledNotificationMode(),
          matchDateTimeComponents: DateTimeComponents.time,
        );
        scheduledDpIds.add((1000000000 + userId).toString());
      }
    }

    await prefs.setStringList('scheduled_match_notification_ids', scheduledMatchIds);
    await prefs.setStringList('scheduled_dp_notification_ids', scheduledDpIds);

    // Contact reminders are independent and are never cancelled by rebuilding
    // match or usual-DP notifications.
    await restoreContactReminders();
  }

  static Future<void> _cancelTrackedNotifications(
    SharedPreferences prefs,
    String key,
  ) async {
    final ids = prefs.getStringList(key) ?? const <String>[];
    for (final value in ids) {
      final id = int.tryParse(value);
      if (id != null) await _plugin.cancel(id);
    }
    await prefs.remove(key);
  }

  static int contactReminderNotificationId(int reminderId) => 1500000000 + reminderId;

  static Future<bool> scheduleContactReminder({
    required int reminderId,
    required String userName,
    required DateTime remindAt,
    String reason = '',
  }) async {
    await initialize();
    final now = DateTime.now();
    var firstAt = remindAt;
    if (!firstAt.isAfter(now)) {
      firstAt = DateTime(now.year, now.month, now.day, remindAt.hour, remindAt.minute);
      if (!firstAt.isAfter(now)) firstAt = firstAt.add(const Duration(days: 1));
    }
    final body = reason.trim().isEmpty
        ? 'Follow up with $userName. This reminder repeats daily until completed.'
        : '$reason · Follow up with $userName. Repeats daily until completed.';
    final scheduleMode = await _scheduledNotificationMode();
    await _plugin.zonedSchedule(
      contactReminderNotificationId(reminderId),
      'Contact reminder: $userName',
      body,
      _deviceWallClock(firstAt),
      _details,
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    return true;
  }

  static Future<void> cancelContactReminder(int reminderId) async {
    await initialize();
    await _plugin.cancel(contactReminderNotificationId(reminderId));
  }

  static Future<void> restoreContactReminders() async {
    final rows = await AppDatabase.instance.getContactReminders();
    for (final row in rows) {
      final id = row['id'] as int;
      final remindAt = DateTime.tryParse(row['remind_at'] as String? ?? '');
      if (remindAt == null) continue;
      await scheduleContactReminder(
        reminderId: id,
        userName: row['user_name'] as String? ?? 'User',
        remindAt: remindAt,
        reason: row['reason'] as String? ?? '',
      );
    }
  }

  static DateTime nextDailyReminderTime(int minuteOfDay, DateTime now) {
    final candidate = DateTime(
      now.year, now.month, now.day,
      minuteOfDay ~/ 60, minuteOfDay % 60,
    );
    return candidate.isAfter(now) ? candidate : candidate.add(const Duration(days: 1));
  }

  static String formatMinuteOfDay(int minuteOfDay) {
    final hour = minuteOfDay ~/ 60;
    final minute = minuteOfDay % 60;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Moves a reminder to the end of quiet hours when possible.
  /// Returns null when the quiet period would extend beyond match start.
  static DateTime? applyQuietHours(
    DateTime reminderAt,
    DateTime matchStart, {
    required bool enabled,
    int quietStartMinute = 1320,
    int quietEndMinute = 420,
  }) {
    if (!enabled || quietStartMinute == quietEndMinute) return reminderAt;
    final minute = reminderAt.hour * 60 + reminderAt.minute;
    final overnight = quietStartMinute > quietEndMinute;
    final inQuietHours = overnight
        ? minute >= quietStartMinute || minute < quietEndMinute
        : minute >= quietStartMinute && minute < quietEndMinute;
    if (!inQuietHours) return reminderAt;

    var end = DateTime(
      reminderAt.year,
      reminderAt.month,
      reminderAt.day,
      quietEndMinute ~/ 60,
      quietEndMinute % 60,
    );
    if (overnight && minute >= quietStartMinute) {
      end = end.add(const Duration(days: 1));
    }
    return end.isBefore(matchStart) ? end : null;
  }

  static bool isEligibleForMatchAlerts(Map<String, Object?> interest) =>
      (interest['match_alerts'] as int? ?? 0) == 1 &&
      (interest['do_not_contact'] as int? ?? 0) != 1;

  static bool isRelevantMatch({
    required Map<String, Object?> match,
    required Map<String, Object?> interest,
  }) {
    if ((interest['match_alerts'] as int? ?? 0) != 1) return false;
    final sport = _normal(match['sport']);
    final sports = _tokens(interest['sports']);
    final sportMatches = sports.isEmpty || sports.any((value) =>
        value == sport || sport.contains(value) || value.contains(sport));
    if (!sportMatches) return false;

    final home = _normal(match['home_team']);
    final away = _normal(match['away_team']);
    final competition = _normal(match['competition']);
    final teams = _tokens(interest['teams']);
    final competitions = _tokens(interest['competitions']);
    final teamMatches = teams.any((value) =>
        value.length >= 3 && (home.contains(value) || away.contains(value)));
    final competitionMatches = competitions.any((value) =>
        value.length >= 3 && competition.contains(value));
    return teamMatches || competitionMatches;
  }

  static List<String> _tokens(Object? value) => (value as String? ?? '')
      .split(RegExp(r'[,;|\n]'))
      .map(_normal)
      .where((item) => item.isNotEmpty)
      .toList();

  static String _normal(Object? value) =>
      (value as String? ?? '').trim().toLowerCase();
}
