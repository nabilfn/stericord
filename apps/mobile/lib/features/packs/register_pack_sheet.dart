import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
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
      debugPrint('Register pack error: $e');
      setState(() => _error = 'Could not register the pack. Check the code and try again.');
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
            Text('Register pack', style: AppTypography.sectionHeader),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pick the instrument set and give this pack a code.',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (_loadingSets)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: SteriInlineProgress(label: 'Loading instrument sets…'),
              )
            else if (_instrumentSets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'No instrument sets available yet.',
                  style: TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedSetId,
                decoration: const InputDecoration(labelText: 'Instrument set'),
                items: _instrumentSets
                    .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedSetId = value),
                validator: (v) => v == null ? 'Select an instrument set' : null,
              ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _packCodeController,
              decoration: const InputDecoration(labelText: 'Pack code', hintText: 'e.g. PK-2026-00931'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(_error!, style: const TextStyle(color: AppColors.fail, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Registering…' : 'Register pack'),
            ),
          ],
        ),
      ),
    );
  }
}
