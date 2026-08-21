import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/components/steri_card.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';

/// Large-number KPI tile for the dashboard's "Today's Overview" grid
/// (redesign prompt section 12) -- deliberately plain (one number, one
/// label, an optional accent) rather than a colorful chart block, per
/// section 44's "rainbow status cards" being on the avoid list.
class SteriMetricCard extends StatelessWidget {
  final String value;
  final String label;
  final Color? accentColor;
  final IconData? icon;

  const SteriMetricCard({
    super.key,
    required this.value,
    required this.label,
    this.accentColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.navy;
    return SteriCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: accent),
            const SizedBox(height: AppSpacing.sm),
          ],
          Text(value, style: AppTypography.metricValue),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.metricLabel),
        ],
      ),
    );
  }
}
