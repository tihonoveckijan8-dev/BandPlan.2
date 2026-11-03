import 'offline_store.dart';
import 'network_error.dart';

typedef OfflineMutationApplier = Future<void> Function(
  Map<String, Object?> mutation,
);

/// A durable outbox drain. Mutations are sent sequentially and acknowledged
/// only after the remote adapter confirms the write.
class OfflineSyncEngine {
  OfflineSyncEngine({
    required OfflineStore store,
    required String? Function() currentUserId,
    required OfflineMutationApplier applyMutation,
  })  : _store = store,
        _currentUserId = currentUserId,
        _applyMutation = applyMutation;

  final OfflineStore _store;
  final String? Function() _currentUserId;
  final OfflineMutationApplier _applyMutation;
  Future<SyncReport>? _inFlight;

  Future<SyncReport> syncPending({
    bool force = false,
    bool retryFailed = false,
  }) {
    final active = _inFlight;
    if (active != null) return active;

    final operation = _run(
      force: force,
      retryFailed: retryFailed,
    );
    _inFlight = operation;
    return operation.whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
  }

  Future<SyncReport> _run({
    required bool force,
    required bool retryFailed,
  }) async {
    final userId = _currentUserId();
    if (userId == null || userId.trim().isEmpty) {
      return const SyncReport();
    }

    if (retryFailed) {
      await _store.retryFailedMutations(ownerUserId: userId);
    }

    var syncedCount = 0;
    String? lastError;
    final pending = await _store.readPendingMutations(ownerUserId: userId);

    for (final mutation in pending) {
      if (mutation['status'] == 'failed') {
        lastError ??= mutation['lastError']?.toString();
        break;
      }

      if (!force && !_isRetryDue(mutation)) break;

      final operationId = mutation['operationId']?.toString() ?? '';
      if (operationId.isEmpty) {
        lastError = 'В очереди обнаружена операция без идентификатора.';
        break;
      }

      try {
        await _applyMutation(mutation);
        await _store.acknowledgeMutation(operationId);
        syncedCount++;
      } catch (error) {
        lastError = error.toString();
        if (isOfflineNetworkError(error)) {
          await _store.recordRetry(
            operationId: operationId,
            error: lastError,
          );
        } else {
          await _store.recordFailure(
            operationId: operationId,
            error: lastError,
          );
        }
        // WHY: preserve mutation order. A later edit/delete must not overtake
        // an earlier operation for the same record after a failed request.
        break;
      }
    }

    final remaining = await _store.readPendingMutations(ownerUserId: userId);
    final failedCount = remaining
        .where((item) => item['status'] == 'failed')
        .length;
    if (lastError == null) {
      for (final item in remaining) {
        final value = item['lastError']?.toString();
        if (value != null && value.isNotEmpty) {
          lastError = value;
          break;
        }
      }
    }

    return SyncReport(
      syncedCount: syncedCount,
      pendingCount: remaining.length,
      failedCount: failedCount,
      lastError: lastError,
    );
  }

  bool _isRetryDue(Map<String, Object?> mutation) {
    final attempts = (mutation['attemptCount'] as num?)?.toInt() ?? 0;
    if (attempts <= 0) return true;
    final lastAttempt = DateTime.tryParse(
      mutation['lastAttemptAt']?.toString() ?? '',
    );
    if (lastAttempt == null) return true;
    final exponent = attempts > 6 ? 6 : attempts - 1;
    final delaySeconds = (5 * (1 << exponent)).clamp(5, 300).toInt();
    return DateTime.now().toUtc().isAfter(
      lastAttempt.add(Duration(seconds: delaySeconds)),
    );
  }
}

class SyncReport {
  const SyncReport({
    this.syncedCount = 0,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.lastError,
  });

  final int syncedCount;
  final int pendingCount;
  final int failedCount;
  final String? lastError;

  bool get hasPending => pendingCount > 0;
  bool get hasPermanentFailure => failedCount > 0;
}
