import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:stericord_mobile/core/network/supabase_client_provider.dart';
import 'package:stericord_mobile/core/offline/offline_queue_repository.dart';
import 'package:stericord_mobile/features/cycles/cycle_model.dart';

class EligibilityResult {
  final bool eligible;
  final String? reason;
  const EligibilityResult({required this.eligible, required this.reason});
}

/// Whether a verification reached the server immediately or was captured
/// offline for later sync (section 42) -- the UI shows a different message
/// for each, since "recorded" and "saved, will sync" are not the same
/// promise to make to a nurse in an OT with no signal.
enum RecordVerificationOutcome { submitted, queuedOffline }

class PointOfUseRepository {
  final OfflineQueueRepository _offlineQueue;

  PointOfUseRepository({OfflineQueueRepository? offlineQueue})
      : _offlineQueue = offlineQueue ?? OfflineQueueRepository();

  Future<EligibilityResult> checkEligibility(String packId) async {
    final data = await SupabaseClientProvider.client
        .rpc('check_pack_eligibility', params: {'p_pack_id': packId});
    final row = (data as List).first as Map<String, dynamic>;
    return EligibilityResult(eligible: row['eligible'] as bool, reason: row['reason'] as String?);
  }

  /// Records a point-of-use verification. Tries the network first -- most
  /// scans happen with connectivity, and a direct round-trip surfaces real
  /// eligibility errors (pack already used, expired) immediately rather
  /// than deferring them to a background sync the nurse won't see. Only a
  /// transport-level failure (no connection, timeout, DNS) falls back to
  /// the encrypted offline queue; a server-level rejection is a real error
  /// and is not something retrying later would fix, so it's surfaced as-is.
  ///
  /// The operation id is generated once and used on both the direct attempt
  /// and any queued fallback: a timeout doesn't tell us whether the server
  /// actually committed the write before the connection dropped, so the
  /// direct call must carry the same idempotency key the retry would use --
  /// otherwise a "failed" request that actually succeeded gets duplicated
  /// when the fallback retries it under a different id.
  Future<RecordVerificationOutcome> recordVerification({
    required String packId,
    required VerificationResult result,
    String? departmentId,
    String? patientReference,
    String? encounterReference,
    String? notes,
    String? aiAnalysisId,
  }) async {
    final operationId = const Uuid().v4();
    final payload = {
      'p_pack_id': packId,
      'p_result': result.dbValue,
      'p_department_id': departmentId,
      'p_patient_reference': patientReference,
      'p_encounter_reference': encounterReference,
      'p_notes': notes,
      'p_ai_analysis_id': aiAnalysisId,
    };

    try {
      await SupabaseClientProvider.client.rpc('record_point_of_use_verification', params: {
        ...payload,
        'p_client_operation_id': operationId,
      });
      return RecordVerificationOutcome.submitted;
    } on PostgrestException {
      // The server saw the request and rejected it -- not a connectivity
      // problem, so let the caller handle/display the real error.
      rethrow;
    } catch (_) {
      // Anything else is assumed transport-level: queue it for the
      // SyncService to retry once connectivity returns, reusing the same id.
      await _offlineQueue.enqueue(rpcName: 'record_point_of_use_verification', payload: payload, id: operationId);
      return RecordVerificationOutcome.queuedOffline;
    }
  }
}
