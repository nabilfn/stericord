import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/capture/evidence_capture_widget.dart';
import 'package:stericord_mobile/features/cycles/cycle_model.dart';
import 'package:stericord_mobile/features/cycles/cycle_repository.dart';
import 'package:stericord_mobile/features/packs/pack_model.dart';
import 'package:stericord_mobile/features/packs/pack_repository.dart';
import 'package:stericord_mobile/features/packs/pack_status_chip.dart';

class PackDetailPage extends StatefulWidget {
  final String packId;
  const PackDetailPage({super.key, required this.packId});

  @override
  State<PackDetailPage> createState() => _PackDetailPageState();
}

class _PackDetailPageState extends State<PackDetailPage> {
  final _packRepository = PackRepository();
  final _cycleRepository = CycleRepository();
  late Future<InstrumentPack> _packFuture;
  Future<SterilizationCycle>? _cycleFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _packFuture = _loadPack();
  }

  Future<InstrumentPack> _loadPack() async {
    final pack = await _packRepository.getPack(widget.packId);
    setState(() => _cycleFuture = _cycleRepository.getCycle(pack.sterilizationCycleId));
    return pack;
  }

  Future<void> _release() async {
    try {
      await _packRepository.releasePack(widget.packId);
      setState(() {
        _packFuture = _loadPack();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pack Detail')),
      body: FutureBuilder<InstrumentPack>(
        future: _packFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final pack = snapshot.data!;
          final auth = context.watch<AuthController>();
          final canRelease = auth.hasRole([UserRole.hospitalAdmin, UserRole.cssdSupervisor, UserRole.cssdTechnician]);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(pack.packCode, style: Theme.of(context).textTheme.headlineSmall),
                  PackStatusChip(status: pack.status),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: QrImageView(data: pack.qrCode, size: 180),
                ),
              ),
              const SizedBox(height: 8),
              Center(child: Text(pack.qrCode, style: const TextStyle(color: Colors.grey, fontSize: 12))),
              const SizedBox(height: 20),
              _DetailRow(label: 'Packed', value: pack.packedAt.toLocal().toString()),
              _DetailRow(label: 'Sterilized', value: pack.sterilizedAt?.toLocal().toString()),
              _DetailRow(label: 'Expiry', value: pack.expiryDate?.toLocal().toString()),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              if (canRelease && pack.status == PackStatus.pendingVerification)
                FutureBuilder<SterilizationCycle>(
                  future: _cycleFuture,
                  builder: (context, cycleSnapshot) {
                    final eligible = cycleSnapshot.data?.cycleStatus == CycleStatus.passed;
                    if (!eligible) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ElevatedButton(onPressed: _release, child: const Text('Release Pack')),
                    );
                  },
                ),
              const SizedBox(height: 24),
              Text('Evidence', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              EvidenceCaptureWidget(entityType: 'instrument_pack', entityId: pack.id),
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
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value ?? '—')),
        ],
      ),
    );
  }
}
