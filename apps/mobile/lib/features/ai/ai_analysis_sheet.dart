import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/ai/ai_model.dart';
import 'package:stericord_mobile/features/ai/ai_repository.dart';

Color colorForConfidenceBand(String? band) {
  switch (band) {
    case 'HIGH':
      return AppColors.pass;
    case 'MEDIUM':
      return AppColors.warning;
    case 'LOW':
      return AppColors.fail;
    default:
      return Colors.grey;
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
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('AI Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            if (_analysis == null)
              ElevatedButton(
                onPressed: _requesting ? null : _request,
                child: Text(_requesting ? 'Analyzing…' : 'Analyze with AI'),
              )
            else ...[
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(_analysis!.status.replaceAll('_', ' '))),
                  if (_analysis!.suggestedResult != null)
                    Chip(label: Text('Suggests ${_analysis!.suggestedResult}')),
                  if (_analysis!.confidenceBand != null)
                    Chip(
                      label: Text(
                        '${_analysis!.confidenceBand} confidence'
                        '${_analysis!.confidence != null ? ' (${(_analysis!.confidence! * 100).round()}%)' : ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                      backgroundColor: colorForConfidenceBand(_analysis!.confidenceBand),
                    ),
                ],
              ),
              if (_analysis!.status == 'NOT_CONFIGURED')
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text("Gemini isn't configured in this environment.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              if (_analysis!.status == 'FAILED')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_analysis!.errorMessage ?? 'Analysis failed.', style: const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              if (_analysis!.observations.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _analysis!.observations.map((o) => Text('• $o', style: const TextStyle(fontSize: 12))).toList(),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Advisory only — a human always confirms the result during verification.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              TextButton(
                onPressed: _requesting ? null : _request,
                child: const Text('Re-run analysis'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
