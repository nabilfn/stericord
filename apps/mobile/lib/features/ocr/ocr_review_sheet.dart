import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/ocr/ocr_model.dart';
import 'package:stericord_mobile/features/ocr/ocr_repository.dart';

class OcrReviewSheet extends StatefulWidget {
  final String evidenceFileId;
  const OcrReviewSheet({super.key, required this.evidenceFileId});

  @override
  State<OcrReviewSheet> createState() => _OcrReviewSheetState();
}

class _OcrReviewSheetState extends State<OcrReviewSheet> {
  final _repository = OcrRepository();

  final _cycleNumberController = TextEditingController();
  final _machineIdController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _pressureController = TextEditingController();
  final _holdTimeController = TextEditingController();
  final _resultController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  OcrExtraction? _extraction;
  bool _loading = true;
  bool _requesting = false;
  bool _confirming = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cycleNumberController.dispose();
    _machineIdController.dispose();
    _temperatureController.dispose();
    _pressureController.dispose();
    _holdTimeController.dispose();
    _resultController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final extractions = await _repository.listExtractions(widget.evidenceFileId);
    setState(() {
      _extraction = extractions.isNotEmpty ? extractions.first : null;
      _loading = false;
    });
    _populateForm();
  }

  void _populateForm() {
    final fields = _extraction?.humanConfirmedFields ?? _extraction?.extractedFields;
    if (fields == null) return;
    _cycleNumberController.text = fields.cycleNumber ?? '';
    _machineIdController.text = fields.machineIdentifier ?? '';
    _temperatureController.text = fields.temperature?.toString() ?? '';
    _pressureController.text = fields.pressure?.toString() ?? '';
    _holdTimeController.text = fields.holdTimeSeconds?.toString() ?? '';
    _resultController.text = fields.result ?? '';
    _dateController.text = fields.date ?? '';
    _timeController.text = fields.time ?? '';
  }

  Future<void> _requestExtraction() async {
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      final extraction = await _repository.requestExtraction(widget.evidenceFileId);
      setState(() => _extraction = extraction);
      _populateForm();
    } catch (e) {
      debugPrint('OCR extraction error: $e');
      setState(() => _error = 'Could not extract from this photo. Try again.');
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _confirm() async {
    if (_extraction == null) return;
    setState(() {
      _confirming = true;
      _error = null;
    });
    try {
      final fields = ExtractedCycleFields(
        cycleNumber: _cycleNumberController.text.isEmpty ? null : _cycleNumberController.text,
        machineIdentifier: _machineIdController.text.isEmpty ? null : _machineIdController.text,
        temperature: double.tryParse(_temperatureController.text),
        pressure: double.tryParse(_pressureController.text),
        holdTimeSeconds: int.tryParse(_holdTimeController.text),
        result: _resultController.text.isEmpty ? null : _resultController.text,
        date: _dateController.text.isEmpty ? null : _dateController.text,
        time: _timeController.text.isEmpty ? null : _timeController.text,
      );
      final updated = await _repository.confirmExtraction(_extraction!.id, fields);
      setState(() => _extraction = updated);
    } catch (e) {
      debugPrint('Confirm OCR error: $e');
      setState(() => _error = 'Could not save these values. Try again.');
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xxl,
        right: AppSpacing.xxl,
        top: AppSpacing.xxl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xxl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Autoclave receipt', style: AppTypography.sectionHeader),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: SteriInlineProgress(label: 'Loading…'),
              )
            else ...[
              if (_extraction == null)
                ElevatedButton(
                  onPressed: _requesting ? null : _requestExtraction,
                  child: _requesting ? const SteriInlineProgress(label: 'Extracting…') : const Text('Extract with OCR'),
                )
              else ...[
                Row(
                  children: [
                    SteriStatusBadge(
                      label: _extraction!.status.replaceAll('_', ' '),
                      tone: _extraction!.status == 'FAILED' ? SteriStatusTone.fail : SteriStatusTone.neutral,
                      compact: true,
                    ),
                    const Spacer(),
                    if (_extraction!.confirmedAt != null)
                      const SteriStatusBadge(label: 'CONFIRMED', tone: SteriStatusTone.pass, icon: Icons.check_circle_outline, compact: true),
                  ],
                ),
                if (_extraction!.status == 'NOT_CONFIGURED') ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(color: AppColors.neutralSoft, borderRadius: BorderRadius.circular(AppRadius.small)),
                    child: const Text(
                      "Document AI isn't configured in this environment. Enter values manually below.",
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                    ),
                  ),
                ],
                if (_extraction!.status == 'FAILED') ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(color: AppColors.failSoft, borderRadius: BorderRadius.circular(AppRadius.small)),
                    child: Text(
                      _extraction!.errorMessage ?? 'OCR failed.',
                      style: const TextStyle(color: AppColors.fail, fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                TextField(controller: _cycleNumberController, decoration: const InputDecoration(labelText: 'Cycle number', isDense: true)),
                const SizedBox(height: AppSpacing.md),
                TextField(controller: _machineIdController, decoration: const InputDecoration(labelText: 'Machine ID', isDense: true)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _temperatureController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Temp (°C)', isDense: true),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _pressureController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Pressure (bar)', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _holdTimeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hold time (sec)', isDense: true),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(controller: _resultController, decoration: const InputDecoration(labelText: 'Result', isDense: true)),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_error!, style: const TextStyle(color: AppColors.fail, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton(
                  onPressed: _confirming ? null : _confirm,
                  child: Text(_confirming ? 'Saving…' : (_extraction!.confirmedAt != null ? 'Update confirmation' : 'Confirm values')),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: _requesting ? null : _requestExtraction,
                  child: Text(_requesting ? 'Extracting…' : 'Re-run OCR'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
