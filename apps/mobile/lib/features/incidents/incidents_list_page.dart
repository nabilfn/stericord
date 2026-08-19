import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/incidents/incident_detail_page.dart';
import 'package:stericord_mobile/features/incidents/incident_model.dart';
import 'package:stericord_mobile/features/incidents/incident_repository.dart';

Color colorForIncidentStatus(IncidentStatus status) {
  switch (status) {
    case IncidentStatus.detected:
    case IncidentStatus.alerted:
      return AppColors.fail;
    case IncidentStatus.acknowledged:
    case IncidentStatus.quarantineInProgress:
    case IncidentStatus.ncrOpen:
      return AppColors.warning;
    case IncidentStatus.replacementDispatched:
    case IncidentStatus.replacementReceived:
      return AppColors.scBlue;
    case IncidentStatus.resolved:
      return AppColors.pass;
    case IncidentStatus.closed:
      return Colors.grey;
  }
}

class IncidentsListPage extends StatefulWidget {
  const IncidentsListPage({super.key});

  @override
  State<IncidentsListPage> createState() => _IncidentsListPageState();
}

class _IncidentsListPageState extends State<IncidentsListPage> {
  final _repository = IncidentRepository();
  late Future<List<Incident>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listIncidents();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.listIncidents());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Incidents')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Incident>>(
          future: _future,
          builder: (context, snapshot) {
            final incidents = snapshot.data ?? [];
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (incidents.isEmpty) {
              return ListView(
                children: const [Padding(padding: EdgeInsets.all(24), child: Text('No incidents recorded.'))],
              );
            }
            return ListView.separated(
              itemCount: incidents.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final incident = incidents[index];
                return ListTile(
                  title: Text(incident.sourceType.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(incident.description ?? ''),
                  trailing: Chip(
                    label: Text(incident.status.dbValue.replaceAll('_', ' '), style: const TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: colorForIncidentStatus(incident.status),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => IncidentDetailPage(incidentId: incident.id)),
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
