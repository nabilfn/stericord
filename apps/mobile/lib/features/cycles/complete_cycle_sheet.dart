import 'package:flutter/material.dart';
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
          const Text('Complete Cycle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Enter the final readings from the autoclave receipt.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(
            controller: _temperatureController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Temperature (°C)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pressureController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Pressure (bar)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _holdTimeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Hold time (seconds)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: Text(_submitting ? 'Saving…' : 'Complete Cycle'),
          ),
        ],
      ),
    );
  }
}
