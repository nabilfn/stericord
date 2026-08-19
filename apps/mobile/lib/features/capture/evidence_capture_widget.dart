import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/capture/evidence_model.dart';
import 'package:stericord_mobile/features/capture/evidence_repository.dart';

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
  String? _error;

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

    final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      await _repository.uploadEvidence(
        organizationId: profile.organizationId,
        entityType: widget.entityType,
        entityId: widget.entityId,
        evidenceType: _selectedType,
        file: File(picked.path),
        capturedBy: profile.id,
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
              onPressed: _uploading ? null : _capture,
              icon: _uploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.camera_alt),
            ),
          ],
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
                        trailing: Text(
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
