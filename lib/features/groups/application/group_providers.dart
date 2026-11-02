import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../data/group_repository.dart';
import '../domain/group_summary.dart';

final groupRepositoryProvider = Provider<GroupRepository?>((ref) {
  if (!SupabaseBootstrap.isInitialized) return null;
  return GroupRepository(Supabase.instance.client);
});

final myGroupsProvider = FutureProvider<List<GroupSummary>>((ref) async {
  final repository = ref.watch(groupRepositoryProvider);
  if (repository == null) {
    throw StateError('Supabase is not configured.');
  }

  final response = await repository.getMyGroups();
  if (response is! List) {
    throw const FormatException('Unexpected groups response from Supabase.');
  }

  return response
      .whereType<Map>()
      .map((item) => GroupSummary.fromJson(
            Map<String, dynamic>.from(item),
          ))
      .toList(growable: false);
});

/// The server validates the saved active group and falls back to a valid
/// membership when the previously selected group is no longer available.
final activeGroupProvider = FutureProvider<GroupSummary?>((ref) async {
  final repository = ref.watch(groupRepositoryProvider);
  if (repository == null) {
    throw StateError('Supabase is not configured.');
  }

  final response = await repository.getMyGroup();
  if (response == null) return null;

  final row = response is List
      ? (response.isEmpty ? null : response.first)
      : response;
  if (row is! Map) {
    throw const FormatException('Unexpected active group response.');
  }

  return GroupSummary.fromJson(Map<String, dynamic>.from(row));
});
