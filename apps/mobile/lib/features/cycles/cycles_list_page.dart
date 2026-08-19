import 'package:flutter/material.dart';
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
        child: FutureBuilder<List<SterilizationCycle>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [Padding(padding: const EdgeInsets.all(24), child: Text('Failed to load cycles: ${snapshot.error}'))],
              );
            }
            final cycles = snapshot.data ?? [];
            if (cycles.isEmpty) {
              return ListView(
                children: const [Padding(padding: EdgeInsets.all(24), child: Text('No cycles yet.'))],
              );
            }
            return ListView.separated(
              itemCount: cycles.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final cycle = cycles[index];
                return ListTile(
                  title: Text(cycle.cycleNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(cycle.cycleType),
                  trailing: CycleStatusChip(status: cycle.cycleStatus),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => CycleDetailPage(cycleId: cycle.id)),
                    );
                    if (mounted) await _refresh();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
