import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/*
    Messages on disk.

    Two problems this solves, both of which are about a bad connection rather
    than about speed for its own sake.

    Opening a thread used to show a spinner while a request went out over the
    tunnel — around 300ms on a good connection and unbounded on a bad one. The
    messages were already known; the app just had no memory of them. Now the
    thread paints instantly from disk and reconciles behind it, so the network
    decides how *fresh* the view is, never whether there is a view at all.

    And a message you have sent survives the app being closed before the
    network came back. Without somewhere local to keep it, an optimistic
    message exists only in RAM: it appears to send, the process dies, and it is
    gone with no record that the user ever wrote it.

    Deliberately not a mirror of the server. It holds what has been seen, keyed
    by the server's own ids, and the server remains the source of truth for
    anything the two disagree about.
*/
class MessageCache {
  MessageCache._();

  static final MessageCache instance = MessageCache._();

  static const int _version = 1;

  /// Local rows waiting on the server are given ids below this, so they sort
  /// after everything real and can never collide with a server id.
  static const int pendingIdBase = 1000000000;

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;

    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'kaya_messages.db'),
      version: _version,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE messages (
            id              INTEGER NOT NULL,
            conversation_id INTEGER NOT NULL,
            sender_id       INTEGER,
            sender_name     TEXT,
            message_text    TEXT,
            created_at      TEXT,
            is_read         INTEGER DEFAULT 0,
            read_at         TEXT,
            -- 'sent' once the server has it; 'pending' while in flight;
            -- 'failed' when the send did not land and can be retried.
            status          TEXT DEFAULT 'sent',
            PRIMARY KEY (conversation_id, id)
          )
        ''');

        // Every read is "this thread, in order", so the index matches it.
        await db.execute(
          'CREATE INDEX idx_messages_thread ON messages (conversation_id, id)',
        );
      },
    );

    return _db!;
  }

  /// Everything known for a thread, oldest first.
  Future<List<Map<String, dynamic>>> load(int conversationId) async {
    try {
      final db = await _database;
      final rows = await db.query(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
        orderBy: 'id ASC',
      );

      return rows.map(_toApiShape).toList();
    } catch (e) {
      // A cache miss must never be fatal — the network path still works.
      debugPrint('[cache] load failed: $e');

      return const [];
    }
  }

  /// The highest server id held for a thread, which is the polling cursor.
  ///
  /// Pending rows are excluded: their ids are local inventions, and asking the
  /// server for "everything after 1000000001" would return nothing forever.
  Future<int> latestId(int conversationId) async {
    try {
      final db = await _database;
      final rows = await db.rawQuery(
        'SELECT MAX(id) AS max_id FROM messages '
        'WHERE conversation_id = ? AND id < ?',
        [conversationId, pendingIdBase],
      );

      return (rows.first['max_id'] as int?) ?? 0;
    } catch (e) {
      debugPrint('[cache] latestId failed: $e');

      return 0;
    }
  }

  /// Writes messages, overwriting any row with the same id.
  Future<void> save(int conversationId, List<Map<String, dynamic>> messages) async {
    if (messages.isEmpty) return;

    try {
      final db = await _database;
      final batch = db.batch();

      for (final message in messages) {
        final id = message['id'];
        if (id is! int) continue;

        batch.insert(
          'messages',
          {
            'id': id,
            'conversation_id': conversationId,
            'sender_id': message['sender_id'],
            'sender_name': message['sender'] is Map
                ? (message['sender'] as Map)['name']
                : message['sender_name'],
            'message_text': message['message_text'],
            'created_at': message['created_at']?.toString(),
            'is_read': (message['is_read'] == true) ? 1 : 0,
            'read_at': message['read_at']?.toString(),
            'status': message['status'] ?? 'sent',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('[cache] save failed: $e');
    }
  }

  /// Swaps a local pending row for the real one the server returned.
  ///
  /// A delete and an insert rather than an update, because the primary key
  /// itself changes — the whole point is that the row stops being local.
  Future<void> replacePending(
    int conversationId,
    int pendingId,
    Map<String, dynamic> real,
  ) async {
    try {
      final db = await _database;
      await db.delete(
        'messages',
        where: 'conversation_id = ? AND id = ?',
        whereArgs: [conversationId, pendingId],
      );
      await save(conversationId, [
        {...real, 'status': 'sent'},
      ]);
    } catch (e) {
      debugPrint('[cache] replacePending failed: $e');
    }
  }

  /// Marks a pending row failed so the thread can offer a retry.
  Future<void> markFailed(int conversationId, int pendingId) async {
    try {
      final db = await _database;
      await db.update(
        'messages',
        {'status': 'failed'},
        where: 'conversation_id = ? AND id = ?',
        whereArgs: [conversationId, pendingId],
      );
    } catch (e) {
      debugPrint('[cache] markFailed failed: $e');
    }
  }

  Future<void> remove(int conversationId, int id) async {
    try {
      final db = await _database;
      await db.delete(
        'messages',
        where: 'conversation_id = ? AND id = ?',
        whereArgs: [conversationId, id],
      );
    } catch (e) {
      debugPrint('[cache] remove failed: $e');
    }
  }

  /// Wipes everything. Called on sign-out — one person's messages must not be
  /// readable from the next person's session on a shared handset.
  Future<void> clear() async {
    try {
      final db = await _database;
      await db.delete('messages');
    } catch (e) {
      debugPrint('[cache] clear failed: $e');
    }
  }

  /// Back into the shape the rest of the app already expects from the API, so
  /// nothing downstream needs to know whether a message came from the network
  /// or from disk.
  Map<String, dynamic> _toApiShape(Map<String, Object?> row) {
    return {
      'id': row['id'],
      'sender_id': row['sender_id'],
      'sender': {'name': row['sender_name']},
      'message_text': row['message_text'],
      'created_at': row['created_at'],
      'is_read': row['is_read'] == 1,
      'read_at': row['read_at'],
      'status': row['status'],
    };
  }
}
