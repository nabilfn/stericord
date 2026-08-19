import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:stericord_mobile/core/network/supabase_client_provider.dart';
import 'package:stericord_mobile/features/capture/evidence_model.dart';

class EvidenceRepository {
  static const _bucket = 'evidence';

  Future<List<EvidenceFile>> listEvidence(String entityType, String entityId) async {
    final data = await SupabaseClientProvider.client
        .from('evidence_files')
        .select()
        .eq('entity_type', entityType)
        .eq('entity_id', entityId)
        .order('captured_at', ascending: false);
    return (data as List).map((row) => EvidenceFile.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<EvidenceFile> uploadEvidence({
    required String organizationId,
    required String entityType,
    required String entityId,
    required EvidenceType evidenceType,
    required File file,
    required String capturedBy,
  }) async {
    final bytes = await file.readAsBytes();
    final sha256Hash = sha256.convert(bytes).toString();
    final fileName = file.uri.pathSegments.last;
    final objectPath =
        '$organizationId/$entityType/$entityId/${DateTime.now().millisecondsSinceEpoch}-$fileName';

    await SupabaseClientProvider.client.storage.from(_bucket).uploadBinary(objectPath, bytes);

    final data = await SupabaseClientProvider.client
        .from('evidence_files')
        .insert({
          'organization_id': organizationId,
          'entity_type': entityType,
          'entity_id': entityId,
          'bucket': _bucket,
          'object_path': objectPath,
          'mime_type': 'image/jpeg',
          'file_size': bytes.length,
          'sha256_hash': sha256Hash,
          'evidence_type': evidenceType.dbValue,
          'captured_by': capturedBy,
        })
        .select()
        .single();
    return EvidenceFile.fromJson(data);
  }

  Future<String> getSignedUrl(String objectPath) async {
    return SupabaseClientProvider.client.storage.from(_bucket).createSignedUrl(objectPath, 60 * 5);
  }
}
