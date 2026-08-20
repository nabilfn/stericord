import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens (and creates, on first run) the on-device sync queue database.
/// Kept separate from any app-level cache database: this one is written
/// from a background sync loop and must never be cleared as part of a
/// generic "clear cache" action, since an un-synced row here is the only
/// copy of a real clinical event until it reaches the server.
class OfflineQueueDatabase {
  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'stericord_offline_queue.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          create table sync_queue (
            id text primary key,
            rpc_name text not null,
            payload_encrypted text not null,
            sync_state text not null,
            retry_count integer not null default 0,
            last_error text,
            created_at text not null,
            last_attempted_at text
          )
        ''');
        await db.execute('create index idx_sync_queue_state on sync_queue(sync_state)');
      },
    );
    return _db!;
  }
}
