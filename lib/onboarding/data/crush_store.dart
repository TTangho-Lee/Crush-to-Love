// 짝사랑 상대 목록 · 내 정보 (여러 명을 담고, 화면은 '지금 상대' 한 명씩)
// 화면에서는 CrushScope.of(context)로 꺼내 씀 (머리글 '지민 ▾', 설정, 온보딩, 대화 분석, 데이트)
//   상대별: 별명 · D-Day · 사유 · 사이 · 목표 · 만남 빈도 · 연결한 카톡 이름 · 보관 여부 · 말 높이 · 결과
//   나: 용기 배터리 · 지금 상대 · 연결 안 하기로 한 카톡 이름 · 예시 멘트 웃음 표현
// 바뀔 때마다 통째로 저장 (CrushStorage, 앱은 ProfileDb), 저장이 안 돼도 앱은 그대로 (Run 창에 출력)
// 미션 흐름(팀원 MissionStore)에는 main.dart가 지금 상대 Profile을 넘김
import 'package:flutter/widgets.dart';

import '../../shared/models.dart';
import 'profile_db.dart';

/// 용기 배터리 기본값 (온보딩 슬라이더 처음 위치)
const defaultCourage = 50;

/// 별명 최대 글자 수
const nicknameMaxLength = 12;

/// 저장할 내용 전체
class CrushSnapshot {
  const CrushSnapshot({
    required this.crushes,
    required this.courage,
    this.currentId,
    this.skippedChatNames = const [],
    this.laughStyle = LaughStyle.auto,
  });

  final List<Crush> crushes;
  final int courage;
  final int? currentId;
  final List<String> skippedChatNames;
  final LaughStyle laughStyle;
}

/// 상대 목록 저장소 (앱은 ProfileDb, 테스트는 메모리)
abstract interface class CrushStorage {
  Future<CrushSnapshot?> load();
  Future<void> save(CrushSnapshot snapshot);
  Future<void> clear();
}

class CrushStore extends ChangeNotifier {
  CrushStore({CrushStorage? storage}) : _storage = storage ?? const ProfileDb();

  final CrushStorage _storage;
  List<Crush> _crushes = const [];
  int _courage = defaultCourage;
  int? _currentId;
  List<String> _skipped = const [];
  LaughStyle _laughStyle = LaughStyle.auto;

  // ---------- 읽기 ----------

  /// 전체 (보관 포함, 추가한 순)
  List<Crush> get all => _crushes;

  /// 보관하지 않은 상대
  List<Crush> get active => [for (final c in _crushes) if (!c.archived) c];

  /// 보관한 상대
  List<Crush> get archived => [for (final c in _crushes) if (c.archived) c];

  /// 지금 상대, 아직 없으면 null (온보딩 전 · 전체 삭제 뒤)
  Crush? get current {
    for (final c in _crushes) {
      if (c.id == _currentId && !c.archived) return c;
    }
    return null;
  }

  /// 내 용기 배터리 0 ~ 100
  int get courage => _courage;

  /// 예시 멘트 웃음 표현 (설정 '나')
  LaughStyle get laughStyle => _laughStyle;

  /// 지금 상대 + 내 용기 (미션 흐름 · 데이트 가이드용), 지금 상대가 없으면 null
  Profile? get profile => current?.toProfile(_courage);

  Crush? byId(int id) {
    for (final c in _crushes) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// 이 카톡 이름을 연결한 상대 (보관 포함), 없으면 null
  Crush? crushForChatName(String chatName) {
    for (final c in _crushes) {
      if (c.chatNames.contains(chatName)) return c;
    }
    return null;
  }

  /// '분석만'을 골라 연결을 묻지 않기로 한 카톡 이름이면 true
  bool isSkipped(String chatName) => _skipped.contains(chatName);

  /// 이 카톡 이름의 대화가 지금 상대 대화인지 (데이트 가이드에 반영할지)
  /// 연결돼 있으면 그 상대가 지금 상대인지, 연결 전이면 상대가 한 명뿐일 때만
  bool chatBelongsToCurrent(String chatName) {
    final linked = crushForChatName(chatName);
    if (linked != null) return linked.id == current?.id;
    return current != null && active.length == 1;
  }

  // ---------- 바꾸기 ----------

  /// 저장된 목록 불러오기 (앱을 켤 때 한 번)
  Future<void> load() async {
    final snapshot = await _storage.load();
    if (snapshot == null) return;
    _crushes = snapshot.crushes;
    _courage = snapshot.courage;
    _currentId = snapshot.currentId;
    _skipped = snapshot.skippedChatNames;
    _laughStyle = snapshot.laughStyle;
    // 지금 상대가 없거나 보관됐으면 남은 상대 중 첫 번째
    if (current == null) _currentId = active.isEmpty ? null : active.first.id;
    notifyListeners();
  }

  /// 새 상대 추가 후 지금 상대로 (온보딩 완료), 더해진 상대를 돌려줌
  Future<Crush> add({
    required String nickname,
    required DateTime dDay,
    required String reason,
    required Intimacy intimacy,
    required int meetingsPerWeek,
    required Goal goal,
    required int courage,
    List<String> chatNames = const [],
  }) async {
    final id = _crushes.fold(0, (max, c) => c.id > max ? c.id : max) + 1;
    final crush = Crush(
      id: id,
      nickname: _cleanName(nickname),
      dDay: dDay,
      reason: reason,
      intimacy: intimacy,
      meetingsPerWeek: meetingsPerWeek,
      goal: goal,
    );
    // 연결할 카톡 이름은 다른 상대에게서 떼어 옴
    _crushes = [
      for (final c in _crushes)
        c.copyWith(chatNames: [
          for (final n in c.chatNames)
            if (!chatNames.contains(n)) n,
        ]),
      crush.copyWith(chatNames: chatNames),
    ];
    _skipped = [for (final n in _skipped) if (!chatNames.contains(n)) n];
    _courage = courage;
    _currentId = id;
    await _changed();
    return byId(id)!;
  }

  /// 상대 정보 고치기 (설정 · 온보딩 다시 하기), id가 같은 상대를 바꿈
  Future<void> update(Crush crush) async {
    _crushes = [
      for (final c in _crushes)
        c.id == crush.id ? crush.copyWith(nickname: _cleanName(crush.nickname)) : c,
    ];
    await _changed();
  }

  /// 용기 배터리 바꾸기
  Future<void> setCourage(int courage) async {
    _courage = courage.clamp(0, 100);
    await _changed();
  }

  /// 짝사랑 결과 정하기 (피그마 17번)
  Future<void> setOutcome(int id, CrushOutcome outcome) async {
    _crushes = [
      for (final c in _crushes) c.id == id ? c.copyWith(outcome: outcome) : c,
    ];
    await _changed();
  }

  /// D-Day가 지났는데 결과를 아직 안 고른 지금 상대, 없으면 null (피그마 17번을 띄울지)
  Crush? get awaitingOutcome {
    final c = current;
    if (c == null || c.outcome != null) return null;
    return daysUntil(c.dDay) < 0 ? c : null;
  }

  Future<void> setLaughStyle(LaughStyle style) async {
    _laughStyle = style;
    await _changed();
  }

  /// 지금 상대 바꾸기 (보관한 상대면 꺼내서)
  Future<void> select(int id) async {
    if (byId(id) == null) return;
    _setArchived(id, false);
    _currentId = id;
    await _changed();
  }

  /// 보관하기, 지금 상대였으면 남은 상대 중 첫 번째로
  Future<void> archive(int id) async {
    _setArchived(id, true);
    _fixCurrent();
    await _changed();
  }

  /// 보관한 상대 꺼내기 (지금 상대는 그대로)
  Future<void> restore(int id) async {
    _setArchived(id, false);
    _fixCurrent();
    await _changed();
  }

  /// 지우기, 그 상대에게 연결했던 카톡 이름을 돌려줌 (대화 분석 기록도 지우라고)
  Future<List<String>> remove(int id) async {
    final crush = byId(id);
    if (crush == null) return const [];
    _crushes = [for (final c in _crushes) if (c.id != id) c];
    _fixCurrent();
    await _changed();
    return crush.chatNames;
  }

  /// 카톡 이름을 이 상대로 연결 (다른 상대에 연결돼 있었으면 옮김)
  Future<void> linkChatName(int id, String chatName) async {
    _crushes = [
      for (final c in _crushes)
        c.copyWith(chatNames: [
          for (final n in c.chatNames)
            if (n != chatName) n,
          if (c.id == id) chatName,
        ]),
    ];
    _skipped = [for (final n in _skipped) if (n != chatName) n];
    await _changed();
  }

  /// 연결 끊기
  Future<void> unlinkChatName(int id, String chatName) async {
    _crushes = [
      for (final c in _crushes)
        c.id == id
            ? c.copyWith(chatNames: [
                for (final n in c.chatNames)
                  if (n != chatName) n,
              ])
            : c,
    ];
    await _changed();
  }

  /// 대화 분석 직후 그 대화의 카톡 이름에 맞춰 지금 상대 정하기
  ///   다른 상대에 연결된 이름이면 그 상대로 바꿈 (보관한 상대면 그대로)
  ///   아직 연결 전이고 별명이 카톡 이름과 똑같은 상대가 한 명뿐이면 묻지 않고 연결
  Future<void> followChat(String chatName) async {
    var crush = crushForChatName(chatName);
    if (crush == null && !isSkipped(chatName)) {
      final same = [
        for (final c in active)
          if (c.nickname == chatName.trim()) c,
      ];
      if (same.length == 1) {
        crush = same.single;
        await linkChatName(crush.id, chatName);
      }
    }
    if (crush == null || crush.archived || crush.id == _currentId) return;
    await select(crush.id);
  }

  /// '분석만': 이 카톡 이름은 다시 묻지 않음
  Future<void> skipChatName(String chatName) async {
    if (_skipped.contains(chatName)) return;
    _skipped = [..._skipped, chatName];
    await _changed();
  }

  /// 전부 지우기 (테스트 · 나중에 '데이터 전체 삭제'를 다시 둘 때)
  Future<void> clearAll() async {
    _crushes = const [];
    _courage = defaultCourage;
    _currentId = null;
    _skipped = const [];
    _laughStyle = LaughStyle.auto;
    notifyListeners();
    try {
      await _storage.clear();
    } catch (e) {
      debugPrint('상대 목록 지우기 실패: $e');
    }
  }

  // ---------- 안쪽 ----------

  void _setArchived(int id, bool archived) {
    _crushes = [
      for (final c in _crushes) c.id == id ? c.copyWith(archived: archived) : c,
    ];
  }

  /// 지금 상대가 없어졌으면 남은 상대 중 첫 번째 (없으면 null)
  void _fixCurrent() {
    if (current != null) return;
    final left = active;
    _currentId = left.isEmpty ? null : left.first.id;
  }

  String _cleanName(String name) {
    final trimmed = name.trim();
    return trimmed.length > nicknameMaxLength
        ? trimmed.substring(0, nicknameMaxLength)
        : trimmed;
  }

  /// 화면 먼저 바꾸고 저장
  Future<void> _changed() async {
    notifyListeners();
    try {
      await _storage.save(
        CrushSnapshot(
          crushes: _crushes,
          courage: _courage,
          currentId: _currentId,
          skippedChatNames: _skipped,
          laughStyle: _laughStyle,
        ),
      );
    } catch (e) {
      debugPrint('상대 목록 저장 실패: $e');
    }
  }
}

/// 위젯 트리 어디서든 CrushScope.of(context)로 CrushStore를 꺼내기 위한 통로
class CrushScope extends InheritedNotifier<CrushStore> {
  const CrushScope({super.key, required CrushStore store, required super.child})
      : super(notifier: store);

  /// 화면을 그릴 때 (바뀌면 다시 그림)
  static CrushStore of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CrushScope>()!.notifier!;
  }

  /// 없을 수도 있을 때 (테스트 · 예시 화면)
  static CrushStore? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CrushScope>()?.notifier;
  }

  /// 버튼 누를 때처럼 그리지 않고 읽기만 할 때
  static CrushStore? read(BuildContext context) {
    return context.getInheritedWidgetOfExactType<CrushScope>()?.notifier;
  }
}
