import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_providers.dart';
import '../application/group_providers.dart';
import '../data/group_repository.dart';
import '../../profile/application/profile_providers.dart';
import '../domain/group_summary.dart';

class GroupWorkspacePage extends ConsumerWidget {
  const GroupWorkspacePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(myGroupsProvider);
    final activeGroup = ref.watch(activeGroupProvider);
    final activeGroupId = activeGroup.when(
      data: (group) => group?.id,
      loading: () => null,
      error: (_, __) => null,
    );
    final repository = ref.watch(groupRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Рабочие группы'),
        actions: [
          IconButton(
            tooltip: 'Каталог песен',
            onPressed: () => context.push('/songs'),
            icon: const Icon(Icons.library_music_outlined),
          ),
          IconButton(
            tooltip: 'Мой профиль',
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline_rounded),
          ),
          IconButton(
            tooltip: 'Выйти из аккаунта',
            onPressed: () => ref.read(authRepositoryProvider)?.signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: groups.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _LoadError(
            message: error.toString(),
            onRetry: () => ref.invalidate(myGroupsProvider),
          ),
          data: (value) {
            final items = value;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(
                  'Пространство вашей группы',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Создайте новую группу или присоединитесь к существующей по коду приглашения.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: repository == null
                      ? null
                      : () => _showGroupDialog(context, ref, repository, create: true),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Создать группу'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: repository == null
                      ? null
                      : () => _showGroupDialog(context, ref, repository, create: false),
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Вступить по коду'),
                ),
                const SizedBox(height: 28),
                Text(
                  'Мои группы',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const _EmptyGroups()
                else
                  for (final group in items)
                    _GroupTile(
                      group: group,
                      repository: repository,
                      isActive: group.id == activeGroupId,
                      onChanged: () {
                        ref.invalidate(myGroupsProvider);
                        ref.invalidate(activeGroupProvider);
                      },
                      onActivated: () {
                        ref.invalidate(activeGroupProvider);
                        ref.invalidate(myGroupsProvider);
                      },
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showGroupDialog(
    BuildContext context,
    WidgetRef ref,
    GroupRepository repository, {
    required bool create,
  }) async {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final userEmail = ref.read(authRepositoryProvider)?.currentUser?.email ?? '';
    final profile = ref.read(myProfileProvider).asData?.value;
    final displayName = profile?.displayName.trim().isNotEmpty == true
        ? profile!.displayName.trim()
        : userEmail.split('@').first;
    final roles = profile?.roles ?? const <String>[];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(create ? 'Новая группа' : 'Вступить в группу'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: create ? nameController : codeController,
            autofocus: true,
            textCapitalization:
                create ? TextCapitalization.words : TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: create ? 'Название группы' : 'Код приглашения',
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return 'Заполните поле';
              if (create && (value!.trim().length < 3 || value.trim().length > 50)) {
                return 'Название должно содержать от 3 до 50 символов';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                if (create) {
                  await repository.createGroup(
                    name: nameController.text.trim(),
                    displayName: displayName,
                    roles: roles,
                  );
                } else {
                  await repository.joinGroup(
                    inviteCode: codeController.text.trim(),
                    displayName: displayName,
                    roles: roles,
                  );
                }
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ref.invalidate(myGroupsProvider);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(create ? 'Группа создана.' : 'Вы вступили в группу.'),
                  ),
                );
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(error.toString())),
                );
              }
            },
            child: Text(create ? 'Создать' : 'Вступить'),
          ),
        ],
      ),
    );
    nameController.dispose();
    codeController.dispose();
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.repository,
    required this.isActive,
    required this.onChanged,
    required this.onActivated,
  });

  final GroupSummary group;
  final GroupRepository? repository;
  final bool isActive;
  final VoidCallback onChanged;
  final VoidCallback onActivated;

  @override
  Widget build(BuildContext context) {
    final id = group.id;
    final name = group.name;
    final repo = repository;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.groups_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                  if (isActive) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Активная группа',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (repo != null)
              PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'activate') {
                  try {
                    await repo.setActiveGroup(id);
                    onActivated();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Активная группа: $name')),
                      );
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  }
                } else if (action == 'rename') {
                  final controller = TextEditingController(text: name);
                  final renamed = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Переименовать группу'),
                      content: TextField(
                        controller: controller,
                        autofocus: true,
                        maxLength: 50,
                        decoration: const InputDecoration(labelText: 'Название группы'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Отмена'),
                        ),
                        FilledButton(
                          onPressed: () {
                            final value = controller.text.trim();
                            if (value.length >= 3 && value.length <= 50) {
                              Navigator.pop(dialogContext, value);
                            }
                          },
                          child: const Text('Сохранить'),
                        ),
                      ],
                    ),
                  );
                  controller.dispose();
                  if (renamed != null) {
                    try {
                      await repo.renameGroup(groupId: id, name: renamed);
                      onChanged();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Название группы обновлено.')),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  }
                } else if (action == 'invite') {
                  try {
                    await repo.setActiveGroup(id);
                    final result = await repo.getOrCreateInviteCode();
                    if (!context.mounted) return;
                    final code = result is Map
                        ? (result['invite_code'] ?? result['code'])?.toString()
                        : result?.toString();
                    if (code == null || code.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Сервер не вернул код приглашения.')),
                      );
                      return;
                    }
                    await Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Код $code скопирован.')),
                    );
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  }
                } else if (action == 'leave') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Покинуть группу?'),
                      content: Text('Вы действительно хотите покинуть «$name»?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Отмена'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Покинуть'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    try {
                      await repo.leaveGroup(id);
                      onChanged();
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  }
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'activate', child: Text('Сделать активной')),
                PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                PopupMenuItem(value: 'invite', child: Text('Получить код приглашения')),
                PopupMenuItem(value: 'leave', child: Text('Покинуть группу')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGroups extends StatelessWidget {
  const _EmptyGroups();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(child: Text('Пока нет групп. Создайте группу или вступите по коду.')),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
          ],
        ),
      ),
    );
  }
}
