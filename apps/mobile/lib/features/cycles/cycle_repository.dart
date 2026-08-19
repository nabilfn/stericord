import 'package:stericord_mobile/core/network/supabase_client_provider.dart';
import 'package:stericord_mobile/features/cycles/cycle_model.dart';

class CycleRepository {
  Future<List<SterilizationCycle>> listCycles() async {
    final data = await SupabaseClientProvider.client
        .from('sterilization_cycles')
        .select()
        .order('created_at', ascending: false);
    return (data as List)
        .map((row) => SterilizationCycle.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<SterilizationCycle> getCycle(String id) async {
    final data =
        await SupabaseClientProvider.client.from('sterilization_cycles').select().eq('id', id).single();
    return SterilizationCycle.fromJson(data);
  }

  Future<SterilizationCycle> createCycle({
    required String organizationId,
    required String equipmentId,
    required String cycleNumber,
    required String cycleType,
    required String operatorUserId,
  }) async {
    final data = await SupabaseClientProvider.client
        .from('sterilization_cycles')
        .insert({
          'organization_id': organizationId,
          'equipment_id': equipmentId,
          'cycle_number': cycleNumber,
          'cycle_type': cycleType,
          'operator_user_id': operatorUserId,
        })
        .select()
        .single();
    return SterilizationCycle.fromJson(data);
  }

  Future<SterilizationCycle> startCycle(String cycleId) async {
    final data = await SupabaseClientProvider.client.rpc('start_cycle', params: {'p_cycle_id': cycleId});
    return SterilizationCycle.fromJson(data as Map<String, dynamic>);
  }

  Future<SterilizationCycle> completeCycle(
    String cycleId, {
    double? temperature,
    double? pressure,
    int? holdTimeSeconds,
  }) async {
    final data = await SupabaseClientProvider.client.rpc('complete_cycle', params: {
      'p_cycle_id': cycleId,
      'p_temperature': temperature,
      'p_pressure': pressure,
      'p_hold_time_seconds': holdTimeSeconds,
    });
    return SterilizationCycle.fromJson(data as Map<String, dynamic>);
  }

  Future<SterilizationCycle> submitForVerification(String cycleId) async {
    final data = await SupabaseClientProvider.client
        .rpc('submit_cycle_for_verification', params: {'p_cycle_id': cycleId});
    return SterilizationCycle.fromJson(data as Map<String, dynamic>);
  }

  Future<SterilizationCycle> verifyCycle(
    String cycleId,
    VerificationResult result, {
    String? notes,
    String? aiAnalysisId,
  }) async {
    final data = await SupabaseClientProvider.client.rpc('verify_cycle', params: {
      'p_cycle_id': cycleId,
      'p_result': result.dbValue,
      'p_notes': notes,
      'p_ai_analysis_id': aiAnalysisId,
    });
    return SterilizationCycle.fromJson(data as Map<String, dynamic>);
  }
}
