import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
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
      debugPrint('Release pack error: $e');
      setState(() => _error = 'Could not release the pack. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pack')),
      body: FutureBuilder<InstrumentPack>(
        future: _packFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SteriLoadingState();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return SteriErrorState(
              title: 'Unable to load pack',
              onRetry: () => setState(() => _packFuture = _loadPack()),
            );
          }
          final pack = snapshot.data!;
          final auth = context.watch<AuthController>();
          final canRelease = auth.hasRole([UserRole.hospitalAdmin, UserRole.cssdSupervisor, UserRole.cssdTechnician]);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(pack.packCode, style: AppTypography.heroHeader)),
                  PackStatusChip(status: pack.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: AppRadius.panelRadius,
                  ),
                  child: QrImageView(data: pack.qrCode, size: 180),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(child: Text(pack.qrCode, style: AppTypography.metadata)),
              const SizedBox(height: AppSpacing.xl),
              SteriCard(
                child: Column(
                  children: [
                    _DetailRow(label: 'Packed', value: _formatDateTime(pack.packedAt)),
                    _DetailRow(label: 'Sterilized', value: pack.sterilizedAt != null ? _formatDateTime(pack.sterilizedAt!) : null),
                    // expiryDate is a DATE column with no time-of-day component -- format
                    // its UTC y/m/d directly rather than through _formatDateTime's toLocal(),
                    // which could otherwise shift it to the wrong calendar day depending on
                    // the device's timezone offset.
                    _DetailRow(label: 'Expiry', value: pack.expiryDate != null ? _formatDateOnly(pack.expiryDate!) : null, showDivider: false),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.failSoft, borderRadius: BorderRadius.circular(AppRadius.small)),
                  child: Text(_error!, style: const TextStyle(color: AppColors.fail, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ],
              if (canRelease && pack.status == PackStatus.pendingVerification)
                FutureBuilder<SterilizationCycle>(
                  future: _cycleFuture,
                  builder: (context, cycleSnapshot) {
                    final eligible = cycleSnapshot.data?.cycleStatus == CycleStatus.passed;
                    if (!eligible) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: ElevatedButton(onPressed: _release, child: const Text('Release pack')),
                    );
                  },
                ),
              const SizedBox(height: AppSpacing.sectionGap),
              const SteriSectionHeader(title: 'Evidence'),
              const SizedBox(height: AppSpacing.md),
              EvidenceCaptureWidget(entityType: 'instrument_pack', entityId: pack.id),
            ],
          );
        },
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  String _formatDateOnly(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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
              SizedBox(width: 110, child: Text(label, style: AppTypography.metadata)),
              Expanded(child: Text(value ?? '—', style: AppTypography.body)),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}
