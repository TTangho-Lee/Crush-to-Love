// 짝사랑 상대 목록 테스트 (flutter test test/crush_store_test.dart)
// 저장은 메모리 저장소로 (실제 DB 없이), 추가 · 전환 · 보관 · 지우기 · 카톡 이름 연결 · 분석한 대화 따라 바꾸기 · 결과 · 기록 묶기 확인
import 'package:flutter_test/flutter_test.dart';
import 'package:one_way_love/analysis/chat/history/chat_record.dart';
import 'package:one_way_love/analysis/chat/history/history_screen.dart';
import 'package:one_way_love/onboarding/data/crush_store.dart';
import 'package:one_way_love/shared/models.dart';

/// 메모리 저장소 (마지막으로 저장한 내용을 들고 있음)
class MemoryStorage implements CrushStorage {
  CrushSnapshot? saved;

  @override
  Future<CrushSnapshot?> load() async => saved;

  @override
  Future<void> save(CrushSnapshot snapshot) async => saved = snapshot;

  @override
  Future<void> clear() async => saved = null;
}

void main() {
  final dDay = DateTime(2026, 12, 20);

  Future<Crush> addCrush(CrushStore store, String name, {int courage = 50}) =>
      store.add(
        nickname: name,
        dDay: dDay,
        reason: '종강',
        intimacy: Intimacy.smallTalk,
        meetingsPerWeek: 2,
        goal: Goal.some,
        courage: courage,
      );

  test('새 상대는 지금 상대가 되고, 용기는 나에 대한 값으로 Profile에', () async {
    final store = CrushStore(storage: MemoryStorage());
    expect(store.current, isNull);
    expect(store.profile, isNull);

    final jimin = await addCrush(store, '  지민  ', courage: 70);
    expect(store.current?.id, jimin.id);
    expect(store.current?.nickname, '지민'); // 앞뒤 공백 정리
    expect(store.profile?.courage, 70);
    expect(store.profile?.reason, '종강');

    final minji = await addCrush(store, '민지', courage: 40);
    expect(store.current?.id, minji.id);
    expect(store.active.length, 2);
    expect(store.courage, 40); // 상대마다 따로가 아님
  });

  test('보관 · 꺼내기 · 지우기, 지금 상대가 빠지면 남은 상대로', () async {
    final store = CrushStore(storage: MemoryStorage());
    final jimin = await addCrush(store, '지민');
    final minji = await addCrush(store, '민지');

    await store.archive(minji.id); // 지금 상대를 보관
    expect(store.current?.id, jimin.id);
    expect(store.archived.single.id, minji.id);

    await store.restore(minji.id);
    expect(store.active.length, 2);
    expect(store.current?.id, jimin.id); // 꺼내도 지금 상대는 그대로

    await store.select(minji.id);
    await store.linkChatName(minji.id, '김민지');
    final names = await store.remove(minji.id);
    expect(names, ['김민지']); // 분석 기록도 지우라고 돌려줌
    expect(store.current?.id, jimin.id);
    expect(store.byId(minji.id), isNull);
  });

  test('카톡 이름은 한 상대에만, 연결하면 다시 안 물음', () async {
    final store = CrushStore(storage: MemoryStorage());
    final jimin = await addCrush(store, '지민');
    final minji = await addCrush(store, '민지');

    await store.skipChatName('김지민');
    expect(store.isSkipped('김지민'), isTrue);

    await store.linkChatName(jimin.id, '김지민');
    expect(store.crushForChatName('김지민')?.id, jimin.id);
    expect(store.isSkipped('김지민'), isFalse);

    // 다른 상대로 옮기면 앞 상대에서는 빠짐
    await store.linkChatName(minji.id, '김지민');
    expect(store.crushForChatName('김지민')?.id, minji.id);
    expect(store.byId(jimin.id)?.chatNames, isEmpty);

    await store.unlinkChatName(minji.id, '김지민');
    expect(store.crushForChatName('김지민'), isNull);
  });

  test('대화가 지금 상대 것인지 (데이트 가이드 반영)', () async {
    final store = CrushStore(storage: MemoryStorage());
    final jimin = await addCrush(store, '지민');
    // 상대가 한 명뿐이면 연결 전 대화도 지금 상대 것으로
    expect(store.chatBelongsToCurrent('누구'), isTrue);

    final minji = await addCrush(store, '민지');
    expect(store.chatBelongsToCurrent('누구'), isFalse);
    await store.linkChatName(jimin.id, '김지민');
    expect(store.chatBelongsToCurrent('김지민'), isFalse); // 지금은 민지
    await store.select(jimin.id);
    expect(store.chatBelongsToCurrent('김지민'), isTrue);
    expect(store.current?.id, isNot(minji.id));
  });

  test('분석한 대화에 맞춰 지금 상대 바꾸기 · 별명이 같으면 자동 연결', () async {
    final store = CrushStore(storage: MemoryStorage());
    final jimin = await addCrush(store, '지민');
    final seoyeon = await addCrush(store, '서연');
    await store.linkChatName(jimin.id, '김지민');
    await store.select(seoyeon.id);

    // 다른 상대에 연결된 이름 → 그 상대로
    await store.followChat('김지민');
    expect(store.current?.id, jimin.id);

    // 연결 전 · 별명과 같은 이름 → 연결하고 그 상대로
    await store.followChat('서연');
    expect(store.crushForChatName('서연')?.id, seoyeon.id);
    expect(store.current?.id, seoyeon.id);

    // 연결 전 · 모르는 이름 · '분석만' 이름 → 그대로
    await store.followChat('철수');
    await store.skipChatName('지민');
    await store.followChat('지민');
    expect(store.current?.id, seoyeon.id);
    expect(store.crushForChatName('철수'), isNull);
    expect(store.crushForChatName('지민'), isNull);

    // 보관한 상대에 연결된 이름 → 그대로
    await store.archive(jimin.id);
    await store.followChat('김지민');
    expect(store.current?.id, seoyeon.id);
  });

  test('저장했다 다시 불러오기, 전체 삭제', () async {
    final storage = MemoryStorage();
    final store = CrushStore(storage: storage);
    final jimin = await addCrush(store, '지민', courage: 80);
    await store.linkChatName(jimin.id, '김지민');
    await store.skipChatName('단톡방 친구');
    await store.setLaughStyle(LaughStyle.none);
    await store.update(store.current!.copyWith(speech: SpeechLevel.formal));

    final again = CrushStore(storage: storage);
    await again.load();
    expect(again.current?.nickname, '지민');
    expect(again.current?.chatNames, ['김지민']);
    expect(again.courage, 80);
    expect(again.isSkipped('단톡방 친구'), isTrue);
    expect(again.laughStyle, LaughStyle.none);
    expect(again.current?.speech, SpeechLevel.formal);

    await again.clearAll();
    expect(again.current, isNull);
    expect(storage.saved, isNull);
  });

  test('D-Day가 지나고 결과를 안 골랐으면 물어볼 상대, 고르면 저장', () async {
    final storage = MemoryStorage();
    final store = CrushStore(storage: storage);
    final jimin = await addCrush(store, '지민');
    final today = DateTime.now();
    await store.update(
      jimin.copyWith(dDay: DateTime(today.year, today.month, today.day + 10)),
    );
    expect(store.awaitingOutcome, isNull); // 아직 D-Day 전

    await store.update(
      store.current!.copyWith(
        dDay: DateTime(today.year, today.month, today.day - 2),
      ),
    );
    expect(store.awaitingOutcome?.id, jimin.id);

    await store.setOutcome(jimin.id, CrushOutcome.fail);
    expect(store.awaitingOutcome, isNull);
    final again = CrushStore(storage: storage);
    await again.load();
    expect(again.current?.outcome, CrushOutcome.fail);
  });

  test('사유 태그: 직접 입력한 사유는 기타로 표시', () {
    expect(reasonTagOf('종강'), '종강');
    expect(reasonTagOf('이사'), otherReason);
  });

  test('분석 기록 묶기: 상대별로 카톡 이름 기록을 합치고, 연결 안 된 이름은 따로', () async {
    final store = CrushStore(storage: MemoryStorage());
    final jimin = await addCrush(store, '지민');
    await store.linkChatName(jimin.id, '김지민');
    await store.linkChatName(jimin.id, '지민');

    ChatRecord record(String partner, int day, int score) => ChatRecord(
          analyzedAt: DateTime(2026, 11, day, 21),
          partner: partner,
          lastMessageAt: DateTime(2026, 11, day, 20),
          score: score,
          replyMinutes: null,
          warmRate: 0.5,
          startRate: 0.2,
          askBackRate: null,
          messageCount: 40,
        );

    final groups = groupHistory([
      record('김지민', 10, 50),
      record('철수', 11, 40),
      record('지민', 12, 64),
    ], store);
    expect(groups.length, 2);
    expect(groups.first.title, '지민');
    expect([for (final r in groups.first.records) r.score], [50, 64]);
    expect(groups.last.title, '철수');
    expect(groups.last.note, '연결 안 된 카톡 이름');
  });
}
