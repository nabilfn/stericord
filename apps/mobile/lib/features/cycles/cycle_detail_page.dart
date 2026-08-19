import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
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
    final cycle = await _cycleRepository.getCycle(widget.cycleId);
    setState(() => _equipmentFuture = _equipmentRepository.getEquipment(cycle.equipmentId));
    return cycle;
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
      setState(() => _error = e.toString());
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
      appBar: AppBar(title: const Text('Cycle Detail')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<SterilizationCycle>(
          future: _cycleFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final cycle = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cycle.cycleNumber, style: Theme.of(context).textTheme.headlineSmall),
                          FutureBuilder<Equipment>(
                            future: _equipmentFuture,
                            builder: (context, eqSnapshot) => Text(
                              '${cycle.cycleType} · ${eqSnapshot.data?.equipmentCode ?? '…'}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                    CycleStatusChip(status: cycle.cycleStatus),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                if (canOperate) _buildActionButton(cycle, canVerify),
                const SizedBox(height: 24),
                Text('Cycle Parameters', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _paramRow('Temperature', cycle.temperature != null ? '${cycle.temperature} °C' : null),
                _paramRow('Pressure', cycle.pressure != null ? '${cycle.pressure} bar' : null),
                _paramRow('Hold time', cycle.holdTimeSeconds != null ? '${cycle.holdTimeSeconds}s' : null),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Instrument Packs', style: Theme.of(context).textTheme.titleMedium),
                    if (canOperate &&
                        (cycle.cycleStatus == CycleStatus.created || cycle.cycleStatus == CycleStatus.running))
                      TextButton.icon(
                        onPressed: () async {
                          final created = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => RegisterPackSheet(cycleId: cycle.id),
                          );
                          if (created == true) _packListKey.currentState?.refresh();
                        },
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Register'),
                      ),
                  ],
                ),
                PackListForCycle(key: _packListKey, cycleId: cycle.id, cycleStatus: cycle.cycleStatus),
                const SizedBox(height: 24),
                Text('Evidence', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
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
          child: const Text('Start Cycle'),
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
          child: const Text('Complete Cycle'),
        );
      case CycleStatus.completed:
        return ElevatedButton(
          onPressed: _busy ? null : () => _runAction(() => _cycleRepository.submitForVerification(cycle.id)),
          child: const Text('Submit for Verification'),
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
          child: const Text('Verify Cycle'),
        );
      case CycleStatus.passed:
      case CycleStatus.failed:
      case CycleStatus.quarantined:
        return const SizedBox.shrink();
    }
  }

  Widget _paramRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Text(value ?? '—'),
        ],
      ),
    );
  }
}
