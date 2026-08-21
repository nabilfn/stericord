import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/components/components.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/core/theme/app_theme.dart';
import 'package:stericord_mobile/features/auth/auth_controller.dart';
import 'package:stericord_mobile/features/incidents/incident_model.dart';
import 'package:stericord_mobile/features/incidents/incident_repository.dart';
import 'package:stericord_mobile/features/incidents/incidents_list_page.dart';

class IncidentDetailPage extends StatefulWidget {
  final String incidentId;
  const IncidentDetailPage({super.key, required this.incidentId});

  @override
  State<IncidentDetailPage> createState() => _IncidentDetailPageState();
}

class _IncidentDetailPageState extends State<IncidentDetailPage> {
  final _repository = IncidentRepository();
  late Future<Incident> _future;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _repository.getIncident(widget.incidentId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _repository.getIncident(widget.incidentId);
      _error = null;
    });
  }

  Future<void> _acknowledge() async {
    try {
      await _repository.acknowledge(widget.incidentId);
      await _refresh();
    } catch (e) {
      debugPrint('Acknowledge incident error: $e');
      setState(() => _error = 'Could not acknowledge this incident. Try again.');
    }
  }

  Future<void> _resolve({required bool close}) async {
    final notes = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(close ? 'Close incident' : 'Resolve incident'),
          content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Notes')),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Submit')),
          ],
        );
      },
    );
    if (notes == null || notes.isEmpty) return;
    try {
      await _repository.resolve(widget.incidentId, notes, close: close);
      await _refresh();
    } catch (e) {
      debugPrint('Resolve incident error: $e');
      setState(() => _error = 'Could not update this incident. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final canManage = auth.hasRole([UserRole.hospitalAdmin, UserRole.cssdSupervisor]);

    return Scaffold(
      appBar: AppBar(title: const Text('Incident')),
      body: FutureBuilder<Incident>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SteriLoadingState();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return SteriErrorState(title: 'Unable to load incident', onRetry: _refresh);
          }
          final incident = snapshot.data!;
          final canAct = canManage && incident.status != IncidentStatus.resolved && incident.status != IncidentStatus.closed;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(incident.sourceType.replaceAll('_', ' '), style: AppTypography.heroHeader),
                        const SizedBox(height: 2),
                        Text('Detected ${_formatDateTime(incident.detectedAt)}', style: AppTypography.metadata),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SteriStatusBadge(
                    label: incident.status.dbValue.replaceAll('_', ' '),
                    tone: toneForIncidentStatus(incident.status),
                  ),
                ],
              ),
              if (incident.priority == 'CRITICAL') ...[
                const SizedBox(height: AppSpacing.md),
                const SteriStatusBadge(label: 'CRITICAL PRIORITY', tone: SteriStatusTone.fail, icon: Icons.priority_high),
              ],
              if (incident.description != null && incident.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                SteriCard(child: Text(incident.description!, style: AppTypography.body)),
              ],
              if (incident.resolutionNotes != null) ...[
                const SizedBox(height: AppSpacing.sectionGap),
                const SteriSectionHeader(title: 'Resolution'),
                const SizedBox(height: AppSpacing.md),
                SteriCard(child: Text(incident.resolutionNotes!, style: AppTypography.body)),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.failSoft, borderRadius: BorderRadius.circular(AppRadius.small)),
                  child: Text(_error!, style: const TextStyle(color: AppColors.fail, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ],
              if (canAct) ...[
                const SizedBox(height: AppSpacing.sectionGap),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    if (incident.status == IncidentStatus.detected || incident.status == IncidentStatus.alerted)
                      ElevatedButton(onPressed: _acknowledge, child: const Text('Acknowledge')),
                    OutlinedButton(onPressed: () => _resolve(close: false), child: const Text('Resolve')),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.fail),
                      onPressed: () => _resolve(close: true),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
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
}
