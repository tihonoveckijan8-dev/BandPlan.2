import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  if (!SupabaseBootstrap.isInitialized) return null;
  return AuthRepository(Supabase.instance.client);
});

final authStateProvider = StreamProvider<AuthState?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  if (repository == null) return const Stream<AuthState?>.empty();
  return repository.authStateChanges;
});
