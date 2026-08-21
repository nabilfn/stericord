import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/cycles/cycle_model.dart';
import 'package:stericord_mobile/features/cycles/cycle_repository.dart';
import 'package:stericord_mobile/features/cycles/cycle_status_chip.dart';
import 'package:stericord_mobile/features/cycles/cycle_detail_page.dart';
import 'package:stericord_mobile/features/cycles/create_cycle_sheet.dart';

class CyclesListPage extends StatefulWidget {
  const CyclesListPage({super.key});

  @override
  State<CyclesListPage> createState() => _CyclesListPageState();
}

class _CyclesListPageState extends State<CyclesListPage> {
  final _repository = CycleRepository();
  late Future<List<SterilizationCycle>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listCycles();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.listCycles());
    await _future;
  }

  Future<void> _createCycle() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const CreateCycleSheet(),
    );
    if (created == true) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sterilization Cycles'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _createCycle)],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.teal,
        child: FutureBuilder<List<SterilizationCycle>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SteriLoadingState();
            }
            if (snapshot.hasError) {
              return SteriErrorState(title: 'Unable to load cycles', onRetry: _refresh);
            }
            final cycles = snapshot.data ?? [];
            if (cycles.isEmpty) {
              return SteriEmptyState(
                icon: Icons.layers_outlined,
                title: 'No cycles yet',
                message: 'Start the first sterilization cycle for your equipment.',
                actionLabel: 'New cycle',
                onAction: _createCycle,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: cycles.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final cycle = cycles[index];
                return SteriCard(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CycleDetailPage(cycleId: cycle.id)),
                    );
                    if (mounted) await _refresh();
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cycle ${cycle.cycleNumber}', style: AppTypography.cardTitle),
                            const SizedBox(height: 4),
                            Text(cycle.cycleType, style: AppTypography.metadata),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      CycleStatusChip(status: cycle.cycleStatus),
                    ],
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
