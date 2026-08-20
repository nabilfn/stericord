/// Master prompt section 42's offline synchronization states, in the order
/// a queued operation actually moves through them:
/// captured while offline -> [localOnly] -> connectivity check queues it ->
/// [syncPending] -> a drain cycle picks it up -> [syncing] -> server
/// acknowledges -> [synced]. [syncFailed] and [conflict] are the two ways a
/// [syncing] attempt can end besides success -- failed is retryable
/// (network drop, 5xx), conflict is not (the server rejected the operation
/// itself, e.g. the pack was already used by someone else in the meantime).
enum SyncState {
  localOnly,
  syncPending,
  syncing,
  synced,
  syncFailed,
  conflict;

  static SyncState fromDb(String value) => SyncState.values.firstWhere(
        (s) => s.name == value,
        orElse: () => SyncState.syncFailed,
      );
}
