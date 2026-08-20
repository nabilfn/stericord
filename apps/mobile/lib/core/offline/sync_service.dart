import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stericord_mobile/core/network/supabase_client_provider.dart';
import 'package:stericord_mobile/core/offline/offline_queue_repository.dart';
import 'package:stericord_mobile/core/offline/queued_operation.dart';
import 'package:stericord_mobile/core/offline/sync_state.dart';

/// Drains the offline queue (section 42: "Sync Queue -> Internet Restored ->
/// Server Synchronization -> Server Acknowledgement -> Local State
/// Reconciled") whenever connectivity returns, and exposes a stream so UI
/// can show a live per-record sync status instead of a black box.
///
/// Retries use capped exponential backoff (doubling up to [_maxBackoffShift]
/// attempts, then holding steady) and never give up entirely -- master
/// prompt section 42's "Never silently discard failed uploads" means a
/// [SyncState.syncFailed] row keeps retrying at a bounded rate forever,
/// staying visible for a human to review, rather than ever being deleted
/// or excluded from future drain cycles.
class SyncService {
  static const _maxBackoffShift = 6; // caps backoff at 2^6 = 64s between attempts

  final OfflineQueueRepository _repository;
  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _draining = false;

  final _statusController = StreamController<void>.broadcast();
  Stream<void> get onQueueChanged => _statusController.stream;

  SyncService({OfflineQueueRepository? repository}) : _repository = repository ?? OfflineQueueRepository();

  void start() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        drainQueue();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }

  Future<void> drainQueue() async {
    if (_draining) return;
    _draining = true;
    try {
      final pending = await _repository.listPending();
      for (final operation in pending) {
        await _syncOne(operation);
      }
    } finally {
      _draining = false;
      _statusController.add(null);
    }
  }

  Future<void> _syncOne(QueuedOperation operation) async {
    final lastAttempt = operation.lastAttemptedAt;
    if (operation.retryCount > 0 && lastAttempt != null) {
      final backoff = Duration(seconds: (1 << operation.retryCount.clamp(0, _maxBackoffShift)));
      if (DateTime.now().toUtc().difference(lastAttempt) < backoff) return;
    }

    await _repository.markSyncing(operation.id);
    try {
      await SupabaseClientProvider.client.rpc(operation.rpcName, params: {
        ...operation.payload,
        'p_client_operation_id': operation.id,
      });
      await _repository.markSynced(operation.id);
    } on PostgrestException catch (e) {
      // A Postgres-level error means the server actually evaluated the
      // request and rejected it (e.g. "Pack is not eligible for use" --
      // someone else already used or quarantined it since this was queued).
      // Retrying an identical payload would just fail identically, so this
      // needs a human to look at it, not another automatic attempt.
      await _repository.markConflict(operation.id, e.message);
    } catch (e) {
      // Anything else (timeout, no connection, DNS failure) is assumed
      // transient and retried with backoff, uncapped in attempt count.
      await _repository.markFailed(operation.id, e.toString(), retryCount: operation.retryCount + 1);
    }
  }
}
