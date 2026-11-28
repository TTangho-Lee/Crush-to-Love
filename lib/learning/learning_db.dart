// 학습 기록 저장용 SQLite DB (learning.db), 다른 DB와 따로
//   event: 보상 기록 하나씩 (분야 · 상대 · 행동 · 그때 문맥 · 보상 · 종류), 모델은 이 기록의 합
//     문맥은 숫자 · 이름만 JSON (대화 글자 없음), 취소는 같은 기록을 weight -1로 하나 더 (ref: 취소한 기록)
//   model: 분야별 A · b 캐시 (특징 버전 · 마지막 기록 번호가 맞을 때만 씀, 아니면 기록으로 다시 계산)
//   meta: 켜기/끄기 · 주차 판정 위치 같은 작은 값
//   상대를 지우면 그 상대 기록을 지우고 모델을 다시 계산 (learning_store.dart)
// 웹용 설정(databaseFactory)은 main.dart에서 한 번
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'linear_ts.dart';

/// 기록 종류
enum LearnKind {
  /// 미션 완료
  done,

  /// 주차가 끝날 때까지 안 함
  missed,

  /// 오늘의 미션 '↻'
  skip,

  /// 멘트 복사
  copy,

  /// 멘트 '↻' (복사 안 한 줄)
  shuffle,

  /// 다음 대화 분석 점수 변화 (늦게 오는 보상)
  chat,

  /// 성공 · 실패 결과
  outcome,

  /// 앞 기록 취소 (weight -1)
  cancel,
}

/// 보상 기록 하나
class LearnEvent {
  const LearnEvent({
    this.id,
    required this.domain,
    required this.crushId,
    required this.arm,
    required this.ctx,
    required this.reward,
    this.weight = 1,
    required this.kind,
    required this.at,
    this.ref,
  });

  /// 저장 번호 (저장 전엔 null)
  final int? id;

  /// 분야 ('mission' · 'line')
  final String domain;

  /// 상대 번호, 상대가 없으면 0
  final int crushId;

  /// 고른 것 (미션 id · 멘트 key)
  final String arm;

  /// 그때 문맥 + 고른 것의 특징 (숫자 · 이름만)
  final Map<String, Object?> ctx;
  final double reward;

  /// 1, 취소 기록은 -1
  final double weight;
  final LearnKind kind;
  final DateTime at;

  /// 취소 기록이면 취소한 기록 번호
  final int? ref;

  LearnEvent withId(int id) => LearnEvent(
        id: id,
        domain: domain,
        crushId: crushId,
        arm: arm,
        ctx: ctx,
        reward: reward,
        weight: weight,
        kind: kind,
        at: at,
        ref: ref,
      );

  Map<String, Object?> toRow() => {
        'domain': domain,
        'crush_id': crushId,
        'arm': arm,
        'ctx': jsonEncode(ctx),
        'reward': reward,
        'weight': weight,
        'kind': kind.name,
        'at': at.toIso8601String(),
        'ref': ref,
      };

  /// 모르는 종류면 null (버전이 바뀐 기록)
  static LearnEvent? fromRow(Map<String, Object?> row) {
    final kind = LearnKind.values.asNameMap()[row['kind']];
    if (kind == null) return null;
    return LearnEvent(
      id: row['id'] as int,
      domain: row['domain'] as String,
      crushId: row['crush_id'] as int,
      arm: row['arm'] as String,
      ctx: (jsonDecode(row['ctx'] as String) as Map).cast<String, Object?>(),
      reward: (row['reward'] as num).toDouble(),
      weight: (row['weight'] as num).toDouble(),
      kind: kind,
      at: DateTime.parse(row['at'] as String),
      ref: row['ref'] as int?,
    );
  }
}

/// 저장해 둔 모델 (캐시)
class SavedModel {
  const SavedModel({
    required this.version,
    required this.lastEvent,
    required this.model,
  });

  /// 특징 버전
  final int version;

  /// 마지막으로 반영한 기록 번호 (없으면 0)
  final int lastEvent;
  final LinearModel model;
}

/// 학습 저장소 (앱은 LearningDb, 테스트는 MemoryLearningStorage)
abstract interface class LearningStorage {
  Future<List<LearnEvent>> loadEvents();

  /// 저장하고 번호를 붙여 돌려줌
  Future<LearnEvent> addEvent(LearnEvent event);

  /// 이 상대 기록 모두 지우기
  Future<void> deleteCrush(int crushId);

  /// 기록 · 모델 모두 지우기 (meta는 남김)
  Future<void> clear();

  Future<SavedModel?> loadModel(String domain);
  Future<void> saveModel(String domain, SavedModel saved);
  Future<void> deleteModels();

  Future<Map<String, String>> loadMeta();

  /// value가 null이면 지움
  Future<void> setMeta(String key, String? value);
}

class LearningDb implements LearningStorage {
  const LearningDb();

  static Database? _db;

  /// 처음 한 번만 열고 이후엔 재사용
  static Future<Database> _open() async {
    return _db ??= await openDatabase(
      'learning.db',
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE event (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            domain TEXT NOT NULL,
            crush_id INTEGER NOT NULL,
            arm TEXT NOT NULL,
            ctx TEXT NOT NULL,
            reward REAL NOT NULL,
            weight REAL NOT NULL,
            kind TEXT NOT NULL,
            at TEXT NOT NULL,
            ref INTEGER
          )
        ''');
        await db.execute('CREATE INDEX event_crush ON event (crush_id)');
        await db.execute('''
          CREATE TABLE model (
            domain TEXT PRIMARY KEY,
            version INTEGER NOT NULL,
            last_event INTEGER NOT NULL,
            data TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
      },
    );
  }

  @override
  Future<List<LearnEvent>> loadEvents() async {
    final db = await _open();
    final rows = await db.query('event', orderBy: 'id');
    return [
      for (final row in rows) ?LearnEvent.fromRow(row),
    ];
  }

  @override
  Future<LearnEvent> addEvent(LearnEvent event) async {
    final db = await _open();
    final id = await db.insert('event', event.toRow());
    return event.withId(id);
  }

  @override
  Future<void> deleteCrush(int crushId) async {
    final db = await _open();
    await db.delete('event', where: 'crush_id = ?', whereArgs: [crushId]);
    await db.delete('model');
  }

  @override
  Future<void> clear() async {
    final db = await _open();
    await db.delete('event');
    await db.delete('model');
  }

  @override
  Future<SavedModel?> loadModel(String domain) async {
    final db = await _open();
    final rows =
        await db.query('model', where: 'domain = ?', whereArgs: [domain]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final model = LinearModel.fromJson(
      (jsonDecode(row['data'] as String) as Map).cast<String, Object?>(),
    );
    if (model == null) return null;
    return SavedModel(
      version: row['version'] as int,
      lastEvent: row['last_event'] as int,
      model: model,
    );
  }

  @override
  Future<void> saveModel(String domain, SavedModel saved) async {
    final db = await _open();
    await db.insert(
      'model',
      {
        'domain': domain,
        'version': saved.version,
        'last_event': saved.lastEvent,
        'data': jsonEncode(saved.model.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteModels() async {
    final db = await _open();
    await db.delete('model');
  }

  @override
  Future<Map<String, String>> loadMeta() async {
    final db = await _open();
    final rows = await db.query('meta');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  @override
  Future<void> setMeta(String key, String? value) async {
    final db = await _open();
    if (value == null) {
      await db.delete('meta', where: 'key = ?', whereArgs: [key]);
      return;
    }
    await db.insert(
      'meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

/// 메모리 저장소 (테스트 · DB를 못 열 때)
class MemoryLearningStorage implements LearningStorage {
  final events = <LearnEvent>[];
  final models = <String, SavedModel>{};
  final meta = <String, String>{};
  var _nextId = 1;

  @override
  Future<List<LearnEvent>> loadEvents() async => [...events];

  @override
  Future<LearnEvent> addEvent(LearnEvent event) async {
    final saved = event.withId(_nextId++);
    events.add(saved);
    return saved;
  }

  @override
  Future<void> deleteCrush(int crushId) async {
    events.removeWhere((e) => e.crushId == crushId);
    models.clear();
  }

  @override
  Future<void> clear() async {
    events.clear();
    models.clear();
  }

  @override
  Future<SavedModel?> loadModel(String domain) async => models[domain];

  @override
  Future<void> saveModel(String domain, SavedModel saved) async {
    models[domain] = SavedModel(
      version: saved.version,
      lastEvent: saved.lastEvent,
      model: saved.model.copy(),
    );
  }

  @override
  Future<void> deleteModels() async => models.clear();

  @override
  Future<Map<String, String>> loadMeta() async => {...meta};

  @override
  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      meta.remove(key);
    } else {
      meta[key] = value;
    }
  }
}
