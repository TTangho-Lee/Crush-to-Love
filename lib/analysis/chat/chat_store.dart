// 대화 분석 흐름의 데이터 (9번, 12번이 같이 씀)
// 화면에서는 ChatScope.of(context)로 꺼내 씀
import 'package:flutter/widgets.dart';

import 'chat_analyzer.dart';
import 'chat_stats.dart';

class ChatStore extends ChangeNotifier {
  ChatStats _stats = fakeChatStats;

  /// 마지막 분석 결과 (피그마 12번)
  ChatStats get stats => _stats;

  /// 카톡 대화 분석 (피그마 9번 '대화 분석하기')
  ChatStats analyze(String chatText, {String? myName}) {
    _stats = analyzeChat(chatText, myName: myName);
    notifyListeners();
    return _stats;
  }
}

/// 위젯 트리 어디서든 ChatScope.of(context)로 ChatStore를 꺼내기 위한 통로
class ChatScope extends InheritedNotifier<ChatStore> {
  const ChatScope({super.key, required ChatStore store, required super.child})
      : super(notifier: store);

  static ChatStore of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ChatScope>()!.notifier!;
  }
}
