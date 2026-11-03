import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/local/network_error.dart';
import '../../../core/local/offline_store.dart';
import '../../../core/local/offline_providers.dart';
import '../../../core/supabase/supabase_bootstrap.dart';

/// Mirrors the legacy identity rule and remembers a server-confirmed onboarding
/// decision so an already onboarded account can open the app without a network.
final onboardingCompleteProvider = FutureProvider<bool>((ref) async {
  if (!SupabaseBootstrap.isInitialized) return false;
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return false;

  final store = await ref.watch(offlineStoreProvider.future);

  if (user.userMetadata?['bandplan_onboarding_done'] == true) {
    await _cacheDecision(store, user.id, true);
    return true;
  }

  try {
    final row = await client
        .from('bandplan_accounts')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();
    final complete = row?['user_id'] == user.id;
    await _cacheDecision(store, user.id, complete);
    return complete;
  } catch (error) {
    if (!isOfflineNetworkError(error)) rethrow;

    final cached = await store.readCachedRecords(
      ownerUserId: user.id,
      collection: 'onboarding',
    );
    if (cached.isNotEmpty && cached.first['payload'] is Map) {
      final decision = (cached.first['payload'] as Map)['complete'];
      if (decision is bool) return decision;
    }

    // WHY: older installs may have a confirmed profile or group snapshot but
    // no onboarding marker yet; those server-derived records prove setup.
    final profile = await store.readCachedRecords(
      ownerUserId: user.id,
      collection: 'profile',
    );
    if (profile.any((record) {
      final payload = record['payload'];
      return payload is Map && payload['user_id']?.toString() == user.id;
    })) {
      await _cacheDecision(store, user.id, true);
      return true;
    }

    for (final collection in ['active_group', 'my_groups']) {
      final groups = await store.readCachedRecords(
        ownerUserId: user.id,
        collection: collection,
      );
      if (groups.any((record) {
        final payload = record['payload'];
        return payload is Map &&
            (payload['group_id'] ?? payload['id'])?.toString().isNotEmpty == true;
      })) {
        await _cacheDecision(store, user.id, true);
        return true;
      }
    }

    rethrow;
  }
});

Future<void> _cacheDecision(
  OfflineStore store,
  String userId,
  bool complete,
) =>
    store.cacheRemoteRecord(
      ownerUserId: userId,
      collection: 'onboarding',
      recordId: 'complete',
      payload: {'complete': complete},
    );
