import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/application/auth_providers.dart';
import '../../groups/presentation/group_workspace_page.dart';
import '../application/profile_providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  final _rolesController = TextEditingController();
  String? _loadedUserId;
  bool _saving = false;

  static final _androidApkUri = Uri.parse(
    'https://github.com/tihonoveckijan8-dev/BandPlan.2/releases/download/'
    'android-latest/BandPlan-android.apk',
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

    final repository = ref.read(profileRepositoryProvider);
    if (repository == null) return;

    final roles = _rolesController.text
        .split(',')
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList(growable: false);

    setState(() => _saving = true);
    try {
      await repository.saveMyProfile(displayName: name, roles: roles);
      ref.invalidate(myProfileProvider);
      if (mounted) _message('Профиль сохранён.');
    } catch (error) {
      if (mounted) _message('Не удалось сохранить профиль: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Профиль'),
          actions: [
            IconButton(
              tooltip: 'Выйти из аккаунта',
              onPressed: () => ref.read(authRepositoryProvider)?.signOut(),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.person_outline_rounded), text: 'Профиль'),
              Tab(icon: Icon(Icons.groups_outlined), text: 'Группы'),
              Tab(icon: Icon(Icons.download_rounded), text: 'Приложение'),
            ],
          ),
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
            _AndroidDownloadTab(onDownload: _downloadAndroidApk),
          ],
        ),
      ),
    );
  }
}

class _AndroidDownloadTab extends StatelessWidget {
  const _AndroidDownloadTab({required this.onDownload});

  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
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
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Скачать APK'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Как установить',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const _InstallStep(
            number: '1',
            title: 'Скачайте файл',
            description: 'Нажмите «Скачать APK» и дождитесь завершения загрузки.',
          ),
          const _InstallStep(
            number: '2',
            title: 'Разрешите установку',
            description:
                'Если Android спросит разрешение, разрешите установку приложений '
                'из браузера или файлового менеджера.',
          ),
          const _InstallStep(
            number: '3',
            title: 'Установите BandPlan',
            description: 'Откройте загруженный APK и подтвердите установку.',
          ),
          const SizedBox(height: 12),
          Text(
            'Загружайте APK только из официального репозитория BandPlan. '
            'При обновлении установите новую версию поверх предыдущей.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
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
