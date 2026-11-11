import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../application/group_providers.dart';
import '../data/group_repository.dart';
import '../../profile/application/profile_providers.dart';
import '../domain/group_summary.dart';

class GroupWorkspacePage extends ConsumerWidget {
  const GroupWorkspacePage({super.key, this.embedded = false});

  final bool embedded;

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
      appBar: embedded ? null : AppBar(title: const Text('Группы')),
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
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.groups_rounded, size: 34,
                          color: Theme.of(context).colorScheme.onPrimaryContainer),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Музыкальные группы',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    )),
                            const SizedBox(height: 5),
                            Text(
                              'У каждой группы свой репертуар, события и сет-листы.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: repository == null
                                ? null
                                : () => _showGroupDialog(context, ref, repository, create: true),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Создать группу'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: repository == null
                                ? null
                                : () => _showGroupDialog(context, ref, repository, create: false),
                            icon: const Icon(Icons.group_add_outlined),
                            label: const Text('Вступить по коду'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Мои группы',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('${items.length}',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              )),
                    ),
                  ],
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
                // WHY: create/join RPCs may update account display name and roles.
                ref.invalidate(myProfileProvider);
                // WHY: create/join may change the server-selected active group.
                ref.invalidate(activeGroupProvider);
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
                if (action == 'members') {
                  await _showGroupMembersDialog(context, repo, group);
                } else if (action == 'activate') {
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
                  final formKey = GlobalKey<FormState>();
                  final renamed = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Переименовать группу'),
                      content: Form(
                        key: formKey,
                        child: TextFormField(
                          controller: controller,
                          autofocus: true,
                          maxLength: 50,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Название группы'),
                          validator: (value) {
                            final length = (value ?? '').trim().length;
                            if (length < 3 || length > 50) {
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
                          onPressed: () {
                            if (formKey.currentState?.validate() != true) return;
                            Navigator.pop(dialogContext, controller.text.trim());
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
                    // WHY: invite generation switches the active group on the server.
                    onActivated();
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
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'members', child: Text('Участники группы')),
                // WHY: don't offer an action that cannot change the current active group.
                if (!isActive)
                  const PopupMenuItem(value: 'activate', child: Text('Сделать активной')),
                const PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                const PopupMenuItem(value: 'invite', child: Text('Получить код приглашения')),
                const PopupMenuItem(value: 'leave', child: Text('Покинуть группу')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showGroupMembersDialog(
  BuildContext context,
  GroupRepository repository,
  GroupSummary group,
) async {
  // WHY: load the roster only after the user explicitly opens this menu item.
  final membersFuture = repository.getGroupMembers(
    groupId: group.id,
    ownerId: group.ownerId,
  );
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Участники — ${group.name}'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: membersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Не удалось загрузить участников.\\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }
            final members = snapshot.data ?? const <Map<String, dynamic>>[];
            if (members.isEmpty) {
              return const Center(child: Text('В группе пока нет участников.'));
            }
            return ListView.separated(
              itemCount: members.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final member = members[index];
                final name = (member['display_name'] ?? '').toString().trim();
                final roles = member['roles'] is List
                    ? (member['roles'] as List).map((role) => role.toString()).join(' · ')
                    : '';
                final isOwner = member['is_owner'] == true;
                final joinedAt = DateTime.tryParse(
                  (member['joined_at'] ?? '').toString(),
                );
                final joinedLabel = joinedAt == null
                    ? ''
                    : 'В группе с ${MaterialLocalizations.of(context).formatMediumDate(joinedAt.toLocal())}';
                final subtitle = [
                  if (isOwner) 'Владелец',
                  if (roles.isNotEmpty) roles,
                  if (joinedLabel.isNotEmpty) joinedLabel,
                ].join(' · ');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(
                      name.isEmpty ? 'У' : name.characters.first.toUpperCase(),
                    ),
                  ),
                  title: Text(name.isEmpty ? 'Участник' : name),
                  subtitle: subtitle.isEmpty ? null : Text(subtitle),
                  trailing: isOwner
                      ? Icon(Icons.workspace_premium_rounded,
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
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
