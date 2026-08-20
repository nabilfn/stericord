import 'dart:convert';

import 'package:stericord_mobile/core/offline/offline_queue_database.dart';
import 'package:stericord_mobile/core/offline/queue_encryption.dart';
import 'package:stericord_mobile/core/offline/queued_operation.dart';
import 'package:stericord_mobile/core/offline/sync_state.dart';
import 'package:uuid/uuid.dart';

/// Local persistence for the sync queue: every read decrypts, every write
/// encrypts, so no caller outside this file ever handles the ciphertext or
/// the key directly.
class OfflineQueueRepository {
  final _encryption = QueueEncryption();
  static const _uuid = Uuid();

  /// Enqueues a write for later sync and returns its Local Operation ID
  /// (section 42) -- the same id doubles as the server-side idempotency key.
  ///
  /// Pass [id] when a direct (non-queued) attempt at this same operation was
  /// already made with that id before falling back to the queue here (e.g.
  /// a network call that timed out after the server may have already
  /// committed it) -- reusing the id lets the server's idempotency ledger
  /// recognize the eventual retry as the same operation instead of creating
  /// a duplicate record. Omit it for a capture that was never attempted
  /// online at all.
  Future<String> enqueue({
    required String rpcName,
    required Map<String, dynamic> payload,
    String? id,
  }) async {
    final db = await OfflineQueueDatabase.instance();
    final operationId = id ?? _uuid.v4();
    final encryptedPayload = await _encryption.encrypt(jsonEncode(payload));
    await db.insert('sync_queue', {
      'id': operationId,
      'rpc_name': rpcName,
      'payload_encrypted': encryptedPayload,
      'sync_state': SyncState.syncPending.name,
      'retry_count': 0,
      'last_error': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'last_attempted_at': null,
    });
    return operationId;
  }

  Future<List<QueuedOperation>> listPending() async {
    final db = await OfflineQueueDatabase.instance();
    // Includes syncState.syncing: if the app was killed mid-sync, a row can
    // be stuck there indefinitely with no other path back to a terminal
    // state. Retrying it is safe even if the original attempt actually
    // reached the server -- the client_operation_id makes the server call
    // idempotent, so a redundant retry just replays the same result.
    final rows = await db.query(
      'sync_queue',
      where: 'sync_state in (?, ?, ?)',
      whereArgs: [SyncState.syncPending.name, SyncState.syncFailed.name, SyncState.syncing.name],
      orderBy: 'created_at asc',
    );
    return Future.wait(rows.map(_rowToOperation));
  }

  Future<List<QueuedOperation>> listAll() async {
    final db = await OfflineQueueDatabase.instance();
    final rows = await db.query('sync_queue', orderBy: 'created_at desc');
    return Future.wait(rows.map(_rowToOperation));
  }

  Future<QueuedOperation> _rowToOperation(Map<String, Object?> row) async {
    final decrypted = await _encryption.decrypt(row['payload_encrypted'] as String);
    return QueuedOperation(
      id: row['id'] as String,
      rpcName: row['rpc_name'] as String,
      payload: jsonDecode(decrypted) as Map<String, dynamic>,
      syncState: SyncState.fromDb(row['sync_state'] as String),
      retryCount: row['retry_count'] as int,
      lastError: row['last_error'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      lastAttemptedAt: row['last_attempted_at'] == null
          ? null
          : DateTime.parse(row['last_attempted_at'] as String),
    );
  }

  Future<void> markSyncing(String id) async {
    final db = await OfflineQueueDatabase.instance();
    await db.update(
      'sync_queue',
      {
        'sync_state': SyncState.syncing.name,
        'last_attempted_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markSynced(String id) async {
    final db = await OfflineQueueDatabase.instance();
    // Synced rows are deleted, not just marked -- once the server has
    // acknowledged the write, there is nothing left to protect by keeping
    // an encrypted copy on the device, and an unbounded queue table would
    // otherwise grow forever on a device with spotty connectivity.
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markFailed(String id, String error, {required int retryCount}) async {
    final db = await OfflineQueueDatabase.instance();
    await db.update(
      'sync_queue',
      {
        'sync_state': SyncState.syncFailed.name,
        'retry_count': retryCount,
        'last_error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markConflict(String id, String error) async {
    final db = await OfflineQueueDatabase.instance();
    await db.update(
      'sync_queue',
      {'sync_state': SyncState.conflict.name, 'last_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
