import 'package:stericord_mobile/core/offline/sync_state.dart';

/// One offline-captured write, queued for later sync (section 42's "Sync
/// Queue"). [id] is the client-generated "Local Operation ID" -- it doubles
/// as the idempotency key sent to the server, so a retried sync can never
/// create a duplicate record (see the `p_client_operation_id` parameter on
/// `record_point_of_use_verification`).
class QueuedOperation {
  final String id;
  final String rpcName;
  final Map<String, dynamic> payload;
  final SyncState syncState;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? lastAttemptedAt;

  const QueuedOperation({
    required this.id,
    required this.rpcName,
    required this.payload,
    required this.syncState,
    required this.retryCount,
    required this.lastError,
    required this.createdAt,
    required this.lastAttemptedAt,
  });

  QueuedOperation copyWith({
    SyncState? syncState,
    int? retryCount,
    String? lastError,
    DateTime? lastAttemptedAt,
  }) {
    return QueuedOperation(
      id: id,
      rpcName: rpcName,
      payload: payload,
      syncState: syncState ?? this.syncState,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError,
      createdAt: createdAt,
      lastAttemptedAt: lastAttemptedAt ?? this.lastAttemptedAt,
    );
  }
}
