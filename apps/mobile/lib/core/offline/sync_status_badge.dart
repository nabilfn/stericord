import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/offline/offline_queue_repository.dart';
import 'package:stericord_mobile/core/offline/sync_service.dart';
import 'package:stericord_mobile/core/offline/sync_state.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';

/// Small AppBar action showing how many captures are still waiting to
/// leave this device -- field staff need to see this at a glance, not
/// discover a silent backlog only when they happen to open the right
/// screen (master prompt section 42: "Never silently discard failed
/// uploads" implies never silently *hide* them either).
class SyncStatusBadge extends StatefulWidget {
  const SyncStatusBadge({super.key});

  @override
  State<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends State<SyncStatusBadge> {
  final _repository = OfflineQueueRepository();
  int _pendingCount = 0;
  int _failedCount = 0;
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _refresh();
    _subscription = context.read<SyncService>().onQueueChanged.listen((_) => _refresh());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final all = await _repository.listAll();
    if (!mounted) return;
    setState(() {
      _pendingCount = all.where((o) => o.syncState == SyncState.syncPending || o.syncState == SyncState.syncing).length;
      _failedCount = all.where((o) => o.syncState == SyncState.syncFailed || o.syncState == SyncState.conflict).length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingCount == 0 && _failedCount == 0) return const SizedBox.shrink();

    final failed = _failedCount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Center(
        child: GestureDetector(
          onTap: () => context.read<SyncService>().drainQueue(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (failed ? AppColors.fail : AppColors.warning).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  failed ? Icons.sync_problem : Icons.cloud_sync_outlined,
                  size: 16,
                  color: failed ? AppColors.fail : AppColors.warning,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_pendingCount + _failedCount} unsynced',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: failed ? AppColors.fail : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
