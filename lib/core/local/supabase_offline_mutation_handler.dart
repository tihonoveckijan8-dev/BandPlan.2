import 'package:supabase_flutter/supabase_flutter.dart';

import 'offline_sync_engine.dart';

/// Applies queued mutations through the user's existing Supabase session/RLS.
class SupabaseOfflineMutationHandler {
  const SupabaseOfflineMutationHandler(this._client);

  final SupabaseClient _client;

  Future<void> call(Map<String, Object?> mutation) async {
    final user = _client.auth.currentUser;
    final ownerUserId = mutation['ownerUserId']?.toString() ?? '';
    if (user == null || ownerUserId != user.id) {
      throw StateError('Для синхронизации требуется исходный аккаунт.');
    }

    final collection = mutation['collection']?.toString() ?? '';
    final operation = mutation['operation']?.toString() ?? '';
    final recordId = mutation['recordId']?.toString() ?? '';
    final groupId = mutation['groupId']?.toString();
    final rawPayload = mutation['payload'];
    if (recordId.isEmpty || rawPayload is! Map) {
      throw const FormatException('Повреждённая операция офлайн-очереди.');
    }
    final payload = Map<String, dynamic>.from(rawPayload);

    if (collection == 'profile') {
      if (operation != 'upsert') {
        throw UnsupportedError('Удаление профиля не поддерживается.');
      }
      await _client
          .from('bandplan_accounts')
          .upsert({
            'user_id': ownerUserId,
            'display_name': payload['display_name'],
            'roles': payload['roles'],
            if (payload['updated_at'] != null)
              'updated_at': payload['updated_at'],
          }, onConflict: 'user_id')
          .select('user_id')
          .single();
      return;
    }

    final table = switch (collection) {
      'group_songs' => 'bandplan_songs',
      'group_events' => 'bandplan_events',
      'group_setlists' => 'bandplan_setlists',
      _ => throw UnsupportedError(
          'Офлайн-синхронизация для "$collection" пока не подключена.',
        ),
    };

    if (groupId == null || groupId.isEmpty) {
      throw const FormatException('В операции отсутствует идентификатор группы.');
    }

    if (operation == 'delete') {
      // WHY: a retry after a successful delete must be idempotent. First check
      // whether the row is still visible under the current user's SELECT RLS.
      final existing = await _client
          .from(table)
          .select('id')
          .eq('group_id', groupId)
          .eq('id', recordId)
          .maybeSingle();
      if (existing == null) return;

      final deleted = await _client
          .from(table)
          .delete()
          .eq('group_id', groupId)
          .eq('id', recordId)
          .select('id');
      if (deleted.isEmpty) {
        // WHY: if the row was visible before DELETE but not returned after it,
        // the user's DELETE policy did not confirm the operation.
        throw StateError('Сервер не подтвердил удаление записи $recordId.');
      }
      return;
    }

    if (operation != 'upsert') {
      throw UnsupportedError('Неизвестная операция "$operation".');
    }

    await _client
        .from(table)
        .upsert({
          'group_id': groupId,
          'id': recordId,
          'data': payload,
          'updated_by': ownerUserId,
        }, onConflict: 'group_id,id')
        .select('id')
        .single();
  }
}
