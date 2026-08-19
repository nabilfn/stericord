import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/cycles/cycle_model.dart';

Color colorForCycleStatus(CycleStatus status) {
  switch (status) {
    case CycleStatus.created:
    case CycleStatus.completed:
      return Colors.grey;
    case CycleStatus.running:
      return AppColors.scBlue;
    case CycleStatus.pendingVerification:
      return AppColors.warning;
    case CycleStatus.passed:
      return AppColors.pass;
    case CycleStatus.failed:
    case CycleStatus.quarantined:
      return AppColors.fail;
  }
}

class CycleStatusChip extends StatelessWidget {
  final CycleStatus status;
  const CycleStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.dbValue.replaceAll('_', ' '), style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: colorForCycleStatus(status),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
