import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/ai/ai_model.dart';
import 'package:stericord_mobile/features/ai/ai_repository.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
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
      debugPrint('Load pack error: $e');
      setState(() {
        _error = 'Could not load this pack.';
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
      debugPrint('Record verification error: $e');
      setState(() => _error = 'Could not record the verification. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Point of Use')),
      body: _loading
          ? const SteriLoadingState()
          : _outcome != null
              ? _buildOutcome(_outcome!)
              : _buildForm(),
    );
  }

  Widget _buildOutcome(String result) {
    final auth = context.watch<AuthController>();
    final tone = result == 'PASS'
        ? SteriStatusTone.pass
        : result == 'FAIL'
            ? SteriStatusTone.fail
            : SteriStatusTone.warning;
    final color = result == 'PASS' ? AppColors.pass : (result == 'FAIL' ? AppColors.fail : AppColors.warning);
    final title = result == 'PASS'
        ? 'Verification complete'
        : result == 'FAIL'
            ? 'Critical: verification failed'
            : 'Manual review required';
    final message = result == 'PASS'
        ? 'Pack marked as used.'
        : result == 'FAIL'
            ? 'This pack has been quarantined. CSSD has been notified.'
            : "SteriCord couldn't determine this result confidently — it stays pending for manual review.";

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(
                result == 'PASS'
                    ? Icons.check_circle
                    : (result == 'FAIL' ? Icons.error : Icons.help_outline),
                size: 40,
                color: color,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, textAlign: TextAlign.center, style: AppTypography.sectionHeader.copyWith(color: color)),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xl),
            SteriCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(_pack?.packCode ?? '', style: AppTypography.cardTitle)),
                      SteriStatusBadge(label: result, tone: tone, compact: true),
                    ],
                  ),
                  if (auth.profile != null) ...[
                    const Divider(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: _OutcomeDetail(label: 'Verified by', value: auth.profile!.fullName),
                        ),
                        _OutcomeDetail(label: 'At', value: _formatTime(DateTime.now())),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (_queuedOffline) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(AppRadius.small)),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 18, color: AppColors.warning),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'No connection — saved on this device and will sync automatically once online.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildForm() {
    final pack = _pack;
    if (pack == null) {
      return SteriErrorState(title: 'Pack not found', message: _error ?? 'Try scanning again.', onRetry: _load);
    }

    final eligible = _eligibility?.eligible ?? false;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(pack.packCode, style: AppTypography.heroHeader)),
            PackStatusChip(status: pack.status),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (!eligible)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.failSoft, borderRadius: BorderRadius.circular(AppRadius.small)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.block, size: 18, color: AppColors.fail),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Not eligible for use', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.fail)),
                      const SizedBox(height: 2),
                      Text(_eligibility?.reason ?? '', style: const TextStyle(color: AppColors.fail, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          )
        else ...[
          const SteriStatusBadge(label: 'ELIGIBLE FOR USE', tone: SteriStatusTone.pass, icon: Icons.check_circle_outline),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: _patientRefController,
            decoration: const InputDecoration(labelText: 'Patient reference (optional)'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _encounterRefController,
            decoration: const InputDecoration(labelText: 'Encounter reference (optional)'),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SteriSectionHeader(title: 'Indicator evidence'),
          const SizedBox(height: AppSpacing.md),
          EvidenceCaptureWidget(entityType: 'instrument_pack', entityId: pack.id),
          const SizedBox(height: AppSpacing.xl),
          if (_aiSuggestion?.suggestedResult != null)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                      'from the captured indicator evidence. Advisory only.',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SteriSectionHeader(title: 'Verification result'),
              TextButton.icon(
                onPressed: _refreshAiSuggestion,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Check AI', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SteriResultOption(
            title: 'PASS',
            description: 'Indicator is within spec. Pack is safe for use.',
            tone: SteriStatusTone.pass,
            selected: _result == VerificationResult.pass,
            onTap: () => setState(() => _result = VerificationResult.pass),
          ),
          SteriResultOption(
            title: 'FAIL',
            description: 'Sterility cannot be confirmed. Pack will be quarantined and CSSD alerted.',
            tone: SteriStatusTone.fail,
            selected: _result == VerificationResult.fail,
            onTap: () => setState(() => _result = VerificationResult.fail),
          ),
          SteriResultOption(
            title: 'UNDETERMINED',
            description: 'Inconclusive — flags for manual review.',
            tone: SteriStatusTone.warning,
            selected: _result == VerificationResult.undetermined,
            onTap: () => setState(() => _result = VerificationResult.undetermined),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes'),
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
      ],
    );
  }
}

class _OutcomeDetail extends StatelessWidget {
  final String label;
  final String value;
  const _OutcomeDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.metadata),
        const SizedBox(height: 2),
        Text(value, style: AppTypography.body),
      ],
    );
  }
}
