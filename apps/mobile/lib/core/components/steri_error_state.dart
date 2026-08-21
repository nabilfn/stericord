import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';

/// Human-readable failure state (redesign prompt section 31): "Unable to
/// load cycles / Check your connection and try again" rather than a raw
/// `PostgrestException: 42501` string on screen. Callers pass the *caught*
/// exception in [technicalDetail] only to log it elsewhere (or omit it
/// entirely) -- this widget never renders it.
class SteriErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const SteriErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.message = 'Check your connection and try again.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: const BoxDecoration(color: AppColors.failSoft, shape: BoxShape.circle),
              child: const Icon(Icons.cloud_off_rounded, size: 28, color: AppColors.fail),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTypography.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
