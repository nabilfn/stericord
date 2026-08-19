import 'package:stericord_mobile/core/network/supabase_client_provider.dart';
import 'package:stericord_mobile/features/ocr/ocr_model.dart';

class OcrRepository {
  Future<List<OcrExtraction>> listExtractions(String evidenceFileId) async {
    final data = await SupabaseClientProvider.client
        .from('ocr_extractions')
        .select()
        .eq('evidence_file_id', evidenceFileId)
        .order('created_at', ascending: false);
    return (data as List).map((row) => OcrExtraction.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<OcrExtraction> requestExtraction(String evidenceFileId) async {
    final response = await SupabaseClientProvider.client.functions.invoke(
      'ocr-extract',
      body: {'evidence_file_id': evidenceFileId},
    );
    return OcrExtraction.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OcrExtraction> confirmExtraction(String extractionId, ExtractedCycleFields fields) async {
    final data = await SupabaseClientProvider.client.rpc('confirm_ocr_extraction', params: {
      'p_extraction_id': extractionId,
      'p_confirmed_fields': fields.toJson(),
    });
    return OcrExtraction.fromJson(data as Map<String, dynamic>);
  }
}
