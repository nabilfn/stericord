import 'package:stericord_mobile/core/network/supabase_client_provider.dart';
import 'package:stericord_mobile/features/equipment/equipment_model.dart';

class EquipmentRepository {
  Future<List<Equipment>> listEquipment() async {
    final data = await SupabaseClientProvider.client
        .from('equipment')
        .select()
        .order('equipment_code', ascending: true);
    return (data as List).map((row) => Equipment.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<Equipment> getEquipment(String id) async {
    final data = await SupabaseClientProvider.client.from('equipment').select().eq('id', id).single();
    return Equipment.fromJson(data);
  }

  Future<List<EquipmentStatusEvent>> getStatusHistory(String equipmentId) async {
    final data = await SupabaseClientProvider.client
        .from('equipment_status_events')
        .select()
        .eq('equipment_id', equipmentId)
        .order('changed_at', ascending: false);
    return (data as List)
        .map((row) => EquipmentStatusEvent.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
