import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/cycles/cycle_model.dart';
import 'package:stericord_mobile/features/packs/pack_detail_page.dart';
import 'package:stericord_mobile/features/packs/pack_model.dart';
import 'package:stericord_mobile/features/packs/pack_repository.dart';
import 'package:stericord_mobile/features/packs/pack_status_chip.dart';

class PackListForCycle extends StatefulWidget {
  final String cycleId;
  final CycleStatus cycleStatus;

  const PackListForCycle({super.key, required this.cycleId, required this.cycleStatus});

  @override
  State<PackListForCycle> createState() => PackListForCycleState();
}

class PackListForCycleState extends State<PackListForCycle> {
  final _repository = PackRepository();
  late Future<List<InstrumentPack>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listPacksByCycle(widget.cycleId);
  }

  void refresh() {
    setState(() => _future = _repository.listPacksByCycle(widget.cycleId));
  }

  Future<void> _release(String packId) async {
    await _repository.releasePack(packId);
    refresh();
  }

  Future<void> _quarantine(String packId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Quarantine pack'),
          content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Reason')),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Quarantine'),
            ),
          ],
        );
      },
    );
    if (reason != null && reason.isNotEmpty) {
      await _repository.quarantinePack(packId, reason);
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final canRelease = auth.hasRole([UserRole.hospitalAdmin, UserRole.cssdSupervisor, UserRole.cssdTechnician]);
    final canQuarantine = auth.hasRole([UserRole.hospitalAdmin, UserRole.cssdSupervisor]);

    return FutureBuilder<List<InstrumentPack>>(
      future: _future,
      builder: (context, snapshot) {
        final packs = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (packs.isEmpty) {
          return const Text('No packs registered yet.', style: TextStyle(color: Colors.grey));
        }
        return Column(
          children: packs.map((pack) {
            final canReleaseThis = canRelease && pack.status == PackStatus.pendingVerification && widget.cycleStatus == CycleStatus.passed;
            final canQuarantineThis = canQuarantine &&
                (pack.status == PackStatus.pendingVerification || pack.status == PackStatus.released);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(pack.packCode, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: PackStatusChip(status: pack.status),
              trailing: Wrap(
                spacing: 4,
                children: [
                  if (canReleaseThis)
                    TextButton(onPressed: () => _release(pack.id), child: const Text('Release')),
                  if (canQuarantineThis)
                    TextButton(
                      onPressed: () => _quarantine(pack.id),
                      child: const Text('Quarantine', style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PackDetailPage(packId: pack.id)),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
