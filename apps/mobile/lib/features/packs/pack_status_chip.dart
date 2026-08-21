import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/features/packs/pack_model.dart';

SteriStatusTone toneForPackStatus(PackStatus status) {
  switch (status) {
    case PackStatus.packed:
    case PackStatus.used:
    case PackStatus.expired:
      return SteriStatusTone.neutral;
    case PackStatus.sterilizing:
      return SteriStatusTone.info;
    case PackStatus.pendingVerification:
      return SteriStatusTone.warning;
    case PackStatus.released:
      return SteriStatusTone.pass;
    case PackStatus.quarantined:
    case PackStatus.recalled:
      return SteriStatusTone.fail;
  }
}

class PackStatusChip extends StatelessWidget {
  final PackStatus status;
  final bool compact;
  const PackStatusChip({super.key, required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return SteriStatusBadge(
      label: status.dbValue.replaceAll('_', ' '),
      tone: toneForPackStatus(status),
      compact: compact,
    );
  }
}
