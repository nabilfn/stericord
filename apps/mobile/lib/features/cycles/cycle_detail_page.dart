import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/capture/evidence_capture_widget.dart';
import 'package:stericord_mobile/features/cycles/complete_cycle_sheet.dart';
import 'package:stericord_mobile/features/cycles/cycle_model.dart';
import 'package:stericord_mobile/features/cycles/cycle_repository.dart';
import 'package:stericord_mobile/features/cycles/cycle_status_chip.dart';
import 'package:stericord_mobile/features/cycles/verify_cycle_sheet.dart';
import 'package:stericord_mobile/features/equipment/equipment_model.dart';
import 'package:stericord_mobile/features/equipment/equipment_repository.dart';
import 'package:stericord_mobile/features/packs/pack_list_for_cycle.dart';
import 'package:stericord_mobile/features/packs/register_pack_sheet.dart';

class CycleDetailPage extends StatefulWidget {
  final String cycleId;
  const CycleDetailPage({super.key, required this.cycleId});

  @override
  State<CycleDetailPage> createState() => _CycleDetailPageState();
}

class _CycleDetailPageState extends State<CycleDetailPage> {
  final _cycleRepository = CycleRepository();
  final _equipmentRepository = EquipmentRepository();
  final _packListKey = GlobalKey<PackListForCycleState>();

  late Future<SterilizationCycle> _cycleFuture;
  Future<Equipment>? _equipmentFuture;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cycleFuture = _loadCycle();
  }

  Future<SterilizationCycle> _loadCycle() async {
    try {
      final cycle = await _cycleRepository.getCycle(widget.cycleId);
      setState(() {
        _equipmentFuture = _equipmentRepository.getEquipment(cycle.equipmentId);
      });
      return cycle;
    } catch (e, st) {
      debugPrint('Load cycle error for ${widget.cycleId}: $e\n$st');
      rethrow;
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _cycleFuture = _loadCycle();
      _error = null;
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      await _refresh();
    } catch (e) {
      debugPrint('Cycle action error: $e');
      setState(() => _error = 'That action could not be completed. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final canOperate = auth.hasRole([UserRole.hospitalAdmin, UserRole.cssdSupervisor, UserRole.cssdTechnician]);
    final canVerify = auth.hasRole([UserRole.hospitalAdmin, UserRole.cssdSupervisor]);

    return Scaffold(
      appBar: AppBar(title: const Text('Cycle')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.teal,
        child: FutureBuilder<SterilizationCycle>(
          future: _cycleFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SteriLoadingState();
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return SteriErrorState(title: 'Unable to load cycle', onRetry: _refresh);
            }
            final cycle = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cycle ${cycle.cycleNumber}', style: AppTypography.heroHeader),
                          const SizedBox(height: 2),
                          FutureBuilder<Equipment>(
                            future: _equipmentFuture,
                            builder: (context, eqSnapshot) => Text(
                              '${cycle.cycleType} · ${eqSnapshot.data?.equipmentCode ?? '…'}',
                              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CycleStatusChip(status: cycle.cycleStatus),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: AppColors.failSoft, borderRadius: BorderRadius.circular(AppRadius.small)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.fail, fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (canOperate) _buildActionButton(cycle, canVerify),
                const SizedBox(height: AppSpacing.sectionGap),
                const SteriSectionHeader(title: 'Cycle parameters'),
                const SizedBox(height: AppSpacing.md),
                SteriCard(
                  child: Column(
                    children: [
                      _ParamRow(label: 'Temperature', value: cycle.temperature != null ? '${cycle.temperature} °C' : null),
                      _ParamRow(label: 'Pressure', value: cycle.pressure != null ? '${cycle.pressure} bar' : null),
                      _ParamRow(
                        label: 'Hold time',
                        value: cycle.holdTimeSeconds != null ? '${cycle.holdTimeSeconds}s' : null,
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sectionGap),
                SteriSectionHeader(
                  title: 'Instrument packs',
                  actionLabel: canOperate &&
                          (cycle.cycleStatus == CycleStatus.created || cycle.cycleStatus == CycleStatus.running)
                      ? 'Register'
                      : null,
                  onAction: () async {
                    final created = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => RegisterPackSheet(cycleId: cycle.id),
                    );
                    if (created == true) _packListKey.currentState?.refresh();
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                PackListForCycle(key: _packListKey, cycleId: cycle.id, cycleStatus: cycle.cycleStatus),
                const SizedBox(height: AppSpacing.sectionGap),
                const SteriSectionHeader(title: 'Evidence'),
                const SizedBox(height: AppSpacing.md),
                EvidenceCaptureWidget(entityType: 'sterilization_cycle', entityId: cycle.id),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionButton(SterilizationCycle cycle, bool canVerify) {
    switch (cycle.cycleStatus) {
      case CycleStatus.created:
        return ElevatedButton(
          onPressed: _busy ? null : () => _runAction(() => _cycleRepository.startCycle(cycle.id)),
          child: const Text('Start cycle'),
        );
      case CycleStatus.running:
        return ElevatedButton(
          onPressed: () async {
            final done = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              builder: (_) => CompleteCycleSheet(cycleId: cycle.id),
            );
            if (done == true) await _refresh();
          },
          child: const Text('Complete cycle'),
        );
      case CycleStatus.completed:
        return ElevatedButton(
          onPressed: _busy ? null : () => _runAction(() => _cycleRepository.submitForVerification(cycle.id)),
          child: const Text('Submit for verification'),
        );
      case CycleStatus.pendingVerification:
        if (!canVerify) return const SizedBox.shrink();
        return ElevatedButton(
          onPressed: () async {
            final done = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              builder: (_) => VerifyCycleSheet(cycleId: cycle.id),
            );
            if (done == true) await _refresh();
          },
          child: const Text('Verify cycle'),
        );
      case CycleStatus.passed:
      case CycleStatus.failed:
      case CycleStatus.quarantined:
        return const SizedBox.shrink();
    }
  }
}

class _ParamRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool showDivider;
  const _ParamRow({required this.label, required this.value, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(width: 130, child: Text(label, style: AppTypography.metadata)),
              Expanded(child: Text(value ?? '—', style: AppTypography.body)),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}
