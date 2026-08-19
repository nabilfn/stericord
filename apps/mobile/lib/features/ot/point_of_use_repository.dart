import 'package:stericord_mobile/core/constants/roles.dart';
import 'package:stericord_mobile/core/network/supabase_client_provider.dart';
import 'package:stericord_mobile/features/cycles/cycle_model.dart';

class EligibilityResult {
  final bool eligible;
  final String? reason;
  const EligibilityResult({required this.eligible, required this.reason});
}

class PointOfUseRepository {
  Future<EligibilityResult> checkEligibility(String packId) async {
    final data = await SupabaseClientProvider.client
        .rpc('check_pack_eligibility', params: {'p_pack_id': packId});
    final row = (data as List).first as Map<String, dynamic>;
    return EligibilityResult(eligible: row['eligible'] as bool, reason: row['reason'] as String?);
  }

  Future<void> recordVerification({
    required String packId,
    required VerificationResult result,
    String? departmentId,
    String? patientReference,
    String? encounterReference,
    String? notes,
  }) async {
    await SupabaseClientProvider.client.rpc('record_point_of_use_verification', params: {
      'p_pack_id': packId,
      'p_result': result.dbValue,
      'p_department_id': departmentId,
      'p_patient_reference': patientReference,
      'p_encounter_reference': encounterReference,
      'p_notes': notes,
    });
  }
}
