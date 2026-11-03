import 'dart:convert';

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

      final table = _client.from('bandplan_accounts');
      final baselineCaptured = mutation['baseVersionCaptured'] == true;
      final rawBaseline = mutation['basePayload'];
      final baseline = rawBaseline is Map
          ? Map<String, dynamic>.from(rawBaseline)
          : null;
      final existing = await table
          .select('user_id,display_name,roles,updated_at')
          .eq('user_id', ownerUserId)
          .maybeSingle();
      final values = {
        'user_id': ownerUserId,
        'display_name': payload['display_name'],
        'roles': payload['roles'],
        if (payload['updated_at'] != null) 'updated_at': payload['updated_at'],
      };

      if (existing == null) {
        // WHY: an absent baseline can only create. INSERT, rather than UPSERT,
        // prevents a second device's newly-created profile from being replaced.
        try {
          await table.insert(values).select('user_id').single();
        } on PostgrestException catch (error) {
          if (error.code != '23505') rethrow;
          final latest = await table
              .select('user_id,display_name,roles,updated_at')
              .eq('user_id', ownerUserId)
              .maybeSingle();
          throw OfflineMutationConflict(
            message: 'Профиль был создан на другом устройстве. Локальная версия сохранена.',
            remoteVersionExists: latest != null,
            remotePayload: latest == null
                ? null
                : Map<String, Object?>.from(latest),
          );
        }
        return;
      }

      final baselineUpdatedAt = baseline?['updated_at']?.toString();
      final remoteUpdatedAt = existing['updated_at']?.toString();
      if (!baselineCaptured ||
          baselineUpdatedAt == null ||
          remoteUpdatedAt != baselineUpdatedAt) {
        throw OfflineMutationConflict(
          message: 'Профиль изменился на сервере. Локальная версия сохранена.',
          remoteVersionExists: true,
          remotePayload: Map<String, Object?>.from(existing),
        );
      }

      // WHY: updated_at is the server-side version token. Conditional UPDATE
      // closes the read/write race without changing the existing table or RLS.
      final updated = await table
          .update(values)
          .eq('user_id', ownerUserId)
          .eq('updated_at', baselineUpdatedAt)
          .select('user_id');
      if (updated.isEmpty) {
        final latest = await table
            .select('user_id,display_name,roles,updated_at')
            .eq('user_id', ownerUserId)
            .maybeSingle();
        throw OfflineMutationConflict(
          message: 'Профиль изменился на сервере. Локальная версия сохранена.',
          remoteVersionExists: latest != null,
          remotePayload: latest == null
              ? null
              : Map<String, Object?>.from(latest),
        );
      }
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

    // WHY: compare the current RLS-visible server payload with the snapshot
    // captured when the first local edit was made. Never blindly overwrite a
    // concurrent edit from another device.
    final baselineCaptured = mutation['baseVersionCaptured'] == true;
    final rawBaseline = mutation['basePayload'];
    final existing = await _client
        .from(table)
        .select('id,data')
        .eq('group_id', groupId)
        .eq('id', recordId)
        .maybeSingle();

    if (operation == 'delete') {
      // WHY: deleting an already-missing row is an idempotent success.
      if (existing == null) return;
      if (baselineCaptured) {
        final rawRemote = existing['data'];
        final remotePayload = rawRemote is Map
            ? Map<String, Object?>.from(rawRemote)
            : null;
        if (rawBaseline == null ||
            rawRemote is! Map ||
            !_sameJson(rawRemote, rawBaseline)) {
          throw OfflineMutationConflict(
            message: 'Запись "$recordId" изменилась на сервере. Удаление остановлено.',
            remoteVersionExists: true,
            remotePayload: remotePayload,
          );
        }
      }

      final deleteQuery = _client
          .from(table)
          .delete()
          .eq('group_id', groupId)
          .eq('id', recordId);
      final deleted = baselineCaptured && rawBaseline is Map
          ? await deleteQuery
              .filter('data', 'eq', jsonEncode(rawBaseline))
              .select('id')
          : await deleteQuery.select('id');
      if (deleted.isEmpty) {
        // WHY: compare-and-delete makes the baseline check atomic with the
        // deletion. A second device cannot edit between our read and delete.
        final latest = await _client
            .from(table)
            .select('id,data')
            .eq('group_id', groupId)
            .eq('id', recordId)
            .maybeSingle();
        if (latest == null) return;
        final latestData = latest['data'];
        throw OfflineMutationConflict(
          message: 'Запись "$recordId" изменилась на сервере. Удаление остановлено.',
          remoteVersionExists: true,
          remotePayload: latestData is Map
              ? Map<String, Object?>.from(latestData)
              : null,
        );
      }
      return;
    }

    if (operation != 'upsert') {
      throw UnsupportedError('Неизвестная операция "$operation".');
    }

    if (baselineCaptured) {
      if (existing == null && rawBaseline != null) {
        throw OfflineMutationConflict(
          message: 'Запись "$recordId" была удалена на сервере. Локальная версия сохранена.',
          remoteVersionExists: false,
        );
      }
      if (existing != null) {
        final rawRemote = existing['data'];
        final remotePayload = rawRemote is Map
            ? Map<String, Object?>.from(rawRemote)
            : null;
        if (rawBaseline == null ||
            rawRemote is! Map ||
            !_sameJson(rawRemote, rawBaseline)) {
          throw OfflineMutationConflict(
            message: 'Запись "$recordId" изменилась на сервере. Локальная версия сохранена.',
            remoteVersionExists: true,
            remotePayload: remotePayload,
          );
        }
      }
    }

    final values = {
      'group_id': groupId,
      'id': recordId,
      'data': payload,
      'updated_by': ownerUserId,
    };

    if (baselineCaptured && rawBaseline is Map) {
      // WHY: a read-then-upsert has a race window. Filter the UPDATE by the
      // exact JSONB baseline so Postgres performs compare-and-swap atomically.
      final updated = await _client
          .from(table)
          .update(values)
          .eq('group_id', groupId)
          .eq('id', recordId)
          .filter('data', 'eq', jsonEncode(rawBaseline))
          .select('id');
      if (updated.isEmpty) {
        final latest = await _client
            .from(table)
            .select('id,data')
            .eq('group_id', groupId)
            .eq('id', recordId)
            .maybeSingle();
        if (latest == null) {
          throw OfflineMutationConflict(
            message: 'Запись "$recordId" была удалена на сервере. Локальная версия сохранена.',
            remoteVersionExists: false,
          );
        }
        final latestData = latest['data'];
        throw OfflineMutationConflict(
          message: 'Запись "$recordId" изменилась на сервере. Локальная версия сохранена.',
          remoteVersionExists: true,
          remotePayload: latestData is Map
              ? Map<String, Object?>.from(latestData)
              : null,
        );
      }
      return;
    }

    if (baselineCaptured && rawBaseline == null) {
      // WHY: create must not overwrite a row created by another device after
      // our initial absence check. A unique-key collision is surfaced as a
      // conflict instead of falling back to an upsert.
      try {
        await _client.from(table).insert(values).select('id').single();
      } on PostgrestException catch (error) {
        if (error.code != '23505') rethrow;
        final latest = await _client
            .from(table)
            .select('id,data')
            .eq('group_id', groupId)
            .eq('id', recordId)
            .maybeSingle();
        final latestData = latest?['data'];
        throw OfflineMutationConflict(
          message: 'Запись "$recordId" уже создана на сервере. Локальная версия сохранена.',
          remoteVersionExists: latest != null,
          remotePayload: latestData is Map
              ? Map<String, Object?>.from(latestData)
              : null,
        );
      }
      return;
    }

    await _client
        .from(table)
        .upsert(values, onConflict: 'group_id,id')
        .select('id')
        .single();
  }

  static bool _sameJson(Object? left, Object? right) {
    String canonical(Object? value) {
      if (value is Map) {
        final keys = value.keys.map((key) => key.toString()).toList()..sort();
        return '{${keys.map((key) => '${jsonEncode(key)}:${canonical(value[key])}').join(',')}}';
      }
      if (value is List) {
        return '[${value.map(canonical).join(',')}]';
      }
      return jsonEncode(value);
    }

    return canonical(left) == canonical(right);
  }
}
