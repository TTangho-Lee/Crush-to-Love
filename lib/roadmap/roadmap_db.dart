// 미션 로드맵 저장용 SQLite DB (roadmap.db)
// 상대(crush_id)마다 한 줄: 만든 날 · 입력값 · 주차 목록(JSON 글자) · 자동 조정(shift · 이유)
// 버전 1에서 열면 자동 조정 칸만 더함
// 상대 정보는 profile.db, 여기는 상대별 로드맵만
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'roadmap_models.dart';

/// 로드맵 저장소 (앱은 RoadmapDb, 테스트는 메모리)
abstract interface class RoadmapStorage {
  Future<List<Roadmap>> loadAll();
  Future<void> save(Roadmap roadmap);
  Future<void> delete(int crushId);
}

class RoadmapDb implements RoadmapStorage {
  const RoadmapDb();

  static Database? _db;

  /// 처음 한 번만 열고 이후엔 재사용
  static Future<Database> _open() async {
    return _db ??= await openDatabase(
      'roadmap.db',
      version: 2,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE roadmap (
          crush_id INTEGER PRIMARY KEY,
          started_at TEXT NOT NULL,
          plan_key TEXT NOT NULL,
          weeks TEXT NOT NULL,
          shift INTEGER NOT NULL DEFAULT 0,
          note TEXT,
          note_at TEXT
        )
      '''),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE roadmap ADD COLUMN shift INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute('ALTER TABLE roadmap ADD COLUMN note TEXT');
          await db.execute('ALTER TABLE roadmap ADD COLUMN note_at TEXT');
        }
      },
    );
  }

  @override
  Future<List<Roadmap>> loadAll() async {
    final db = await _open();
    final rows = await db.query('roadmap', orderBy: 'crush_id');
    return [
      for (final row in rows)
        Roadmap(
          crushId: row['crush_id'] as int,
          startedAt: DateTime.parse(row['started_at'] as String),
          planKey: row['plan_key'] as String,
          weeks: [
            for (final w in jsonDecode(row['weeks'] as String) as List)
              RoadmapWeek.fromJson((w as Map).cast<String, Object?>()),
          ],
          shift: row['shift'] as int? ?? 0,
          note: row['note'] as String?,
          noteAt: DateTime.tryParse(row['note_at'] as String? ?? ''),
        ),
    ];
  }

  @override
  Future<void> save(Roadmap roadmap) async {
    final db = await _open();
    await db.insert(
      'roadmap',
      {
        'crush_id': roadmap.crushId,
        'started_at': roadmap.startedAt.toIso8601String(),
        'plan_key': roadmap.planKey,
        'weeks': jsonEncode([for (final w in roadmap.weeks) w.toJson()]),
        'shift': roadmap.shift,
        'note': roadmap.note,
        'note_at': roadmap.noteAt?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> delete(int crushId) async {
    final db = await _open();
    await db.delete('roadmap', where: 'crush_id = ?', whereArgs: [crushId]);
  }
}
