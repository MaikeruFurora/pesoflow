import 'dart:io';
import 'dart:math';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local-only notification service. All scheduling happens through Android's
/// AlarmManager (via flutter_local_notifications), so reminders fire even when
/// the app is closed or backgrounded.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelDebt = AndroidNotificationChannel(
    'pesoflow_debt',
    'Debt reminders',
    description: 'Due-soon and overdue alerts for your debts.',
    importance: Importance.high,
  );

  static const _channelGoal = AndroidNotificationChannel(
    'pesoflow_goal',
    'Goal progress',
    description: 'Celebrations when your ipon goals hit milestones.',
    importance: Importance.high,
  );

  static const _channelAsset = AndroidNotificationChannel(
    'pesoflow_asset',
    'Net worth milestones',
    description: 'Motivational pings as your total assets grow.',
    importance: Importance.defaultImportance,
  );

  static const _channelInactivity = AndroidNotificationChannel(
    'pesoflow_inactivity',
    'Tracking reminders',
    description: 'Gentle nudges when you haven\'t logged in a while.',
    importance: Importance.high,
  );

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // Default to local timezone via DateTime offset; if more precision is
    // needed later, flutter_timezone could resolve the actual IANA name.
    try {
      final now = DateTime.now();
      final offsetMinutes = now.timeZoneOffset.inMinutes;
      final tzName =
          offsetMinutes == 480 ? 'Asia/Manila' : 'Etc/UTC';
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(init);

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(_channelDebt);
        await android.createNotificationChannel(_channelGoal);
        await android.createNotificationChannel(_channelAsset);
        await android.createNotificationChannel(_channelInactivity);
        await android.requestNotificationsPermission();
        await android.requestExactAlarmsPermission();
      }
    }
    _ready = true;
  }

  // ---------------------------------------------------------------- Goal --
  /// Fired immediately when a deposit crosses a milestone (25 / 50 / 75 / 100%).
  Future<void> celebrateGoalMilestone({
    required String goalId,
    required String goalName,
    required String emoji,
    required int percent,
  }) async {
    await init();
    final body = _goalCopy(goalName, percent);
    final id = _stableId('goal-$goalId-$percent');
    await _plugin.show(
      id,
      '$emoji $percent% of the way there!',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelGoal.id,
          _channelGoal.name,
          channelDescription: _channelGoal.description,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  String _goalCopy(String name, int percent) {
    if (percent >= 100) {
      return 'Tagumpay! 🎉 You hit your "$name" goal. Time to enjoy what you saved for.';
    }
    if (percent >= 75) {
      return 'Three quarters done with "$name". The finish line is right there — keep going!';
    }
    if (percent >= 50) {
      return 'Halfway to "$name"! Every peso you tuck away makes the next half feel closer. Tuloy lang.';
    }
    // 25
    return 'A quarter into "$name" already. Strong start — small consistent saves win.';
  }

  // -------------------------------------------------------------- Assets --
  /// Fired immediately when total assets cross a major ₱ threshold.
  Future<void> celebrateAssetMilestone({
    required int peso,
  }) async {
    await init();
    final pretty = _formatPeso(peso);
    final body = _assetCopy(peso);
    final id = _stableId('asset-$peso');
    await _plugin.show(
      id,
      '🎯 You crossed $pretty in total assets!',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelAsset.id,
          _channelAsset.name,
          channelDescription: _channelAsset.description,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  String _formatPeso(int p) {
    if (p >= 1000000) return '₱${(p / 1000000).toStringAsFixed(1)}M';
    if (p >= 1000) return '₱${(p / 1000).round()}K';
    return '₱$p';
  }

  String _assetCopy(int peso) {
    if (peso >= 1000000) {
      return 'Millionaire energy. 🇵🇭 Your future self is cheering from the cheap seats.';
    }
    if (peso >= 100000) {
      return 'Six figures. Every centavo of effort is starting to compound. Don\'t stop now.';
    }
    if (peso >= 50000) {
      return 'Halfway to ₱100K — momentum is the hardest part and you\'ve got it.';
    }
    if (peso >= 30000) {
      return '₱30K secured. You\'ve out-saved a lot of people your age — keep stacking.';
    }
    if (peso >= 20000) {
      return '₱20K in the bank. The habit is sticking — that\'s what most people never figure out.';
    }
    // 10k
    return 'Your first ₱10K. The first one is the hardest — the next ones come faster.';
  }

  // --------------------------------------------------------------- Debt --
  /// Schedules two notifications for a single debt:
  /// 1) "Due soon" — 1 day before the due date at 9 AM.
  /// 2) "Overdue" — at 9 AM on the day AFTER the due date if still unpaid.
  Future<void> scheduleDebtReminders({
    required String debtId,
    required String party,
    required bool iOwe,
    required DateTime? dueDate,
    required double remaining,
  }) async {
    await init();
    await cancelDebtReminders(debtId);
    if (dueDate == null || remaining <= 0) return;

    final dueSoon = tz.TZDateTime(
        tz.local, dueDate.year, dueDate.month, dueDate.day, 9)
        .subtract(const Duration(days: 1));
    final overdue = tz.TZDateTime(
        tz.local, dueDate.year, dueDate.month, dueDate.day, 9)
        .add(const Duration(days: 1));
    final now = tz.TZDateTime.now(tz.local);

    final soonTitle = iOwe
        ? '⏰ Payment due tomorrow — $party'
        : '⏰ $party owes you tomorrow';
    final soonBody = iOwe
        ? 'Heads up: your debt to $party is due tomorrow. Schedule the transfer today para wala kang gulo.'
        : 'Friendly reminder: $party\'s payment to you is due tomorrow. Drop them a polite ping if needed.';

    final overTitle = iOwe
        ? '🚨 Overdue: pay $party'
        : '🚨 $party is overdue';
    final overBody = iOwe
        ? 'This debt is past due. Settle it today if you can — late payments compound stress.'
        : 'Still no payment from $party. Time for a follow-up message.';

    if (dueSoon.isAfter(now)) {
      await _plugin.zonedSchedule(
        _stableId('debt-soon-$debtId'),
        soonTitle,
        soonBody,
        dueSoon,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelDebt.id,
            _channelDebt.name,
            channelDescription: _channelDebt.description,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(soonBody),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    if (overdue.isAfter(now)) {
      await _plugin.zonedSchedule(
        _stableId('debt-over-$debtId'),
        overTitle,
        overBody,
        overdue,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelDebt.id,
            _channelDebt.name,
            channelDescription: _channelDebt.description,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(overBody),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelDebtReminders(String debtId) async {
    await init();
    await _plugin.cancel(_stableId('debt-soon-$debtId'));
    await _plugin.cancel(_stableId('debt-over-$debtId'));
  }

  // --------------------------------------------------------- Inactivity --
  /// Schedules three motivational reminders firing 1, 3, and 7 days after the
  /// user's last activity (at 9 AM local). Any existing inactivity reminders
  /// are cancelled first, so this is safe to call on every activity.
  Future<void> scheduleInactivityReminders({
    required DateTime lastActivity,
  }) async {
    await init();
    await cancelInactivityReminders();

    final base = tz.TZDateTime(
      tz.local,
      lastActivity.year,
      lastActivity.month,
      lastActivity.day,
      9,
    );
    final oneDay = base.add(const Duration(days: 1));
    final threeDay = base.add(const Duration(days: 3));
    final sevenDay = base.add(const Duration(days: 7));
    final now = tz.TZDateTime.now(tz.local);

    const oneDayTitle = '☕ Kumusta? Got something to log today?';
    const oneDayBody =
        'A day already? 👋 30 seconds is all it takes — log today\'s coffee, jeepney, or kanin. Tracking daily is how saving becomes a habit.';

    const threeDayTitle = '💸 Miss kita! Where did the pesos go?';
    const threeDayBody =
        'It\'s been 3 days since your last entry. Got an expense or income to record? Tap to log it now — small habits, big ipon.';

    const sevenDayTitle = '🐷 Your piggy bank misses you';
    const sevenDayBody =
        'A whole week na walang record! Tracking your money is the easiest way to find ₱500+ in "where did it go?" mystery spending. Open PesoFlow and catch up. 💪';

    if (oneDay.isAfter(now)) {
      await _plugin.zonedSchedule(
        _stableId('inactivity-1d'),
        oneDayTitle,
        oneDayBody,
        oneDay,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelInactivity.id,
            _channelInactivity.name,
            channelDescription: _channelInactivity.description,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: const BigTextStyleInformation(oneDayBody),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    if (threeDay.isAfter(now)) {
      await _plugin.zonedSchedule(
        _stableId('inactivity-3d'),
        threeDayTitle,
        threeDayBody,
        threeDay,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelInactivity.id,
            _channelInactivity.name,
            channelDescription: _channelInactivity.description,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: const BigTextStyleInformation(threeDayBody),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
    if (sevenDay.isAfter(now)) {
      await _plugin.zonedSchedule(
        _stableId('inactivity-7d'),
        sevenDayTitle,
        sevenDayBody,
        sevenDay,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelInactivity.id,
            _channelInactivity.name,
            channelDescription: _channelInactivity.description,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: const BigTextStyleInformation(sevenDayBody),
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelInactivityReminders() async {
    await init();
    await _plugin.cancel(_stableId('inactivity-1d'));
    await _plugin.cancel(_stableId('inactivity-3d'));
    await _plugin.cancel(_stableId('inactivity-7d'));
  }

  // ID space: flutter_local_notifications uses int IDs. Hash a string into
  // 31 bits so it fits and stays stable across runs.
  int _stableId(String key) {
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7FFFFFFF;
    }
    if (h == 0) h = key.length + 1;
    return h % pow(2, 30).toInt();
  }
}
