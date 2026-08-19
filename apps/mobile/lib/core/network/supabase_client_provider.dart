import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin accessor around the singleton Supabase client initialized in main.dart.
/// Kept as a single indirection point so a future storage-provider or
/// API-gateway swap does not require touching every feature.
class SupabaseClientProvider {
  static SupabaseClient get client => Supabase.instance.client;
}
