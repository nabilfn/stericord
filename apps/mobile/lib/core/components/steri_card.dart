import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';

/// Base surface used everywhere a card appears -- one consistent radius,
/// border, and padding instead of every screen picking its own (redesign
/// prompt section 40: "same card radius... The app must feel like one
/// product"). Wraps [Card] rather than replacing it so `Theme.of(context)`
/// consumers (e.g. an `InkWell` splash inside) still behave normally.
class SteriCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;

  const SteriCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      child: child,
    );

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surface,
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(onTap: onTap, child: content),
    );
  }
}
