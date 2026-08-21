import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';

enum SteriStatusTone { pass, warning, fail, info, neutral }

class _ToneColors {
  final Color foreground;
  final Color background;
  const _ToneColors(this.foreground, this.background);
}

const _toneColors = <SteriStatusTone, _ToneColors>{
  SteriStatusTone.pass: _ToneColors(AppColors.pass, AppColors.passSoft),
  SteriStatusTone.warning: _ToneColors(AppColors.warning, AppColors.warningSoft),
  SteriStatusTone.fail: _ToneColors(AppColors.fail, AppColors.failSoft),
  SteriStatusTone.info: _ToneColors(AppColors.info, AppColors.infoSoft),
  SteriStatusTone.neutral: _ToneColors(AppColors.neutral, AppColors.neutralSoft),
};

/// The one place status color-coding is decided (redesign prompt section 3:
/// "Status colours are extremely important... must remain consistent
/// everywhere"). A PASS badge here and a PASS badge on a completely
/// different screen are guaranteed to look identical because both go
/// through this widget rather than each screen picking its own green.
///
/// Never color-only (section 36 accessibility: "status not indicated by
/// colour alone") -- always paired with a leading icon and the status text.
class SteriStatusBadge extends StatelessWidget {
  final String label;
  final SteriStatusTone tone;
  final IconData? icon;
  final bool compact;

  const SteriStatusBadge({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _toneColors[tone]!;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppRadius.small),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 13 : 15, color: colors.foreground),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: colors.foreground,
              fontSize: compact ? 11.5 : 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
