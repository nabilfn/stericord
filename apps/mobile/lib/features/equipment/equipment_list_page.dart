import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/equipment/equipment_model.dart';
import 'package:stericord_mobile/features/equipment/equipment_repository.dart';
import 'package:stericord_mobile/features/equipment/equipment_detail_page.dart';

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
        child: FutureBuilder<List<Equipment>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load equipment: ${snapshot.error}'),
                  ),
                ],
              );
            }
            final equipment = snapshot.data ?? [];
            if (equipment.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No equipment registered yet.'),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: equipment.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = equipment[index];
                return ListTile(
                  title: Text(item.equipmentCode, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${item.equipmentType.replaceAll('_', ' ')} · ${item.location ?? '—'}'),
                  trailing: _StatusChip(status: item.operatingStatus),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => EquipmentDetailPage(equipmentId: item.id)),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final EquipmentStatus status;
  const _StatusChip({required this.status});

  Color get _color {
    switch (status) {
      case EquipmentStatus.active:
        return AppColors.pass;
      case EquipmentStatus.lockedOut:
        return AppColors.fail;
      case EquipmentStatus.maintenance:
        return AppColors.warning;
      case EquipmentStatus.decommissioned:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.dbValue.replaceAll('_', ' '), style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: _color,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
