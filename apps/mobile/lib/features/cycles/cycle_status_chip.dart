import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/features/cycles/cycle_model.dart';

SteriStatusTone toneForCycleStatus(CycleStatus status) {
  switch (status) {
    case CycleStatus.created:
    case CycleStatus.completed:
      return SteriStatusTone.neutral;
    case CycleStatus.running:
      return SteriStatusTone.info;
    case CycleStatus.pendingVerification:
      return SteriStatusTone.warning;
    case CycleStatus.passed:
      return SteriStatusTone.pass;
    case CycleStatus.failed:
    case CycleStatus.quarantined:
      return SteriStatusTone.fail;
  }
}

class CycleStatusChip extends StatelessWidget {
  final CycleStatus status;
  final bool compact;
  const CycleStatusChip({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return SteriStatusBadge(
      label: status.dbValue.replaceAll('_', ' '),
      tone: toneForCycleStatus(status),
      compact: compact,
    );
  }
}
