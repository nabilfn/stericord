import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
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
      debugPrint('Create cycle error: $e');
      setState(() => _error = 'Could not create the cycle. Check the details and try again.');
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New sterilization cycle', style: AppTypography.sectionHeader),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Select the equipment and give this cycle an identifier.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_loadingEquipment)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: SteriInlineProgress(label: 'Loading equipment…'),
              )
            else if (_equipment.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'No active equipment available. An equipment must be ACTIVE to start a cycle on it.',
                  style: TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedEquipmentId,
                decoration: const InputDecoration(labelText: 'Equipment'),
                items: _equipment
                    .map((e) => DropdownMenuItem(value: e.id, child: Text(e.equipmentCode)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedEquipmentId = value),
                validator: (v) => v == null ? 'Select equipment' : null,
              ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _cycleNumberController,
              decoration: const InputDecoration(labelText: 'Cycle number', hintText: 'e.g. CYC-2026-0094'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _cycleTypeController,
              decoration: const InputDecoration(labelText: 'Cycle type', hintText: 'e.g. Steam Prevac'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: AppColors.fail, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Creating…' : 'Create cycle'),
            ),
          ],
        ),
      ),
    );
  }
}
