// 대화 분석 흐름의 데이터 (9번, 12번이 같이 씀)
// 화면에서는 ChatScope.of(context)로 꺼내 씀
// 붙여넣은 대화 원문은 보관하지 않음, 분석 숫자만 기록 DB에 저장 (history/chat_history_db.dart)
import 'package:flutter/widgets.dart';

import 'chat_analyzer.dart';
import 'chat_stats.dart';
import 'history/chat_history_db.dart';
import 'history/chat_record.dart';

class ChatStore extends ChangeNotifier {
  ChatStats _stats = fakeChatStats;
  ChatComparison? _comparison = fakeComparison;
  bool _firstAnalysis = false;
  String? _pendingText;

  /// 마지막 분석 결과 (피그마 12번)
  ChatStats get stats => _stats;

  /// 같은 상대의 지난 분석과 비교 (12번 '지난 분석과 비교'), 지난 기록이 없거나 불러오는 중이면 null
  ChatComparison? get comparison => _comparison;

  /// 이 상대를 처음 분석했으면 true (비교할 기록 없음)
  bool get isFirstAnalysis => _firstAnalysis;

  /// 안드로이드 공유로 받고 아직 입력칸에 안 넣은 대화가 있으면 true
  bool get hasPendingText => _pendingText != null;

  /// 카톡 대화 분석 (피그마 9번 '대화 분석하기'), range: 지금부터 이만큼 전까지
  /// 분석할 수 없으면 ChatAnalysisError (이유 문구 포함), 그땐 이전 결과 유지
  /// partnerName: 짝사랑 상대 (단톡방은 꼭 필요)
  /// 결과는 바로 바꾸고, 숫자 기록 · 지난 기록 비교는 뒤에서 (끝나면 12번 화면이 다시 그려짐)
  ChatStats analyze(
    ParsedChat chat, {
    String? myName,
    String? partnerName,
    Duration range = defaultRange,
  }) {
    final stats = analyzeParsed(
      chat,
      myName: myName,
      partnerName: partnerName,
      range: range,
    );
    _stats = stats;
    _comparison = null;
    _firstAnalysis = false;
    notifyListeners();
    _recordHistory(stats);
    return stats;
  }

  /// 숫자 기록 저장 + 같은 상대의 지난 기록과 비교
  Future<void> _recordHistory(ChatStats stats) async {
    final record = stats.record;
    if (record == null) return;
    try {
      // 이번 대화보다 앞선 기록만 비교 대상 (같은 대화를 다시 분석하면 save가 덮어씀)
      final previous = [
        for (final r in await ChatHistoryDb.load(record.partner))
          if (r.lastMessageAt.isBefore(record.lastMessageAt)) r,
      ];
      await ChatHistoryDb.save(record);
      if (!identical(_stats, stats)) return; // 그새 다른 분석 · 예시로 바뀜
      _comparison = compareWithHistory(previous, record);
      _firstAnalysis = previous.isEmpty;
      notifyListeners();
    } catch (_) {
      // DB를 못 열어도(웹 설정 전 등) 분석 결과는 그대로, 비교 카드만 안 보임
    }
  }

  /// 지금 결과의 상대 분석 기록 모두 지우기 (12번 '분석 기록 지우기')
  Future<void> clearHistory() async {
    final partner = _stats.record?.partner;
    if (partner == null) return;
    await ChatHistoryDb.clear(partner);
    _comparison = null;
    _firstAnalysis = false;
    notifyListeners();
  }

  /// 예시 결과로 바꾸기 (피그마 9번 '예시 결과 보기')
  void showExample() {
    _stats = fakeChatStats;
    _comparison = fakeComparison;
    _firstAnalysis = false;
    notifyListeners();
  }

  /// 안드로이드 공유로 받은 대화 맡기기, 9번 화면이 꺼내서 입력칸에
  void receiveSharedText(String text) {
    _pendingText = text;
    notifyListeners();
  }

  /// 맡긴 대화 꺼내기 (꺼내면 비움)
  String? takePendingText() {
    final text = _pendingText;
    _pendingText = null;
    return text;
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
