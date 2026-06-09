import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../models/message.dart';

class DatabaseService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'lanchat.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            sender_nickname TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            content TEXT NOT NULL,
            mime_type TEXT,
            timestamp INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_messages_timestamp ON messages(timestamp DESC)'
        );
      },
    );
  }

  static Future<void> saveMessage(Message msg) async {
    final db = await database;
    try {
      await db.insert('messages', {
        'id': msg.id,
        'type': msg.type.name,
        'sender_nickname': msg.senderNickname,
        'sender_id': msg.senderId,
        'content': msg.content,
        'mime_type': msg.mimeType,
        'timestamp': msg.timestamp.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } catch (_) {}
  }

  static Future<List<Message>> loadRecent({int limit = 200}) async {
    final db = await database;
    final rows = await db.query(
      'messages',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.reversed.map((r) {
      return Message(
        id: r['id'] as String,
        type: MessageType.values.firstWhere(
          (t) => t.name == r['type'],
          orElse: () => MessageType.text,
        ),
        senderNickname: r['sender_nickname'] as String,
        senderId: r['sender_id'] as String,
        content: r['content'] as String,
        mimeType: r['mime_type'] as String?,
        timestamp: DateTime.fromMillisecondsSinceEpoch(r['timestamp'] as int),
      );
    }).toList();
  }

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
