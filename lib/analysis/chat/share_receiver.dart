// 안드로이드 공유로 받은 카톡 대화 (짝: android/.../MainActivity.kt · ShareInbox.kt, 채널 duedate/share)
// 웹 · iOS에서는 아무것도 안 함
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class ShareReceiver {
  static const _channel = MethodChannel('duedate/share');

  /// 공유로 받은 글자가 생길 때마다 onText 호출 (앱이 공유로 켜진 경우 포함)
  static Future<void> listen(void Function(String text) onText) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    // 준비된 뒤 새로 받은 것
    _channel.setMethodCallHandler((call) async {
      final text = call.arguments;
      if (call.method == 'sharedText' && text is String) onText(text);
    });

    // 준비 전에 받아서 맡겨 둔 것 (이 요청이 '준비됐음' 신호도 겸함, 그래서 핸들러를 먼저 등록)
    try {
      final text = await _channel.invokeMethod<String>('takeSharedText');
      if (text != null) onText(text);
    } catch (e) {
      debugPrint('공유받은 대화 읽기 실패: $e');
    }
  }
}
