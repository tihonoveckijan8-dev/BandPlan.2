import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/events/data/event_repository.dart';
import '../../features/groups/data/group_repository.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/setlists/data/setlist_repository.dart';
import '../../features/songs/data/song_repository.dart';
import 'offline_store.dart';

/// Best-effort prefetch of account data needed by every app tab.
abstract final class OfflineCacheWarmup {
  static Future<void> run({
    required SupabaseClient client,
    required OfflineStore store,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    final groups = GroupRepository(client, offlineStore: store);
    final profile = ProfileRepository(client, offlineStore: store);
    final songs = SongRepository(client, offlineStore: store);
    final events = EventRepository(client, offlineStore: store);
    final setlists = SetlistRepository(client, offlineStore: store);

    // WHY: Group and active-group snapshots establish which account-scoped
    // datasets should be prefetched, while profile and personal songs are
    // independent and can warm in parallel.
    final groupsFuture = _try(() => groups.getMyGroups());
    final activeGroupFuture = _try(() => groups.getMyGroup());

    await Future.wait<void>([
      _ignore(() => profile.getMyProfile()),
      _ignore(() => songs.refreshAndCachePersonalSongs(user.id)),
    ]);

    final groupResponse = await groupsFuture;
    final activeGroupResponse = await activeGroupFuture;
    final groupIds = <String>{};

    if (groupResponse is List) {
      for (final row in groupResponse.whereType<Map>()) {
        final id = _idFromRow(row);
        if (id != null) groupIds.add(id);
      }
    }
    final activeGroupId = _idFromUnknownRow(activeGroupResponse);
    if (activeGroupId != null) groupIds.add(activeGroupId);

    // WHY: Cache every group the account can switch to, not only the currently
    // selected one, so offline group switching does not expose empty screens.
    for (final groupId in groupIds) {
      await Future.wait<void>([
        _ignore(() => songs.refreshAndCacheGroupSongs(user.id, groupId)),
        _ignore(() => events.refreshAndCacheGroupEvents(user.id, groupId)),
        _ignore(() => setlists.refreshAndCacheGroupSetlists(user.id, groupId)),
      ]);
    }
  }

  static String? _idFromUnknownRow(Object? value) {
    final row = value is List ? (value.isEmpty ? null : value.first) : value;
    return row is Map ? _idFromRow(row) : null;
  }

  static String? _idFromRow(Map row) {
    final id = (row['group_id'] ?? row['id'])?.toString().trim() ?? '';
    return id.isEmpty ? null : id;
  }

  static Future<T?> _try<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _ignore<T>(Future<T> Function() action) async {
    try {
      await action();
    } catch (_) {
      // WHY: Offline or unavailable datasets must not block other cache warmups.
    }
  }
}
