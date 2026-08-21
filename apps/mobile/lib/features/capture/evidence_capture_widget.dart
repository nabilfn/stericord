import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/core/vision/image_quality.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/capture/evidence_model.dart';
import 'package:stericord_mobile/features/capture/evidence_repository.dart';
import 'package:stericord_mobile/features/capture/evidence_review_sheet.dart';
import 'package:stericord_mobile/features/ocr/ocr_review_sheet.dart';
import 'package:stericord_mobile/features/ai/ai_analysis_sheet.dart';

class EvidenceCaptureWidget extends StatefulWidget {
  final String entityType;
  final String entityId;
  final VoidCallback? onUploaded;

  const EvidenceCaptureWidget({
    super.key,
    required this.entityType,
    required this.entityId,
    this.onUploaded,
  });

  @override
  State<EvidenceCaptureWidget> createState() => _EvidenceCaptureWidgetState();
}

class _EvidenceCaptureWidgetState extends State<EvidenceCaptureWidget> {
  final _repository = EvidenceRepository();
  final _picker = ImagePicker();

  late Future<List<EvidenceFile>> _future;
  EvidenceType _selectedType = EvidenceType.autoclaveReceipt;
  bool _uploading = false;
  bool _checkingQuality = false;
  String? _error;
  List<QualityReason>? _retakeReasons;

  @override
  void initState() {
    super.initState();
    _future = _repository.listEvidence(widget.entityType, widget.entityId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repository.listEvidence(widget.entityType, widget.entityId);
    });
  }

  Future<void> _capture() async {
    final profile = context.read<AuthController>().profile;
    if (profile == null) return;

    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (picked == null) return;

    setState(() {
      _error = null;
      _retakeReasons = null;
      _checkingQuality = true;
    });

    final file = File(picked.path);
    final bytes = await file.readAsBytes();
    final quality = analyzeImageQuality(bytes, _selectedType.dbValue);

    setState(() => _checkingQuality = false);

    if (quality != null && quality.status == QualityStatus.retakeRequired) {
      setState(() => _retakeReasons = quality.reasons);
      return;
    }

    if (!mounted) return;
    final usePhoto = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EvidenceReviewSheet(file: file, evidenceType: _selectedType, quality: quality),
    );

    if (usePhoto == false) {
      // Retake: relaunch the camera immediately rather than leaving the
      // user staring at a dismissed sheet with no obvious next step.
      await _capture();
      return;
    }
    if (usePhoto != true) return;

    setState(() => _uploading = true);
    try {
      await _repository.uploadEvidence(
        organizationId: profile.organizationId,
        entityType: widget.entityType,
        entityId: widget.entityId,
        evidenceType: _selectedType,
        file: file,
        capturedBy: profile.id,
        quality: quality,
      );
      await _refresh();
      widget.onUploaded?.call();
    } catch (e) {
      debugPrint('Upload evidence error: $e');
      setState(() => _error = 'Could not upload the photo. Try again.');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.center_focus_strong, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Fill the frame with the indicator, avoid glare, and hold steady.',
                style: AppTypography.metadata,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<EvidenceType>(
                initialValue: _selectedType,
                decoration: const InputDecoration(labelText: 'Evidence type', isDense: true),
                items: EvidenceType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedType = value);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: AppColors.teal, minimumSize: const Size(48, 48)),
              onPressed: (_uploading || _checkingQuality) ? null : _capture,
              icon: (_uploading || _checkingQuality)
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.camera_alt, color: Colors.white),
            ),
          ],
        ),
        if (_retakeReasons != null)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.sm),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(AppRadius.small)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Retake required', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning, fontSize: 13)),
                const SizedBox(height: 2),
                ..._retakeReasons!.map((r) => Text('• ${r.label}', style: const TextStyle(color: AppColors.warning, fontSize: 12))),
              ],
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(_error!, style: const TextStyle(color: AppColors.fail, fontSize: 12.5, fontWeight: FontWeight.w500)),
        ],
        const SizedBox(height: AppSpacing.sm),
        FutureBuilder<List<EvidenceFile>>(
          future: _future,
          builder: (context, snapshot) {
            final files = snapshot.data ?? [];
            if (files.isEmpty) {
              return Text('No evidence captured yet.', style: AppTypography.metadata);
            }
            return Column(
              children: files
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          children: [
                            const Icon(Icons.description_outlined, size: 18, color: AppColors.textSecondary),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text(f.evidenceType.label, style: AppTypography.body)),
                            _trailingFor(context, f),
                          ],
                        ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  static const _indicatorTypes = {
    EvidenceType.bowieDick,
    EvidenceType.chemicalIndicator,
    EvidenceType.biTray,
    EvidenceType.otIndicator,
    EvidenceType.washerTest,
  };

  Widget _trailingFor(BuildContext context, EvidenceFile f) {
    if (f.evidenceType == EvidenceType.autoclaveReceipt) {
      return TextButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => OcrReviewSheet(evidenceFileId: f.id),
        ),
        child: const Text('OCR', style: TextStyle(fontSize: 12)),
      );
    }
    if (_indicatorTypes.contains(f.evidenceType)) {
      return TextButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => AiAnalysisSheet(evidenceFileId: f.id),
        ),
        child: const Text('AI', style: TextStyle(fontSize: 12)),
      );
    }
    return Text(
      '${f.capturedAt.hour.toString().padLeft(2, '0')}:${f.capturedAt.minute.toString().padLeft(2, '0')}',
      style: AppTypography.metadata,
    );
  }
}
