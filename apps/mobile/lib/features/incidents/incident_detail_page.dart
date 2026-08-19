import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stericord_mobile/core/constants/roles.dart';
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
      setState(() => _error = e.toString());
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
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final canManage = auth.hasRole([UserRole.hospitalAdmin, UserRole.cssdSupervisor]);

    return Scaffold(
      appBar: AppBar(title: const Text('Incident Detail')),
      body: FutureBuilder<Incident>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final incident = snapshot.data!;
          final canAct = canManage && !['RESOLVED', 'CLOSED'].contains(incident.status.dbValue);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(incident.sourceType.replaceAll('_', ' '), style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  Chip(
                    label: Text(incident.status.dbValue.replaceAll('_', ' '), style: const TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: colorForIncidentStatus(incident.status),
                  ),
                ],
              ),
              Text('Detected ${incident.detectedAt.toLocal()}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Text(incident.description ?? ''),
              if (incident.resolutionNotes != null) ...[
                const Divider(height: 32),
                Text('Resolution', style: Theme.of(context).textTheme.titleSmall),
                Text(incident.resolutionNotes!),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              if (canAct) ...[
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  children: [
                    if (['DETECTED', 'ALERTED'].contains(incident.status.dbValue))
                      ElevatedButton(onPressed: _acknowledge, child: const Text('Acknowledge')),
                    OutlinedButton(onPressed: () => _resolve(close: false), child: const Text('Resolve')),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
}
