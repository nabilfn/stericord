import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
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
  VerificationResult? _result;
  bool _submitting = false;
  String? _error;

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
      await _repository.verifyCycle(widget.cycleId, _result!, notes: _notesController.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Manual Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _ResultOption(
            title: 'PASS',
            description: 'All indicators and parameters are within spec. Packs may be released individually.',
            color: AppColors.pass,
            selected: _result == VerificationResult.pass,
            onTap: () => setState(() => _result = VerificationResult.pass),
          ),
          _ResultOption(
            title: 'FAIL',
            description: 'Sterility cannot be confirmed. All packs in this cycle will be quarantined.',
            color: AppColors.fail,
            selected: _result == VerificationResult.fail,
            onTap: () => setState(() => _result = VerificationResult.fail),
          ),
          _ResultOption(
            title: 'UNDETERMINED',
            description: 'Inconclusive — stays pending verification for further review.',
            color: AppColors.warning,
            selected: _result == VerificationResult.undetermined,
            onTap: () => setState(() => _result = VerificationResult.undetermined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true),
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
      ),
    );
  }
}

class _ResultOption extends StatelessWidget {
  final String title;
  final String description;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ResultOption({
    required this.title,
    required this.description,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // A manual selection indicator, not the Radio widget: this is a single
    // free-standing choice (no RadioGroup ancestor / groupValue involved),
    // and Radio's groupValue-based API is being superseded by RadioGroup.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? color : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: selected ? color.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? color : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
