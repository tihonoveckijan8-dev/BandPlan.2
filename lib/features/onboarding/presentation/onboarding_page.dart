import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../groups/application/group_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../../groups/application/group_providers.dart' show myGroupsProvider, activeGroupProvider;

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _nameController = TextEditingController();
  final _groupController = TextEditingController();
  final _rolesController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    _nameController.text = email.split('@').first;
    _groupController.text = 'Моя группа';
    _rolesController.text = 'Вокал';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();
    _rolesController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    final groupName = _groupController.text.trim();
    final roles = _rolesController.text
        .split(',')
        .map((role) => role.trim())
        .where((role) => role.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (name.isEmpty || groupName.length < 3 || groupName.length > 50) {
      setState(() => _error = 'Укажите имя и название группы (от 3 до 50 символов).');
      return;
    }
    if (roles.isEmpty) {
      setState(() => _error = 'Укажите хотя бы одну музыкальную роль.');
      return;
    }

    final repository = ref.read(groupRepositoryProvider);
    if (repository == null) {
      setState(() => _error = 'Сервис пока недоступен. Попробуйте позже.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      // WHY: the existing create-group RPC atomically provisions the account,
      // membership, invite and initial group state; do not write tables directly.
      await repository.createGroup(
        name: groupName,
        displayName: name,
        roles: roles,
      );

      final client = Supabase.instance.client;
      final result = await client.auth.updateUser(
        UserAttributes(data: {
          'bandplan_onboarding_done': true,
          'bandplan_onboarding_required': false,
        }),
      );
      if (result.user == null) {
        throw StateError('Группа создана, но не удалось подтвердить профиль аккаунта.');
      }

      ref.invalidate(myProfileProvider);
      ref.invalidate(myGroupsProvider);
      ref.invalidate(activeGroupProvider);
      ref.invalidate(onboardingCompleteProvider);
    } catch (error) {
      if (mounted) setState(() => _error = 'Не удалось завершить настройку: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.music_note_rounded,
                      size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 20),
                  Text('Добро пожаловать в BandPlan',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Заполните профиль и создайте рабочее пространство вашей группы. '
                    'Это займёт всего минуту.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Как к вам обращаться',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _rolesController,
                    decoration: const InputDecoration(
                      labelText: 'Ваши музыкальные роли',
                      hintText: 'Вокал, гитара, клавиши',
                      helperText: 'Несколько ролей можно разделить запятыми',
                      prefixIcon: Icon(Icons.queue_music_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _groupController,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 50,
                    decoration: const InputDecoration(
                      labelText: 'Название вашей группы',
                      prefixIcon: Icon(Icons.groups_rounded),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _saving ? null : _finish,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Создать группу и продолжить'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
