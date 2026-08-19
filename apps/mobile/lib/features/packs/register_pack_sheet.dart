import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/packs/pack_model.dart';
import 'package:stericord_mobile/features/packs/pack_repository.dart';

class RegisterPackSheet extends StatefulWidget {
  final String cycleId;
  const RegisterPackSheet({super.key, required this.cycleId});

  @override
  State<RegisterPackSheet> createState() => _RegisterPackSheetState();
}

class _RegisterPackSheetState extends State<RegisterPackSheet> {
  final _formKey = GlobalKey<FormState>();
  final _packCodeController = TextEditingController();
  final _repository = PackRepository();

  List<InstrumentSet> _instrumentSets = [];
  String? _selectedSetId;
  bool _loadingSets = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSets();
  }

  Future<void> _loadSets() async {
    final sets = await _repository.listInstrumentSets();
    setState(() {
      _instrumentSets = sets;
      _loadingSets = false;
    });
  }

  @override
  void dispose() {
    _packCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedSetId == null) return;
    final profile = context.read<AuthController>().profile;
    if (profile == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _repository.createPack(
        organizationId: profile.organizationId,
        instrumentSetId: _selectedSetId!,
        cycleId: widget.cycleId,
        packCode: _packCodeController.text.trim(),
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Register Pack', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _loadingSets
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    value: _selectedSetId,
                    decoration: const InputDecoration(labelText: 'Instrument set'),
                    items: _instrumentSets
                        .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedSetId = value),
                    validator: (v) => v == null ? 'Select an instrument set' : null,
                  ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _packCodeController,
              decoration: const InputDecoration(labelText: 'Pack code'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Registering…' : 'Register Pack'),
            ),
          ],
        ),
      ),
    );
  }
}
