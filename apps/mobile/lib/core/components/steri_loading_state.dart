import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';

/// A single pulsing placeholder block. Deliberately hand-rolled with
/// [TweenAnimationBuilder] rather than a shimmer package -- section 43
/// warns against unnecessary dependency weight, and a slow opacity pulse
/// reads just as clearly as a moving shimmer for this app's purposes.
class _SkeletonBlock extends StatefulWidget {
  final double height;
  final double? width;

  const _SkeletonBlock({required this.height, this.width});

  @override
  State<_SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<_SkeletonBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(Tween(begin: 0.4, end: 0.9)),
      child: Container(
        height: widget.height,
        width: widget.width,
        decoration: const BoxDecoration(
          color: AppColors.neutralSoft,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.small)),
        ),
      ),
    );
  }
}

/// Skeleton loader for list-style content (redesign prompt section 30:
/// avoid a big centered [CircularProgressIndicator] for content that's
/// about to render as cards) -- shows [itemCount] card-shaped placeholders
/// matching [SteriCard]'s actual proportions, so the transition from
/// loading to loaded doesn't jump.
class SteriLoadingState extends StatelessWidget {
  final int itemCount;

  const SteriLoadingState({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(color: AppColors.border),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBlock(height: 16, width: 140),
            SizedBox(height: AppSpacing.sm),
            _SkeletonBlock(height: 12, width: 200),
            SizedBox(height: AppSpacing.md),
            _SkeletonBlock(height: 24, width: 90),
          ],
        ),
      ),
    );
  }
}

/// Compact inline progress label for a specific action (redesign prompt
/// section 30: "Analyzing evidence... / Uploading... / Generating QR...").
class SteriInlineProgress extends StatelessWidget {
  final String label;

  const SteriInlineProgress({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.teal),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}
