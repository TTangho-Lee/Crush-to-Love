// 분석 기록 저장용 SQLite DB (숫자만, 대화 원문 없음)
// 저장 위치: 앱은 기기 기본 DB 폴더의 chat_history.db, 웹은 브라우저 저장소(IndexedDB)
// 웹용 설정(databaseFactory)은 main.dart에서 한 번
import 'package:sqflite/sqflite.dart';

import 'chat_record.dart';

abstract final class ChatHistoryDb {
  static Database? _db;

  static Future<Database> _open() async {
    return _db ??= await openDatabase(
      'chat_history.db',
      version: 1,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE chat_record (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          analyzed_at TEXT NOT NULL,
          partner TEXT NOT NULL,
          last_message_at TEXT NOT NULL,
          score INTEGER NOT NULL,
          reply_minutes REAL,
          warm_rate REAL NOT NULL,
          start_rate REAL NOT NULL,
          ask_back_rate REAL,
          message_count INTEGER NOT NULL
        )
      '''),
    );
  }

  /// 저장, 같은 상대의 같은 대화(마지막 메시지 시각이 같음)를 다시 분석하면 덮어씀
  static Future<void> save(ChatRecord record) async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete(
        'chat_record',
        where: 'partner = ? AND last_message_at = ?',
        whereArgs: [record.partner, record.lastMessageAt.toIso8601String()],
      );
      await txn.insert('chat_record', record.toRow());
    });
  }

  /// 상대의 기록 전체 (마지막 메시지 시각 순)
  static Future<List<ChatRecord>> load(String partner) async {
    final db = await _open();
    final rows = await db.query(
      'chat_record',
      where: 'partner = ?',
      whereArgs: [partner],
      orderBy: 'last_message_at',
    );
    return [for (final row in rows) ChatRecord.fromRow(row)];
  }

  /// 상대의 기록 지우기
  static Future<void> clear(String partner) async {
    final db = await _open();
    await db.delete('chat_record', where: 'partner = ?', whereArgs: [partner]);
  }

  /// 모든 상대의 기록 (분석 기록 모아보기, 마지막 메시지 시각 순)
  static Future<List<ChatRecord>> loadAll() async {
    final db = await _open();
    final rows = await db.query('chat_record', orderBy: 'last_message_at');
    return [for (final row in rows) ChatRecord.fromRow(row)];
  }

  /// 모두 지우기 (설정 '데이터 전체 삭제')
  static Future<void> clearAll() async {
    final db = await _open();
    await db.delete('chat_record');
  }
}
