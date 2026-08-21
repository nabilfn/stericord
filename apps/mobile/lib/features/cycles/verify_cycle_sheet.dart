import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/ai/ai_model.dart';
import 'package:stericord_mobile/features/ai/ai_repository.dart';
import 'package:stericord_mobile/features/cycles/cycle_model.dart';
import 'package:stericord_mobile/features/cycles/cycle_repository.dart';

class VerifyCycleSheet extends StatefulWidget {
  final String cycleId;
  const VerifyCycleSheet({super.key, required this.cycleId});

  @override
  State<VerifyCycleSheet> createState() => _VerifyCycleSheetState();
}

class _VerifyCycleSheetState extends State<VerifyCycleSheet> {
  final _notesController = TextEditingController();
  final _repository = CycleRepository();
  final _aiRepository = AiRepository();
  VerificationResult? _result;
  bool _submitting = false;
  String? _error;
  AiAnalysis? _aiSuggestion;

  @override
  void initState() {
    super.initState();
    _loadAiSuggestion();
  }

  Future<void> _loadAiSuggestion() async {
    final suggestion = await _aiRepository.getLatestIndicatorAnalysis('sterilization_cycle', widget.cycleId);
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
      await _repository.verifyCycle(
        widget.cycleId,
        _result!,
        notes: _notesController.text.trim(),
        aiAnalysisId: _aiSuggestion?.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Verify cycle error: $e');
      setState(() => _error = 'Could not record the verification. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Manual verification', style: AppTypography.sectionHeader),
          if (_aiSuggestion?.suggestedResult != null) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(AppRadius.small)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, size: 16, color: AppColors.info),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'AI suggests ${_aiSuggestion!.suggestedResult}'
                      '${_aiSuggestion!.confidenceBand != null ? ' (${_aiSuggestion!.confidenceBand} confidence)' : ''} '
                      'from the captured indicator evidence. Advisory only — confirm or override below.',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SteriResultOption(
            title: 'PASS',
            description: 'All indicators and parameters are within spec. Packs may be released individually.',
            tone: SteriStatusTone.pass,
            selected: _result == VerificationResult.pass,
            onTap: () => setState(() => _result = VerificationResult.pass),
          ),
          SteriResultOption(
            title: 'FAIL',
            description: 'Sterility cannot be confirmed. All packs in this cycle will be quarantined.',
            tone: SteriStatusTone.fail,
            selected: _result == VerificationResult.fail,
            onTap: () => setState(() => _result = VerificationResult.fail),
          ),
          SteriResultOption(
            title: 'UNDETERMINED',
            description: 'Inconclusive — stays pending verification for further review.',
            tone: SteriStatusTone.warning,
            selected: _result == VerificationResult.undetermined,
            onTap: () => setState(() => _result = VerificationResult.undetermined),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: const TextStyle(color: AppColors.fail, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: (_result == null || _submitting) ? null : _submit,
            child: Text(_submitting ? 'Recording…' : 'Record verification'),
          ),
        ],
      ),
    );
  }
}
