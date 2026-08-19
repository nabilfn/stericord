import 'package:stericord_mobile/core/network/supabase_client_provider.dart';
import 'package:stericord_mobile/features/packs/pack_model.dart';

class PackRepository {
  Future<List<InstrumentSet>> listInstrumentSets() async {
    final data = await SupabaseClientProvider.client
        .from('instrument_sets')
        .select()
        .eq('is_active', true)
        .order('name');
    return (data as List).map((row) => InstrumentSet.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<List<InstrumentPack>> listPacksByCycle(String cycleId) async {
    final data = await SupabaseClientProvider.client
        .from('instrument_packs')
        .select()
        .eq('sterilization_cycle_id', cycleId)
        .order('pack_code');
    return (data as List).map((row) => InstrumentPack.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<InstrumentPack> getPack(String id) async {
    final data = await SupabaseClientProvider.client.from('instrument_packs').select().eq('id', id).single();
    return InstrumentPack.fromJson(data);
  }

  Future<InstrumentPack?> findPackByCode(String code) async {
    final data = await SupabaseClientProvider.client
        .from('instrument_packs')
        .select()
        .or('pack_code.eq.$code,qr_code.eq.$code')
        .maybeSingle();
    if (data == null) return null;
    return InstrumentPack.fromJson(data);
  }

  Future<InstrumentPack> createPack({
    required String organizationId,
    required String instrumentSetId,
    required String cycleId,
    required String packCode,
    String? expiryDate,
  }) async {
    final data = await SupabaseClientProvider.client
        .from('instrument_packs')
        .insert({
          'organization_id': organizationId,
          'instrument_set_id': instrumentSetId,
          'sterilization_cycle_id': cycleId,
          'pack_code': packCode,
          if (expiryDate != null) 'expiry_date': expiryDate,
        })
        .select()
        .single();
    return InstrumentPack.fromJson(data);
  }

  Future<InstrumentPack> releasePack(String packId) async {
    final data = await SupabaseClientProvider.client.rpc('release_pack', params: {'p_pack_id': packId});
    return InstrumentPack.fromJson(data as Map<String, dynamic>);
  }

  Future<InstrumentPack> quarantinePack(String packId, String reason) async {
    final data = await SupabaseClientProvider.client
        .rpc('quarantine_pack', params: {'p_pack_id': packId, 'p_reason': reason});
    return InstrumentPack.fromJson(data as Map<String, dynamic>);
  }
}
