import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/equipment/equipment_detail_page.dart';
import 'package:stericord_mobile/features/equipment/equipment_model.dart';
import 'package:stericord_mobile/features/equipment/equipment_repository.dart';

class EquipmentListPage extends StatefulWidget {
  const EquipmentListPage({super.key});

  @override
  State<EquipmentListPage> createState() => _EquipmentListPageState();
}

class _EquipmentListPageState extends State<EquipmentListPage> {
  final _repository = EquipmentRepository();
  late Future<List<Equipment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listEquipment();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.listEquipment());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipment')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.teal,
        child: FutureBuilder<List<Equipment>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SteriLoadingState();
            }
            if (snapshot.hasError) {
              return SteriErrorState(
                title: 'Unable to load equipment',
                onRetry: _refresh,
              );
            }
            final equipment = snapshot.data ?? [];
            if (equipment.isEmpty) {
              return const SteriEmptyState(
                icon: Icons.build_outlined,
                title: 'No equipment yet',
                message: 'Equipment registered for your organization will appear here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: equipment.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) => _EquipmentCard(equipment: equipment[index]),
            );
          },
        ),
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  final Equipment equipment;
  const _EquipmentCard({required this.equipment});

  @override
  Widget build(BuildContext context) {
    return SteriCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EquipmentDetailPage(equipmentId: equipment.id)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(equipment.equipmentCode, style: AppTypography.cardTitle),
                const SizedBox(height: 4),
                Text(
                  '${equipment.equipmentType.replaceAll('_', ' ')} · ${equipment.location ?? '—'}',
                  style: AppTypography.metadata,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _statusBadge(equipment.operatingStatus),
        ],
      ),
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
