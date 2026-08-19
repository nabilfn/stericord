import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/packs/pack_model.dart';

Color colorForPackStatus(PackStatus status) {
  switch (status) {
    case PackStatus.packed:
    case PackStatus.used:
    case PackStatus.expired:
      return Colors.grey;
    case PackStatus.sterilizing:
      return AppColors.scBlue;
    case PackStatus.pendingVerification:
      return AppColors.warning;
    case PackStatus.released:
      return AppColors.pass;
    case PackStatus.quarantined:
    case PackStatus.recalled:
      return AppColors.fail;
  }
}

class PackStatusChip extends StatelessWidget {
  final PackStatus status;
  const PackStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.dbValue.replaceAll('_', ' '), style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: colorForPackStatus(status),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
