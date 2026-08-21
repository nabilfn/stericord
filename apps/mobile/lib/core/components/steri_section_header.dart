import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';

/// Consistent section title + optional trailing action, used to break a
/// dashboard/list screen into named regions (redesign prompt's dashboard
/// structure: Greeting -> Alerts -> Today's Overview -> Quick Actions ->
/// Equipment -> Recent Activity) instead of every screen inventing its own
/// heading style.
class SteriSectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SteriSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTypography.sectionHeader),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
