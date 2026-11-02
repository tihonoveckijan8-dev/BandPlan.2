import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';

/// Mirrors the legacy identity rule: an existing account row or the durable
/// Auth metadata marker means onboarding was already completed on another device.
final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  if (!SupabaseBootstrap.isInitialized) return false;
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return false;

  if (user.userMetadata?['bandplan_onboarding_done'] == true) return true;

  final row = await client
      .from('bandplan_accounts')
      .select('user_id')
      .eq('user_id', user.id)
      .maybeSingle();

  return row?['user_id'] == user.id;
});
