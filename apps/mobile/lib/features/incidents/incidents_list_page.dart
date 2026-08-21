import 'package:flutter/material.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/incidents/incident_detail_page.dart';
import 'package:stericord_mobile/features/incidents/incident_model.dart';
import 'package:stericord_mobile/features/incidents/incident_repository.dart';

SteriStatusTone toneForIncidentStatus(IncidentStatus status) {
  switch (status) {
    case IncidentStatus.detected:
    case IncidentStatus.alerted:
      return SteriStatusTone.fail;
    case IncidentStatus.acknowledged:
    case IncidentStatus.quarantineInProgress:
    case IncidentStatus.ncrOpen:
      return SteriStatusTone.warning;
    case IncidentStatus.replacementDispatched:
    case IncidentStatus.replacementReceived:
      return SteriStatusTone.info;
    case IncidentStatus.resolved:
      return SteriStatusTone.pass;
    case IncidentStatus.closed:
      return SteriStatusTone.neutral;
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
        color: AppColors.teal,
        child: FutureBuilder<List<Incident>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SteriLoadingState();
            }
            if (snapshot.hasError) {
              return SteriErrorState(title: 'Unable to load incidents', onRetry: _refresh);
            }
            final incidents = snapshot.data ?? [];
            if (incidents.isEmpty) {
              return const SteriEmptyState(
                icon: Icons.check_circle_outline,
                title: 'No incidents',
                message: 'Safety events for your organization will appear here.',
              );
            }
            // Open incidents first (unresolved severity is the reason anyone
            // opens this screen), most recently detected within each group.
            final sorted = [...incidents]..sort((a, b) {
                final aOpen = a.status != IncidentStatus.resolved && a.status != IncidentStatus.closed;
                final bOpen = b.status != IncidentStatus.resolved && b.status != IncidentStatus.closed;
                if (aOpen != bOpen) return aOpen ? -1 : 1;
                return b.detectedAt.compareTo(a.detectedAt);
              });
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final incident = sorted[index];
                return SteriCard(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => IncidentDetailPage(incidentId: incident.id)),
                    );
                    if (mounted) await _refresh();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(incident.sourceType.replaceAll('_', ' '), style: AppTypography.cardTitle),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          SteriStatusBadge(
                            label: incident.status.dbValue.replaceAll('_', ' '),
                            tone: toneForIncidentStatus(incident.status),
                            compact: true,
                          ),
                        ],
                      ),
                      if (incident.description != null && incident.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          incident.description!,
                          style: AppTypography.metadata,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (incident.priority == 'CRITICAL') ...[
                        const SizedBox(height: AppSpacing.sm),
                        const SteriStatusBadge(label: 'CRITICAL', tone: SteriStatusTone.fail, icon: Icons.priority_high, compact: true),
                      ],
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
