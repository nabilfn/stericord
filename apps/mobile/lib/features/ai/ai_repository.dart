import 'package:stericord_mobile/core/network/supabase_client_provider.dart';
import 'package:stericord_mobile/features/ai/ai_model.dart';

const indicatorEvidenceTypes = [
  'BOWIE_DICK',
  'CHEMICAL_INDICATOR',
  'BI_TRAY',
  'OT_INDICATOR',
  'WASHER_TEST',
];

class AiRepository {
  Future<List<AiAnalysis>> listAnalyses(String evidenceFileId) async {
    final data = await SupabaseClientProvider.client
        .from('ai_analyses')
        .select()
        .eq('evidence_file_id', evidenceFileId)
        .order('created_at', ascending: false);
    return (data as List).map((row) => AiAnalysis.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<AiAnalysis> requestAnalysis(String evidenceFileId) async {
    final response = await SupabaseClientProvider.client.functions.invoke(
      'gemini-analyze',
      body: {'evidence_file_id': evidenceFileId},
    );
    return AiAnalysis.fromJson(response.data as Map<String, dynamic>);
  }

  /// Most recent completed AI analysis of any indicator evidence attached to
  /// a cycle/pack, for pre-filling the verification form.
  Future<AiAnalysis?> getLatestIndicatorAnalysis(String entityType, String entityId) async {
    final files = await SupabaseClientProvider.client
        .from('evidence_files')
        .select('id')
        .eq('entity_type', entityType)
        .eq('entity_id', entityId)
        .inFilter('evidence_type', indicatorEvidenceTypes);
    final fileIds = (files as List).map((f) => f['id'] as String).toList();
    if (fileIds.isEmpty) return null;

    final data = await SupabaseClientProvider.client
        .from('ai_analyses')
        .select()
        .inFilter('evidence_file_id', fileIds)
        .eq('status', 'COMPLETED')
        .order('created_at', ascending: false)
        .limit(1);
    final rows = data as List;
    return rows.isEmpty ? null : AiAnalysis.fromJson(rows.first as Map<String, dynamic>);
  }
}
