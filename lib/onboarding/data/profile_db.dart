// 온보딩 입력값(Profile) 저장용 SQLite DB
// 팀원 DB(mission/data)와 합치기 전까지 따로 쓰는 DB
// 합칠 때: profile 테이블을 팀원 DB로 옮기고 이 파일 삭제
import 'package:sqflite/sqflite.dart';

import '../../shared/models.dart';

abstract final class ProfileDb {
  static Database? _db;

  /// 처음 한 번만 열고 이후엔 재사용
  /// 저장 위치: 앱은 기기 기본 DB 폴더의 profile.db, 웹은 브라우저 저장소(IndexedDB)
  static Future<Database> _open() async {
    return _db ??= await openDatabase(
      'profile.db',
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE profile (
          id INTEGER PRIMARY KEY,
          d_day TEXT NOT NULL,
          reason TEXT NOT NULL,
          intimacy TEXT NOT NULL,
          meetings_per_week INTEGER NOT NULL,
          courage INTEGER NOT NULL,
          goal TEXT NOT NULL
        )
      '''),
    );
  }

  /// 저장, 사용자는 한 명이라 id는 항상 1 (다시 저장하면 덮어씀)
  static Future<void> save(Profile profile) async {
    final db = await _open();
    await db.insert(
      'profile',
      {
        'id': 1,
        'd_day': profile.dDay.toIso8601String(),
        'reason': profile.reason,
        'intimacy': profile.intimacy.name,
        'meetings_per_week': profile.meetingsPerWeek,
        'courage': profile.courage,
        'goal': profile.goal.name,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 불러오기, 저장된 게 없으면 null
  static Future<Profile?> load() async {
    final db = await _open();
    final rows = await db.query('profile', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return null;

    final row = rows.first;
    return Profile(
      dDay: DateTime.parse(row['d_day'] as String),
      reason: row['reason'] as String,
      intimacy: Intimacy.values.byName(row['intimacy'] as String),
      meetingsPerWeek: row['meetings_per_week'] as int,
      courage: row['courage'] as int,
      goal: Goal.values.byName(row['goal'] as String),
    );
  }
}
