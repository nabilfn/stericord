import 'dart:io';

import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/core/vision/image_quality.dart';
import 'package:stericord_mobile/features/capture/evidence_model.dart';

/// Shown after a capture passes the on-device quality gate, before it's
/// uploaded (redesign prompt section 22: "Evidence Preview... [Retake]
/// [Use Photo]"). Previously a photo that passed quality checks uploaded
/// immediately with no confirmation step -- only a failed check showed
/// anything back to the user. This adds the missing review/confirm step
/// without touching how the photo itself is captured (still the OS camera
/// via image_picker) or how it's uploaded.
class EvidenceReviewSheet extends StatelessWidget {
  final File file;
  final EvidenceType evidenceType;
  final ImageQualityResult? quality;

  const EvidenceReviewSheet({super.key, required this.file, required this.evidenceType, required this.quality});

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final timeLabel = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        top: AppSpacing.xxl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Evidence preview', style: AppTypography.sectionHeader),
          const SizedBox(height: AppSpacing.lg),
          ClipRRect(
            borderRadius: AppRadius.panelRadius,
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.file(file, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SteriCard(
            child: Column(
              children: [
                _InfoRow(
                  label: 'Image quality',
                  child: quality == null
                      ? const Text('Not checked', style: TextStyle(color: AppColors.textSecondary, fontSize: 14))
                      : SteriStatusBadge(
                          label: quality!.status == QualityStatus.accepted ? 'GOOD' : 'NEEDS RETAKE',
                          tone: quality!.status == QualityStatus.accepted ? SteriStatusTone.pass : SteriStatusTone.warning,
                          compact: true,
                        ),
                ),
                const Divider(height: AppSpacing.xl),
                _InfoRow(label: 'Type', child: Text(evidenceType.label, style: AppTypography.body)),
                const Divider(height: AppSpacing.xl),
                _InfoRow(label: 'Captured', child: Text(timeLabel, style: AppTypography.body)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Retake'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Use photo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _InfoRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.metadata),
        child,
      ],
    );
  }
}
