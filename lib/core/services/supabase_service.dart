import 'package:supabase_flutter/supabase_flutter.dart';

/// Global Supabase client accessor.
/// Usage anywhere in the app:
///   SupabaseService.client.from('table_name').select()
class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;
}
