import 'package:flutter/material.dart';
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
      setState(() => _error = e.toString());
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
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('OCR Extraction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              if (_extraction == null)
                ElevatedButton(
                  onPressed: _requesting ? null : _requestExtraction,
                  child: Text(_requesting ? 'Extracting…' : 'Extract with OCR'),
                )
              else ...[
                Row(
                  children: [
                    Chip(label: Text(_extraction!.status.replaceAll('_', ' '))),
                    const Spacer(),
                    if (_extraction!.confirmedAt != null)
                      const Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: AppColors.pass),
                          SizedBox(width: 4),
                          Text('Confirmed', style: TextStyle(color: AppColors.pass, fontSize: 12)),
                        ],
                      ),
                  ],
                ),
                if (_extraction!.status == 'NOT_CONFIGURED')
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      "Document AI isn't configured in this environment. Enter values manually below.",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                if (_extraction!.status == 'FAILED')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(_extraction!.errorMessage ?? 'OCR failed.', style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                const SizedBox(height: 8),
                TextField(controller: _cycleNumberController, decoration: const InputDecoration(labelText: 'Cycle number', isDense: true)),
                const SizedBox(height: 8),
                TextField(controller: _machineIdController, decoration: const InputDecoration(labelText: 'Machine ID', isDense: true)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _temperatureController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Temp (°C)', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _pressureController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Pressure (bar)', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _holdTimeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Hold time (sec)', isDense: true),
                ),
                const SizedBox(height: 8),
                TextField(controller: _resultController, decoration: const InputDecoration(labelText: 'Result', isDense: true)),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _confirming ? null : _confirm,
                  child: Text(_confirming ? 'Saving…' : (_extraction!.confirmedAt != null ? 'Update confirmation' : 'Confirm values')),
                ),
                TextButton(
                  onPressed: _requesting ? null : _requestExtraction,
                  child: const Text('Re-run OCR'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
