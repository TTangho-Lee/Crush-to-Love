// 짝사랑 상대 목록 · 내 정보 저장용 SQLite DB (profile.db)
// 팀원 DB(mission/data)와 합치기 전까지 따로 쓰는 DB
// 합칠 때: crush · me 테이블을 팀원 DB로 옮기고, 미션 · 로드맵 테이블에 crush_id 칸을 두기
// 저장 위치: 앱은 기기 기본 DB 폴더의 profile.db, 웹은 브라우저 저장소(IndexedDB)
// 버전 1(온보딩 입력값 한 줄, profile 테이블)에서 열면 상대 한 명으로 옮기고 profile 테이블은 지움
import 'package:sqflite/sqflite.dart';

import '../../shared/models.dart';
import 'crush_store.dart';

/// 버전 1에서 옮긴 상대의 별명 (별명을 받기 전이라 없음, 설정에서 바꿀 수 있음)
const migratedNickname = '짝사랑 상대';

class ProfileDb implements CrushStorage {
  const ProfileDb();

  static Database? _db;

  /// 처음 한 번만 열고 이후엔 재사용
  static Future<Database> _open() async {
    return _db ??= await openDatabase(
      'profile.db',
      version: 2,
      onCreate: (db, version) => _createTables(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _migrateFromV1(db);
      },
    );
  }

  /// crush: 상대 한 명씩, me: 나 (용기 · 지금 상대 · 연결 안 하기로 한 카톡 이름), 항상 id 1
  /// 카톡 이름 목록은 줄바꿈으로 이어 붙여 저장 (카톡 이름엔 줄바꿈이 없음)
  static Future<void> _createTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE crush (
        id INTEGER PRIMARY KEY,
        nickname TEXT NOT NULL,
        d_day TEXT NOT NULL,
        reason TEXT NOT NULL,
        intimacy TEXT NOT NULL,
        meetings_per_week INTEGER NOT NULL,
        goal TEXT NOT NULL,
        chat_names TEXT NOT NULL DEFAULT '',
        archived INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE me (
        id INTEGER PRIMARY KEY,
        courage INTEGER NOT NULL,
        current_crush INTEGER,
        skipped_chat_names TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  /// 버전 1의 입력값 한 줄 → 상대 1명 + 나
  static Future<void> _migrateFromV1(Database db) async {
    await _createTables(db);
    final rows = await db.query('profile', where: 'id = ?', whereArgs: [1]);
    if (rows.isNotEmpty) {
      final row = rows.first;
      await db.insert('crush', {
        'id': 1,
        'nickname': migratedNickname,
        'd_day': row['d_day'],
        'reason': row['reason'],
        'intimacy': row['intimacy'],
        'meetings_per_week': row['meetings_per_week'],
        'goal': row['goal'],
      });
      await db.insert('me', {
        'id': 1,
        'courage': row['courage'],
        'current_crush': 1,
      });
    }
    await db.execute('DROP TABLE IF EXISTS profile');
  }

  /// 저장된 상대 목록 · 나, 아무것도 없으면 null
  @override
  Future<CrushSnapshot?> load() async {
    final db = await _open();
    final crushRows = await db.query('crush', orderBy: 'id');
    final meRows = await db.query('me', where: 'id = ?', whereArgs: [1]);
    if (crushRows.isEmpty && meRows.isEmpty) return null;

    final me = meRows.isEmpty ? null : meRows.first;
    return CrushSnapshot(
      crushes: [
        for (final row in crushRows)
          Crush(
            id: row['id'] as int,
            nickname: row['nickname'] as String,
            dDay: DateTime.parse(row['d_day'] as String),
            reason: row['reason'] as String,
            intimacy: Intimacy.values.byName(row['intimacy'] as String),
            meetingsPerWeek: row['meetings_per_week'] as int,
            goal: Goal.values.byName(row['goal'] as String),
            chatNames: _split(row['chat_names'] as String),
            archived: row['archived'] == 1,
          ),
      ],
      courage: me?['courage'] as int? ?? defaultCourage,
      currentId: me?['current_crush'] as int?,
      skippedChatNames: _split(me?['skipped_chat_names'] as String? ?? ''),
    );
  }

  /// 전체를 그대로 덮어씀 (상대는 몇 명뿐이라 통째로 저장)
  @override
  Future<void> save(CrushSnapshot snapshot) async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete('crush');
      for (final c in snapshot.crushes) {
        await txn.insert('crush', {
          'id': c.id,
          'nickname': c.nickname,
          'd_day': c.dDay.toIso8601String(),
          'reason': c.reason,
          'intimacy': c.intimacy.name,
          'meetings_per_week': c.meetingsPerWeek,
          'goal': c.goal.name,
          'chat_names': c.chatNames.join('\n'),
          'archived': c.archived ? 1 : 0,
        });
      }
      await txn.insert(
        'me',
        {
          'id': 1,
          'courage': snapshot.courage,
          'current_crush': snapshot.currentId,
          'skipped_chat_names': snapshot.skippedChatNames.join('\n'),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// 상대 · 나 모두 지우기 (설정 '데이터 전체 삭제')
  @override
  Future<void> clear() async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete('crush');
      await txn.delete('me');
    });
  }

  static List<String> _split(String joined) => [
        for (final name in joined.split('\n'))
          if (name.isNotEmpty) name,
      ];
}
