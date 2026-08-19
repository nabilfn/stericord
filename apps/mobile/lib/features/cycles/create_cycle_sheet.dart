import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/cycles/cycle_repository.dart';
import 'package:stericord_mobile/features/equipment/equipment_model.dart';
import 'package:stericord_mobile/features/equipment/equipment_repository.dart';

class CreateCycleSheet extends StatefulWidget {
  const CreateCycleSheet({super.key});

  @override
  State<CreateCycleSheet> createState() => _CreateCycleSheetState();
}

class _CreateCycleSheetState extends State<CreateCycleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _cycleNumberController = TextEditingController();
  final _cycleTypeController = TextEditingController();
  final _equipmentRepository = EquipmentRepository();
  final _cycleRepository = CycleRepository();

  List<Equipment> _equipment = [];
  String? _selectedEquipmentId;
  bool _loadingEquipment = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEquipment();
  }

  Future<void> _loadEquipment() async {
    final all = await _equipmentRepository.listEquipment();
    setState(() {
      _equipment = all.where((e) => e.operatingStatus.dbValue == 'ACTIVE').toList();
      _loadingEquipment = false;
    });
  }

  @override
  void dispose() {
    _cycleNumberController.dispose();
    _cycleTypeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedEquipmentId == null) return;
    final auth = context.read<AuthController>();
    final profile = auth.profile;
    if (profile == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await _cycleRepository.createCycle(
        organizationId: profile.organizationId,
        equipmentId: _selectedEquipmentId!,
        cycleNumber: _cycleNumberController.text.trim(),
        cycleType: _cycleTypeController.text.trim(),
        operatorUserId: profile.id,
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
            const Text('Create Sterilization Cycle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _loadingEquipment
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<String>(
                    value: _selectedEquipmentId,
                    decoration: const InputDecoration(labelText: 'Equipment'),
                    items: _equipment
                        .map((e) => DropdownMenuItem(value: e.id, child: Text(e.equipmentCode)))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedEquipmentId = value),
                    validator: (v) => v == null ? 'Select equipment' : null,
                  ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cycleNumberController,
              decoration: const InputDecoration(labelText: 'Cycle number'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cycleTypeController,
              decoration: const InputDecoration(labelText: 'Cycle type'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Creating…' : 'Create Cycle'),
            ),
          ],
        ),
      ),
    );
  }
}
