import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/ai/ai_model.dart';
import 'package:stericord_mobile/features/ai/ai_repository.dart';

SteriStatusTone toneForConfidenceBand(String? band) {
  switch (band) {
    case 'HIGH':
      return SteriStatusTone.pass;
    case 'MEDIUM':
      return SteriStatusTone.warning;
    case 'LOW':
      return SteriStatusTone.fail;
    default:
      return SteriStatusTone.neutral;
  }
}

class AiAnalysisSheet extends StatefulWidget {
  final String evidenceFileId;
  const AiAnalysisSheet({super.key, required this.evidenceFileId});

  @override
  State<AiAnalysisSheet> createState() => _AiAnalysisSheetState();
}

class _AiAnalysisSheetState extends State<AiAnalysisSheet> {
  final _repository = AiRepository();
  AiAnalysis? _analysis;
  bool _loading = true;
  bool _requesting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final analyses = await _repository.listAnalyses(widget.evidenceFileId);
    setState(() {
      _analysis = analyses.isNotEmpty ? analyses.first : null;
      _loading = false;
    });
  }

  Future<void> _request() async {
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      final analysis = await _repository.requestAnalysis(widget.evidenceFileId);
      setState(() => _analysis = analysis);
    } catch (e) {
      debugPrint('AI analysis error: $e');
      setState(() => _error = 'Could not run analysis. Try again.');
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: AppColors.info),
              const SizedBox(width: AppSpacing.sm),
              Text('AI-assisted analysis', style: AppTypography.sectionHeader),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: SteriInlineProgress(label: 'Loading…'),
            )
          else ...[
            if (_analysis == null)
              ElevatedButton(
                onPressed: _requesting ? null : _request,
                child: _requesting
                    ? const SteriInlineProgress(label: 'Analyzing evidence…')
                    : const Text('Analyze with AI'),
              )
            else
              _AnalysisResult(analysis: _analysis!),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: AppColors.fail, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
            if (_analysis != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: _requesting ? null : _request,
                child: Text(_requesting ? 'Analyzing…' : 'Re-run analysis'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AnalysisResult extends StatelessWidget {
  final AiAnalysis analysis;
  const _AnalysisResult({required this.analysis});

  @override
  Widget build(BuildContext context) {
    if (analysis.status == 'NOT_CONFIGURED') {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.neutralSoft, borderRadius: BorderRadius.circular(AppRadius.small)),
        child: const Text(
          "AI analysis isn't configured in this environment. Enter the verification result manually.",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }
    if (analysis.status == 'FAILED') {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.failSoft, borderRadius: BorderRadius.circular(AppRadius.small)),
        child: Text(
          analysis.errorMessage ?? 'Analysis failed.',
          style: const TextStyle(color: AppColors.fail, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      );
    }

    final undetermined = analysis.suggestedResult == 'UNDETERMINED' || analysis.suggestedResult == null;
    if (undetermined) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(AppRadius.small)),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manual review required', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning, fontSize: 14)),
            SizedBox(height: 4),
            Text(
              "SteriCord couldn't determine this result confidently. Don't use this as the final verification.",
              style: TextStyle(color: AppColors.warning, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    final tone = analysis.suggestedResult == 'PASS' ? SteriStatusTone.pass : SteriStatusTone.fail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Suggested result', style: AppTypography.metadata),
        const SizedBox(height: AppSpacing.xs),
        SteriStatusBadge(label: analysis.suggestedResult!, tone: tone),
        if (analysis.confidenceBand != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Confidence', style: AppTypography.metadata),
          const SizedBox(height: AppSpacing.xs),
          SteriStatusBadge(
            label: '${analysis.confidenceBand}'
                '${analysis.confidence != null ? ' (${(analysis.confidence! * 100).round()}%)' : ''}',
            tone: toneForConfidenceBand(analysis.confidenceBand),
            compact: true,
          ),
        ],
        if (analysis.observations.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Observations', style: AppTypography.metadata),
          const SizedBox(height: AppSpacing.xs),
          ...analysis.observations.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $o', style: AppTypography.body),
              )),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(color: AppColors.neutralSoft, borderRadius: BorderRadius.circular(AppRadius.small)),
          child: const Text(
            'Advisory only — a human always confirms the result during verification.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
