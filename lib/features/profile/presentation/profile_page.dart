import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/profile_providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  final _rolesController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

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

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Мой профиль')),
      body: SafeArea(
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
            if (!_initialized) {
              _nameController.text = value.displayName;
              _rolesController.text = value.roles.join(', ');
              _initialized = true;
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
    );
  }
}
