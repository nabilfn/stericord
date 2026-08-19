import 'package:stericord_mobile/core/network/supabase_client_provider.dart';
import 'package:stericord_mobile/features/incidents/incident_model.dart';

class IncidentRepository {
  Future<List<Incident>> listIncidents() async {
    final data = await SupabaseClientProvider.client
        .from('incidents')
        .select()
        .order('detected_at', ascending: false);
    return (data as List).map((row) => Incident.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<Incident> getIncident(String id) async {
    final data = await SupabaseClientProvider.client.from('incidents').select().eq('id', id).single();
    return Incident.fromJson(data);
  }

  Future<Incident> acknowledge(String id) async {
    final data =
        await SupabaseClientProvider.client.rpc('acknowledge_incident', params: {'p_incident_id': id});
    return Incident.fromJson(data as Map<String, dynamic>);
  }

  Future<Incident> resolve(String id, String notes, {bool close = false}) async {
    final data = await SupabaseClientProvider.client.rpc('resolve_incident', params: {
      'p_incident_id': id,
      'p_resolution_notes': notes,
      'p_close': close,
    });
    return Incident.fromJson(data as Map<String, dynamic>);
  }
}
