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
    channelDescription: 'Local reminders for matches related to saved user interests',
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
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
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

  static Future<void> initializeAndRestore() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('match_reminders_enabled') == true) {
      await rescheduleAllUpcoming();
    }
  }

  static Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
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
    if (prefs.getBool('match_reminders_enabled') != true) {
      await _plugin.cancelAll();
      return;
    }

    await _plugin.cancelAll();
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
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
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
