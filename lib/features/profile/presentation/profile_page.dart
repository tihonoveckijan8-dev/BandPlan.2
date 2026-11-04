import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/application/auth_providers.dart';
import '../../../core/local/offline_providers.dart';
import '../../groups/presentation/group_workspace_page.dart';
import '../application/profile_providers.dart';
import 'appearance_settings_tab.dart';
import 'element_customization_tab.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, this.initialSection = 0});

  final int initialSection;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  final _rolesController = TextEditingController();
  String? _loadedUserId;
  bool _saving = false;
  bool _syncing = false;

  static final _androidApkUri = Uri.parse(
    'https://github.com/tihonoveckijan8-dev/BandPlan.2/releases/download/'
    'android-latest/BandPlan-android.apk',
  );
  static final _webAppUri = Uri.parse(
    'https://tihonoveckijan8-dev.github.io/BandPlan.2/',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _rolesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _message('Укажите имя.');
      return;
    }

    final repository = await ref.read(profileRepositoryProvider.future);

    final roles = _rolesController.text
        .split(',')
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList(growable: false);

    setState(() => _saving = true);
    try {
      final sync = await repository.saveMyProfile(displayName: name, roles: roles);
      ref.invalidate(myProfileProvider);
      ref.invalidate(offlineQueueStatusProvider);
      if (mounted) _message(sync.hasPermanentFailure
          ? 'Профиль сохранён на устройстве, но сервер отклонил синхронизацию.'
          : sync.hasPending
              ? 'Профиль сохранён на устройстве. Ожидает синхронизации.'
              : 'Профиль сохранён.');
    } catch (error) {
      if (mounted) _message('Не удалось сохранить профиль: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _retryOfflineSync() async {
    setState(() => _syncing = true);
    try {
      final engine = await ref.read(offlineSyncEngineProvider.future);
      final report = await engine.syncPending(force: true, retryFailed: true);
      ref.invalidate(offlineQueueStatusProvider);
      if (mounted) {
        _message(report.failedCount > 0
            ? 'Синхронизировано: ${report.syncedCount}. Ошибок: ${report.failedCount}. Проверьте доступы и повторите.'
            : report.hasPending
                ? 'Синхронизировано: ${report.syncedCount}. Осталось в очереди: ${report.pendingCount}.'
                : 'Все изменения синхронизированы.');
      }
    } catch (error) {
      if (mounted) _message('Не удалось запустить синхронизацию: $error');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _resolveOfflineConflict(
    Map<String, Object?> mutation, {
    required bool keepLocal,
  }) async {
    try {
      final store = await ref.read(offlineStoreProvider.future);
      final operationId = mutation['operationId']?.toString() ?? '';
      if (operationId.isEmpty) return;
      if (keepLocal) {
        await store.resolveConflictKeepLocal(operationId: operationId);
        final engine = await ref.read(offlineSyncEngineProvider.future);
        await engine.syncPending(force: true);
      } else {
        await store.resolveConflictUseServer(operationId: operationId);
      }
      ref.invalidate(offlineQueueStatusProvider);
      ref.invalidate(offlineConflictsProvider);
      if (mounted) {
        _message(keepLocal
            ? 'Локальная версия сохранена и отправлена на сервер.'
            : 'Принята серверная версия. Локальные изменения этой записи удалены.');
      }
    } catch (error) {
      if (mounted) _message('Не удалось разрешить конфликт: $error');
    }
  }

  Future<void> _openWebApp() async {
    try {
      final opened = await launchUrl(
        _webAppUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _message('Не удалось открыть веб-версию BandPlan.');
      }
    } catch (error) {
      if (mounted) _message('Не удалось открыть веб-версию: $error');
    }
  }

  Future<void> _downloadAndroidApk() async {
    try {
      final opened = await launchUrl(
        _androidApkUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) {
        _message('Не удалось открыть ссылку на APK. Попробуйте ещё раз.');
      }
    } catch (error) {
      if (mounted) _message('Не удалось открыть загрузку: $error');
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    final offlineQueue = ref.watch(offlineQueueStatusProvider);
    final offlineConflicts = ref.watch(offlineConflictsProvider);

    return DefaultTabController(
      length: 5,
      initialIndex: widget.initialSection,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Профиль'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.person_outline_rounded), text: 'Профиль'),
              Tab(icon: Icon(Icons.groups_outlined), text: 'Группы'),
              Tab(icon: Icon(Icons.palette_outlined), text: 'Оформление'),
              Tab(icon: Icon(Icons.tune_rounded), text: 'Элементы'),
              Tab(icon: Icon(Icons.download_rounded), text: 'Приложение'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Выйти из аккаунта',
              onPressed: () => ref.read(authRepositoryProvider)?.signOut(),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            SafeArea(
              child: profile.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 40),
                        const SizedBox(height: 12),
                        Text(error.toString(), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => ref.invalidate(myProfileProvider),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (value) {
                  // WHY: a long-lived profile page must not show the previous account's
                  // controllers after the authenticated user changes.
                  if (_loadedUserId != value.userId) {
                    _nameController.text = value.displayName;
                    _rolesController.text = value.roles.join(', ');
                    _loadedUserId = value.userId;
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 38,
                          child: Text(
                            value.displayName.isEmpty
                                ? '?'
                                : value.displayName.characters.first.toUpperCase(),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Отображаемое имя',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _rolesController,
                        decoration: const InputDecoration(
                          labelText: 'Музыкальные роли',
                          hintText: 'Вокал, гитара, клавиши',
                          helperText: 'Укажите роли через запятую',
                          prefixIcon: Icon(Icons.music_note_rounded),
                        ),
                      ),
                      const SizedBox(height: 24),
                      offlineQueue.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, stack) => const SizedBox.shrink(),
                        data: (status) => status.pendingCount == 0
                            ? const SizedBox.shrink()
                            : Container(
                                margin: const EdgeInsets.only(bottom: 18),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.sync_rounded),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(
                                        status.failedCount > 0
                                            ? 'Есть изменения с ошибками синхронизации'
                                            : 'Изменения ожидают синхронизации',
                                        style: Theme.of(context).textTheme.titleSmall,
                                      )),
                                    ]),
                                    const SizedBox(height: 6),
                                    Text('В очереди: ${status.pendingCount} · Ошибок: ${status.failedCount} · Конфликтов: ${status.conflictCount}'),
                                    offlineConflicts.when(
                                      loading: () => const SizedBox.shrink(),
                                      error: (error, stack) => const SizedBox.shrink(),
                                      data: (conflicts) => conflicts.isEmpty
                                          ? const SizedBox.shrink()
                                          : Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const SizedBox(height: 14),
                                                Text(
                                                  'Нужно выбрать версию записи:',
                                                  style: Theme.of(context).textTheme.titleSmall,
                                                ),
                                                const SizedBox(height: 8),
                                                ...conflicts.map((mutation) {
                                                  final recordId = mutation['recordId']?.toString() ?? 'Запись';
                                                  final remoteExists = mutation['remoteVersionExists'] == true;
                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 14),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          recordId,
                                                          style: Theme.of(context).textTheme.titleSmall,
                                                        ),
                                                        const SizedBox(height: 8),
                                                        _ConflictVersionCard(
                                                          label: 'Локальная версия',
                                                          payload: mutation['payload'],
                                                          isDeleted: mutation['operation'] == 'delete',
                                                        ),
                                                        const SizedBox(height: 8),
                                                        _ConflictVersionCard(
                                                          label: 'Версия на сервере',
                                                          payload: mutation['remotePayload'],
                                                          missing: !remoteExists,
                                                        ),
                                                        const SizedBox(height: 8),
                                                        Wrap(
                                                          spacing: 8,
                                                          runSpacing: 8,
                                                          children: [
                                                            OutlinedButton(
                                                              onPressed: _syncing
                                                                  ? null
                                                                  : () => _resolveOfflineConflict(mutation, keepLocal: true),
                                                              child: const Text('Оставить мою'),
                                                            ),
                                                            TextButton(
                                                              onPressed: _syncing
                                                                  ? null
                                                                  : () => _resolveOfflineConflict(mutation, keepLocal: false),
                                                              child: const Text('Принять серверную'),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                    ),
                                    const SizedBox(height: 10),
                                    OutlinedButton.icon(
                                      onPressed: _syncing ? null : _retryOfflineSync,
                                      icon: _syncing
                                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.sync_rounded),
                                      label: const Text('Повторить синхронизацию'),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Сохранить профиль'),
                      ),
                    ],
                  );
                },
              ),
            ),
            const GroupWorkspacePage(embedded: true),
            const AppearanceSettingsTab(),
            const ElementCustomizationTab(),
            _AppInstallTab(
              onOpenWeb: _openWebApp,
              onDownloadApk: _downloadAndroidApk,
            ),
          ],
        ),
      ),
    );
  }
}


class _AppInstallTab extends StatelessWidget {
  const _AppInstallTab({
    required this.onOpenWeb,
    required this.onDownloadApk,
  });

  final VoidCallback onOpenWeb;
  final VoidCallback onDownloadApk;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          _PwaInstallCard(onOpenWeb: onOpenWeb),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.android_rounded,
                    size: 34,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'BandPlan для Android',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Скачайте APK-файл и установите BandPlan прямо на телефон. '
                  'Это мобильная сборка Flutter, а не веб-страница в браузере.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onDownloadApk,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Скачать APK'),
                  ),
                ),
                const SizedBox(height: 22),
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 18),
                Text(
                  'Как установить APK',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                const _InstallStep(
                  number: '1',
                  title: 'Скачайте файл',
                  description:
                      'Нажмите «Скачать APK» и дождитесь завершения загрузки.',
                ),
                const _InstallStep(
                  number: '2',
                  title: 'Разрешите установку',
                  description:
                      'Если Android спросит разрешение, разрешите установку '
                      'приложений из браузера или файлового менеджера.',
                ),
                const _InstallStep(
                  number: '3',
                  title: 'Установите BandPlan',
                  description:
                      'Откройте загруженный APK и подтвердите установку.',
                ),
                const SizedBox(height: 2),
                Text(
                  'Загружайте APK только из официального репозитория BandPlan. '
                  'При обновлении установите новую версию поверх предыдущей.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PwaInstallCard extends StatelessWidget {
  const _PwaInstallCard({required this.onOpenWeb});

  final VoidCallback onOpenWeb;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.install_mobile_rounded,
              size: 32,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Установить BandPlan как PWA',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Веб-версию можно добавить на главный экран. Она будет '
            'открываться отдельным окном, как обычное приложение. APK '
            'для этого не нужен.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onOpenWeb,
              icon: const Icon(Icons.open_in_browser_rounded),
              label: const Text('Открыть веб-версию'),
            ),
          ),
          const SizedBox(height: 18),
          Text('Как установить на устройство',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          const _InstallStep(
            number: '1',
            title: 'Android · Chrome',
            description:
                'Откройте BandPlan в Chrome, нажмите ⋮ и выберите '
                '«Установить приложение» или «Добавить на главный экран».',
          ),
          const _InstallStep(
            number: '2',
            title: 'iPhone · Safari',
            description:
                'Откройте BandPlan в Safari, нажмите «Поделиться» и выберите '
                '«На экран Домой».',
          ),
          const _InstallStep(
            number: '3',
            title: 'Компьютер · Chrome или Edge',
            description:
                'Откройте сайт и нажмите значок установки в адресной строке '
                'или выберите пункт установки в меню браузера.',
          ),
          Text(
            'Для установки нужен интернет и открытие сайта по HTTPS. '
            'Доступность пункта установки зависит от браузера.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}

class _InstallStep extends StatelessWidget {
  const _InstallStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: colors.secondaryContainer,
            foregroundColor: colors.onSecondaryContainer,
            child: Text(number),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// WHY: Show the actual competing values so users can choose a version based
/// on its contents instead of resolving a conflict from a generic warning.
class _ConflictVersionCard extends StatelessWidget {
  const _ConflictVersionCard({
    required this.label,
    this.payload,
    this.isDeleted = false,
    this.missing = false,
  });

  final String label;
  final Object? payload;
  final bool isDeleted;
  final bool missing;

  static const _labels = <String, String>{
    'title': 'Название',
    'name': 'Название',
    'display_name': 'Имя',
    'artist': 'Исполнитель',
    'key': 'Тональность',
    'tempo': 'Темп',
    'bpm': 'Темп',
    'date': 'Дата',
    'start_at': 'Начало',
    'location': 'Место',
    'roles': 'Роли',
    'description': 'Описание',
  };

  static String _valueText(Object value) {
    if (value is List) return value.take(4).join(', ');
    if (value is Map) return 'Составные данные';
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final values = payload is Map
        ? Map<String, Object?>.from(payload as Map)
        : <String, Object?>{};
    final entries = <MapEntry<String, Object?>>[];

    for (final key in _labels.keys) {
      final value = values[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        entries.add(MapEntry(key, value));
      }
    }
    if (entries.isEmpty) {
      for (final entry in values.entries) {
        final value = entry.value;
        if (value == null || value is Map || value is List) continue;
        entries.add(entry);
        if (entries.length == 3) break;
      }
    }

    final message = missing
        ? 'Эта запись удалена на сервере.'
        : isDeleted
            ? 'Эта запись будет удалена после синхронизации.'
            : entries.isEmpty
                ? 'Нет данных для предварительного просмотра.'
                : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withOpacity(0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 5),
          if (message != null)
            Text(message, style: Theme.of(context).textTheme.bodySmall)
          else
            ...entries.take(4).map((entry) {
              final fieldLabel = _labels[entry.key] ?? entry.key;
              return Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '$fieldLabel: ${_valueText(entry.value!)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }),
        ],
      ),
    );
  }
}

