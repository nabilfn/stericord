import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/core/vision/image_quality.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/capture/evidence_model.dart';
import 'package:stericord_mobile/features/capture/evidence_repository.dart';
import 'package:stericord_mobile/features/ocr/ocr_review_sheet.dart';

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
    setState(() => _future = _repository.listEvidence(widget.entityType, widget.entityId));
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
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.center_focus_strong, size: 14, color: Colors.grey),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                'Fill the frame with the indicator, avoid glare, and hold steady.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<EvidenceType>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Evidence type', isDense: true),
                items: EvidenceType.values
                    .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedType = value);
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: (_uploading || _checkingQuality) ? null : _capture,
              icon: (_uploading || _checkingQuality)
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.camera_alt),
            ),
          ],
        ),
        if (_retakeReasons != null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Retake required', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.warning)),
                ..._retakeReasons!.map((r) => Text('• ${r.label}', style: const TextStyle(color: AppColors.warning, fontSize: 12))),
              ],
            ),
          ),
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
        const SizedBox(height: 8),
        FutureBuilder<List<EvidenceFile>>(
          future: _future,
          builder: (context, snapshot) {
            final files = snapshot.data ?? [];
            if (files.isEmpty) {
              return const Text('No evidence captured yet.', style: TextStyle(color: Colors.grey));
            }
            return Column(
              children: files
                  .map((f) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description_outlined, size: 18),
                        title: Text(f.evidenceType.label),
                        trailing: f.evidenceType == EvidenceType.autoclaveReceipt
                            ? TextButton(
                                onPressed: () => showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => OcrReviewSheet(evidenceFileId: f.id),
                                ),
                                child: const Text('OCR', style: TextStyle(fontSize: 12)),
                              )
                            : Text(
                                '${f.capturedAt.hour.toString().padLeft(2, '0')}:${f.capturedAt.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}
