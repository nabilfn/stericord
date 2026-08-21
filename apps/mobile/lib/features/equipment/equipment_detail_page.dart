import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/cycles/cycle_model.dart';
import 'package:stericord_mobile/features/cycles/cycle_repository.dart';
import 'package:stericord_mobile/features/cycles/cycle_status_chip.dart';
import 'package:stericord_mobile/features/equipment/equipment_model.dart';
import 'package:stericord_mobile/features/equipment/equipment_repository.dart';

class EquipmentDetailPage extends StatefulWidget {
  final String equipmentId;
  const EquipmentDetailPage({super.key, required this.equipmentId});

  @override
  State<EquipmentDetailPage> createState() => _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends State<EquipmentDetailPage> {
  final _equipmentRepository = EquipmentRepository();
  final _cycleRepository = CycleRepository();
  late Future<Equipment> _equipmentFuture;
  late Future<List<EquipmentStatusEvent>> _historyFuture;
  late Future<List<SterilizationCycle>> _cyclesFuture;

  @override
  void initState() {
    super.initState();
    _equipmentFuture = _equipmentRepository.getEquipment(widget.equipmentId);
    _historyFuture = _equipmentRepository.getStatusHistory(widget.equipmentId);
    _cyclesFuture = _cycleRepository.listCyclesByEquipment(widget.equipmentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipment')),
      body: FutureBuilder<Equipment>(
        future: _equipmentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SteriLoadingState();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return SteriErrorState(
              title: 'Unable to load equipment',
              onRetry: () => setState(() {
                _equipmentFuture = _equipmentRepository.getEquipment(widget.equipmentId);
              }),
            );
          }
          final equipment = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              _Header(equipment: equipment),
              const SizedBox(height: AppSpacing.sectionGap),
              const SteriSectionHeader(title: 'Details'),
              const SizedBox(height: AppSpacing.md),
              SteriCard(
                child: Column(
                  children: [
                    _DetailRow(label: 'Manufacturer', value: equipment.manufacturer),
                    _DetailRow(label: 'Model', value: equipment.modelName),
                    _DetailRow(label: 'Serial number', value: equipment.serialNumber),
                    _DetailRow(label: 'Location', value: equipment.location, showDivider: false),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const SteriSectionHeader(title: 'Cycle history'),
              const SizedBox(height: AppSpacing.md),
              FutureBuilder<List<SterilizationCycle>>(
                future: _cyclesFuture,
                builder: (context, cyclesSnapshot) {
                  if (cyclesSnapshot.connectionState == ConnectionState.waiting) {
                    return const SteriInlineProgress(label: 'Loading cycles…');
                  }
                  final cycles = cyclesSnapshot.data ?? [];
                  return Column(
                    children: [
                      _CycleStats(cycles: cycles),
                      const SizedBox(height: AppSpacing.md),
                      if (cycles.isEmpty)
                        const SteriEmptyState(
                          icon: Icons.layers_outlined,
                          title: 'No cycles yet',
                          message: 'Cycles run on this equipment will appear here.',
                        )
                      else
                        ...cycles.take(5).map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: SteriCard(
                                child: Row(
                                  children: [
                                    Expanded(child: Text('Cycle ${c.cycleNumber}', style: AppTypography.body)),
                                    CycleStatusChip(status: c.cycleStatus),
                                  ],
                                ),
                              ),
                            )),
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sectionGap),
              const SteriSectionHeader(title: 'Status history'),
              const SizedBox(height: AppSpacing.md),
              FutureBuilder<List<EquipmentStatusEvent>>(
                future: _historyFuture,
                builder: (context, historySnapshot) {
                  final events = historySnapshot.data ?? [];
                  if (historySnapshot.connectionState == ConnectionState.waiting) {
                    return const SteriInlineProgress(label: 'Loading history…');
                  }
                  if (events.isEmpty) {
                    return const SteriEmptyState(
                      icon: Icons.history,
                      title: 'No status changes',
                      message: 'Changes to this equipment\'s status will be recorded here.',
                    );
                  }
                  return SteriCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: events
                          .map((event) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.cardPadding,
                                  vertical: AppSpacing.md,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        event.previousStatus != null
                                            ? '${event.previousStatus} → ${event.newStatus}'
                                            : 'Created as ${event.newStatus}',
                                        style: AppTypography.body,
                                      ),
                                    ),
                                    Text(
                                      DateFormat.yMd().add_jm().format(event.changedAt.toLocal()),
                                      style: AppTypography.metadata,
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Equipment equipment;
  const _Header({required this.equipment});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(equipment.equipmentCode, style: AppTypography.heroHeader),
              const SizedBox(height: 2),
              Text(equipment.equipmentType.replaceAll('_', ' '), style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        _statusBadge(equipment.operatingStatus),
      ],
    );
  }

  Widget _statusBadge(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.active:
        return const SteriStatusBadge(label: 'ACTIVE', tone: SteriStatusTone.pass, icon: Icons.check_circle_outline);
      case EquipmentStatus.lockedOut:
        return const SteriStatusBadge(label: 'LOCKED OUT', tone: SteriStatusTone.fail, icon: Icons.lock_outline);
      case EquipmentStatus.maintenance:
        return const SteriStatusBadge(label: 'MAINTENANCE', tone: SteriStatusTone.warning, icon: Icons.build_outlined);
      case EquipmentStatus.decommissioned:
        return const SteriStatusBadge(label: 'DECOMMISSIONED', tone: SteriStatusTone.neutral, icon: Icons.block);
    }
  }
}

class _CycleStats extends StatelessWidget {
  final List<SterilizationCycle> cycles;
  const _CycleStats({required this.cycles});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = cycles
        .where((c) => c.createdAt.year == now.year && c.createdAt.month == now.month && c.createdAt.day == now.day)
        .length;
    final decided = cycles.where((c) => c.cycleStatus == CycleStatus.passed || c.cycleStatus == CycleStatus.failed);
    final passed = decided.where((c) => c.cycleStatus == CycleStatus.passed).length;
    final passRate = decided.isEmpty ? null : (passed / decided.length * 100).round();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: SteriMetricCard(value: '$today', label: "Today's cycles", icon: Icons.today_outlined)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SteriMetricCard(
              value: passRate == null ? '—' : '$passRate%',
              label: 'Pass rate',
              icon: Icons.verified_outlined,
              accentColor: passRate == null
                  ? AppColors.navy
                  : (passRate == 100 ? AppColors.pass : AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool showDivider;
  const _DetailRow({required this.label, required this.value, this.showDivider = true});

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
