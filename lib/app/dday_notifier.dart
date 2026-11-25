// D-Day 알림: D-3 · D-1 저녁 8시에 기기 알림 (flutter_local_notifications)
// 안드로이드 · 아이폰만 (웹 · PC는 예약 알림이 안 돼서 건너뜀)
// 지금 상대의 D-Day로, 지금 상대 · D-Day가 바뀔 때마다 다시 예약 (main.dart, 이전 예약은 지우고, 이미 지난 날은 건너뜀)
// 알림 글자에는 상대 이름을 넣지 않음 (잠금 화면에 보일 수 있어서)
// 알림이 안 돼도 앱은 그대로 (실패는 Run 창에만 출력)
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../shared/models.dart';

/// 알림 시각 (저녁 8시)
const reminderHour = 20;

/// 예약할 알림 (D-Day 며칠 전, 알림 id)
const _reminders = [(daysBefore: 3, id: 3001), (daysBefore: 1, id: 3002)];

abstract final class DdayNotifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'dday',
      'D-Day 알림',
      channelDescription: 'D-Day 3일 전 · 전날 저녁 알림',
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// 예약 알림이 되는 기기
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// 처음 한 번만 준비 (권한은 schedule에서 물음)
  static Future<bool> _init() async {
    if (_ready) return true;
    if (!supported) return false;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
    return true;
  }

  /// 알림 권한 묻기 (안드로이드 13 이상 · 아이폰, 이미 정했으면 다시 안 뜸)
  static Future<void> _requestPermission() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  /// D-Day 알림 다시 예약 (main.dart가 지금 상대가 바뀔 때 부름)
  static Future<void> schedule(Profile profile, {DateTime? now}) async {
    try {
      if (!await _init()) return;
      await _requestPermission();
      for (final r in _reminders) {
        await _plugin.cancel(id: r.id);
      }
      final at = now ?? DateTime.now();
      for (final r in _reminders) {
        final when = reminderTime(profile.dDay, r.daysBefore);
        if (!when.isAfter(at)) continue;
        await _plugin.zonedSchedule(
          id: r.id,
          // 기기 시각 그대로 (한 번만 울리는 알림이라 UTC로 바꿔 넘겨도 같은 순간)
          scheduledDate: tz.TZDateTime.from(when, tz.UTC),
          notificationDetails: _details,
          // 정확한 알람 권한 없이 (몇 분 늦을 수 있음)
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'DueDate · D-${r.daysBefore}',
          body: reminderText(profile.reason, r.daysBefore),
        );
      }
    } catch (e) {
      debugPrint('D-Day 알림 예약 실패: $e');
    }
  }

  /// 예약한 알림 모두 취소 (설정 '데이터 전체 삭제')
  static Future<void> cancelAll() async {
    try {
      if (!await _init()) return;
      for (final r in _reminders) {
        await _plugin.cancel(id: r.id);
      }
    } catch (e) {
      debugPrint('D-Day 알림 취소 실패: $e');
    }
  }
}

/// D-Day daysBefore일 전 저녁 8시
DateTime reminderTime(DateTime dDay, int daysBefore) =>
    DateTime(dDay.year, dDay.month, dDay.day - daysBefore, reminderHour);

/// 알림 글자 ('종강까지 3일 남았어요. …', '내일이 종강이에요. …'), 사유가 '기타'면 'D-Day'
String reminderText(String reason, int daysBefore) {
  final name = reason == '기타' ? 'D-Day' : reason;
  if (daysBefore == 1) {
    return '내일이 $name${_copula(name)}. 오늘 한마디 건네 볼까요?';
  }
  return '$name까지 $daysBefore일 남았어요. 오늘 미션 하나 해볼까요?';
}

/// 받침 있으면 '이에요', 없으면 '예요' (한글이 아니면 '예요')
String _copula(String word) {
  if (word.isEmpty) return '예요';
  final code = word.codeUnitAt(word.length - 1);
  final hangul = code >= 0xAC00 && code <= 0xD7A3;
  return hangul && (code - 0xAC00) % 28 != 0 ? '이에요' : '예요';
}
