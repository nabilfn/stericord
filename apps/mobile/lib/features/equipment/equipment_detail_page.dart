import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stericord_mobile/features/equipment/equipment_model.dart';
import 'package:stericord_mobile/features/equipment/equipment_repository.dart';

class EquipmentDetailPage extends StatefulWidget {
  final String equipmentId;
  const EquipmentDetailPage({super.key, required this.equipmentId});

  @override
  State<EquipmentDetailPage> createState() => _EquipmentDetailPageState();
}

class _EquipmentDetailPageState extends State<EquipmentDetailPage> {
  final _repository = EquipmentRepository();
  late Future<Equipment> _equipmentFuture;
  late Future<List<EquipmentStatusEvent>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _equipmentFuture = _repository.getEquipment(widget.equipmentId);
    _historyFuture = _repository.getStatusHistory(widget.equipmentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipment Detail')),
      body: FutureBuilder<Equipment>(
        future: _equipmentFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final equipment = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(equipment.equipmentCode, style: Theme.of(context).textTheme.headlineSmall),
              Text(equipment.equipmentType.replaceAll('_', ' ')),
              const SizedBox(height: 16),
              _DetailRow(label: 'Manufacturer', value: equipment.manufacturer),
              _DetailRow(label: 'Model', value: equipment.modelName),
              _DetailRow(label: 'Serial number', value: equipment.serialNumber),
              _DetailRow(label: 'Location', value: equipment.location),
              const SizedBox(height: 24),
              Text('Status history', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              FutureBuilder<List<EquipmentStatusEvent>>(
                future: _historyFuture,
                builder: (context, historySnapshot) {
                  final events = historySnapshot.data ?? [];
                  if (events.isEmpty) {
                    return const Text('No status changes recorded.');
                  }
                  return Column(
                    children: events
                        .map((event) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                event.previousStatus != null
                                    ? '${event.previousStatus} → ${event.newStatus}'
                                    : 'Created as ${event.newStatus}',
                              ),
                              trailing: Text(DateFormat.yMd().add_jm().format(event.changedAt.toLocal())),
                            ))
                        .toList(),
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value ?? '—')),
        ],
      ),
    );
  }
}
