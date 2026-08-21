import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/components/steri_status_badge.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';

/// A single large, tappable PASS/FAIL/UNDETERMINED-style choice -- shared by
/// every verification screen (cycle verify, OT point-of-use) so a result
/// choice looks and behaves identically everywhere, matching the redesign
/// brief's "same buttons... everywhere" (section 40).
///
/// A manual selection indicator, not the Radio widget: this is always a
/// single free-standing choice group (no RadioGroup ancestor / groupValue
/// involved), and Radio's groupValue-based API is being superseded by
/// RadioGroup.
class SteriResultOption extends StatelessWidget {
  final String title;
  final String description;
  final SteriStatusTone tone;
  final bool selected;
  final VoidCallback onTap;

  const SteriResultOption({
    super.key,
    required this.title,
    required this.description,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  Color get _color {
    switch (tone) {
      case SteriStatusTone.pass:
        return AppColors.pass;
      case SteriStatusTone.warning:
        return AppColors.warning;
      case SteriStatusTone.fail:
        return AppColors.fail;
      case SteriStatusTone.info:
        return AppColors.info;
      case SteriStatusTone.neutral:
        return AppColors.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? color : AppColors.border, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(AppRadius.small),
          color: selected ? color.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? color : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(description, style: AppTypography.metadata),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
