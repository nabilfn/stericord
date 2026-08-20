import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/ai/ai_model.dart';
import 'package:stericord_mobile/features/ai/ai_repository.dart';
import 'package:stericord_mobile/features/capture/evidence_capture_widget.dart';
import 'package:stericord_mobile/features/cycles/cycle_model.dart';
import 'package:stericord_mobile/features/ot/point_of_use_repository.dart';
import 'package:stericord_mobile/features/packs/pack_model.dart';
import 'package:stericord_mobile/features/packs/pack_repository.dart';
import 'package:stericord_mobile/features/packs/pack_status_chip.dart';

class PointOfUseVerifyPage extends StatefulWidget {
  final String packId;
  const PointOfUseVerifyPage({super.key, required this.packId});

  @override
  State<PointOfUseVerifyPage> createState() => _PointOfUseVerifyPageState();
}

class _PointOfUseVerifyPageState extends State<PointOfUseVerifyPage> {
  final _packRepository = PackRepository();
  final _pouRepository = PointOfUseRepository();
  final _aiRepository = AiRepository();
  final _patientRefController = TextEditingController();
  final _encounterRefController = TextEditingController();
  final _notesController = TextEditingController();

  InstrumentPack? _pack;
  EligibilityResult? _eligibility;
  VerificationResult? _result;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _outcome;
  bool _queuedOffline = false;
  AiAnalysis? _aiSuggestion;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pack = await _packRepository.getPack(widget.packId);
      final eligibility = await _pouRepository.checkEligibility(widget.packId);
      setState(() {
        _pack = pack;
        _eligibility = eligibility;
        _loading = false;
      });
      await _refreshAiSuggestion();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshAiSuggestion() async {
    final suggestion = await _aiRepository.getLatestIndicatorAnalysis('instrument_pack', widget.packId);
    if (!mounted) return;
    setState(() {
      _aiSuggestion = suggestion;
      if (suggestion?.suggestedResult != null && _result == null) {
        _result = VerificationResult.values.firstWhere(
          (r) => r.dbValue == suggestion!.suggestedResult,
          orElse: () => VerificationResult.undetermined,
        );
      }
    });
  }

  @override
  void dispose() {
    _patientRefController.dispose();
    _encounterRefController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_result == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final outcome = await _pouRepository.recordVerification(
        packId: widget.packId,
        result: _result!,
        patientReference: _patientRefController.text.trim().isEmpty ? null : _patientRefController.text.trim(),
        encounterReference:
            _encounterRefController.text.trim().isEmpty ? null : _encounterRefController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        aiAnalysisId: _aiSuggestion?.id,
      );
      setState(() {
        _outcome = _result!.dbValue;
        _queuedOffline = outcome == RecordVerificationOutcome.queuedOffline;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Point of Use Verification')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _outcome != null
              ? _buildOutcome(_outcome!)
              : _buildForm(),
    );
  }

  Widget _buildOutcome(String result) {
    final color = result == 'PASS'
        ? AppColors.pass
        : result == 'FAIL'
            ? AppColors.fail
            : AppColors.warning;
    final message = result == 'PASS'
        ? 'PASS — pack marked as used.'
        : result == 'FAIL'
            ? 'FAIL — pack quarantined, incident created, CSSD alerted.'
            : 'UNDETERMINED — requires further manual review.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              result == 'PASS' ? Icons.check_circle : Icons.warning_amber_rounded,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
            if (_queuedOffline) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No connection — saved on this device and will sync automatically once online.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final pack = _pack;
    if (pack == null) {
      return Center(child: Text(_error ?? 'Pack not found'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(pack.packCode, style: Theme.of(context).textTheme.headlineSmall),
            PackStatusChip(status: pack.status),
          ],
        ),
        const SizedBox(height: 16),
        if (_eligibility != null && !_eligibility!.eligible)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Not eligible for use', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.fail)),
                Text(_eligibility!.reason ?? '', style: const TextStyle(color: AppColors.fail)),
              ],
            ),
          )
        else ...[
          const Chip(label: Text('Eligible for use'), backgroundColor: AppColors.pass, labelStyle: TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          TextField(
            controller: _patientRefController,
            decoration: const InputDecoration(labelText: 'Patient reference (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _encounterRefController,
            decoration: const InputDecoration(labelText: 'Encounter reference (optional)'),
          ),
          const SizedBox(height: 16),
          Text('Indicator evidence', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          EvidenceCaptureWidget(entityType: 'instrument_pack', entityId: pack.id),
          const SizedBox(height: 16),
          if (_aiSuggestion?.suggestedResult != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.scBlueLight, borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: AppColors.scBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI suggests ${_aiSuggestion!.suggestedResult}'
                      '${_aiSuggestion!.confidenceBand != null ? ' (${_aiSuggestion!.confidenceBand} confidence)' : ''} '
                      'from the captured indicator evidence. Advisory only.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Verification result', style: Theme.of(context).textTheme.titleSmall),
              TextButton.icon(
                onPressed: _refreshAiSuggestion,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Check AI suggestion', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _resultButton('PASS', VerificationResult.pass, AppColors.pass),
              const SizedBox(width: 8),
              _resultButton('FAIL', VerificationResult.fail, AppColors.fail),
              const SizedBox(width: 8),
              _resultButton('UNDETERMINED', VerificationResult.undetermined, AppColors.warning),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: (_result == null || _submitting) ? null : _submit,
            child: Text(_submitting ? 'Recording…' : 'Record Verification'),
          ),
        ],
      ],
    );
  }

  Widget _resultButton(String label, VerificationResult value, Color color) {
    final selected = _result == value;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? color.withValues(alpha: 0.1) : null,
          side: BorderSide(color: selected ? color : Colors.grey.shade300),
          foregroundColor: color,
        ),
        onPressed: () => setState(() => _result = value),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
