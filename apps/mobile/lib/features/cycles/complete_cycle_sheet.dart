import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/cycles/cycle_repository.dart';

class CompleteCycleSheet extends StatefulWidget {
  final String cycleId;
  const CompleteCycleSheet({super.key, required this.cycleId});

  @override
  State<CompleteCycleSheet> createState() => _CompleteCycleSheetState();
}

class _CompleteCycleSheetState extends State<CompleteCycleSheet> {
  final _temperatureController = TextEditingController();
  final _pressureController = TextEditingController();
  final _holdTimeController = TextEditingController();
  final _repository = CycleRepository();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _temperatureController.dispose();
    _pressureController.dispose();
    _holdTimeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repository.completeCycle(
        widget.cycleId,
        temperature: double.tryParse(_temperatureController.text),
        pressure: double.tryParse(_pressureController.text),
        holdTimeSeconds: int.tryParse(_holdTimeController.text),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Complete cycle error: $e');
      setState(() => _error = 'Could not complete the cycle. Check the readings and try again.');
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
          Text('Complete cycle', style: AppTypography.sectionHeader),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enter the final readings from the autoclave receipt.',
            style: AppTypography.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          TextField(
            controller: _temperatureController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Temperature (°C)'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _pressureController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Pressure (bar)'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _holdTimeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Hold time (seconds)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(_error!, style: const TextStyle(color: AppColors.fail, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
          const SizedBox(height: AppSpacing.xl),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Saving…' : 'Complete cycle'),
          ),
        ],
      ),
    );
  }
}
