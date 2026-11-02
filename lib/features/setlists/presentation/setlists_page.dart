import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../groups/application/group_providers.dart';
import '../../songs/application/song_providers.dart';
import '../../songs/domain/song.dart';
import '../application/setlist_providers.dart';
import '../domain/setlist.dart';

class SetlistsPage extends ConsumerWidget {
  const SetlistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlists = ref.watch(groupSetlistsProvider);
    final songs = ref.watch(groupSongsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Сет-листы')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: songs.hasValue ? () => _editSetlist(context, ref, songs.value!) : null,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Новый сет-лист'),
      ),
      body: SafeArea(
        child: setlists.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _LoadError(
            message: error.toString(),
            onRetry: () => ref.invalidate(groupSetlistsProvider),
          ),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.queue_music_rounded, size: 46),
                      SizedBox(height: 12),
                      Text('Пока нет сет-листов', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      SizedBox(height: 6),
                      Text('Создайте программу выступления и добавьте песни из репертуара группы.', textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }
            final songMap = {for (final song in songs.asData?.value ?? const <Song>[]) song.id: song};
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final setlist = items[index];
                final duration = setlist.items.fold<int>(0, (total, item) =>
                    total + (songMap[item.songId]?.durationSeconds ?? 0).toInt());
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: const Icon(Icons.queue_music_rounded),
                    ),
                    title: Text(setlist.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text([
                      '${setlist.items.length} песен',
                      if (duration > 0) _durationLabel(duration),
                      if (setlist.note.isNotEmpty) setlist.note,
                    ].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _editSetlist(context, ref, songs.asData?.value ?? const <Song>[], setlist),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _editSetlist(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs, [
    Setlist? existing,
  ]) async {
    final group = await ref.read(activeGroupProvider.future);
    if (group == null || !context.mounted) return;
    final repository = ref.read(setlistRepositoryProvider);
    if (repository == null) return;

    final nameController = TextEditingController(text: existing?.name ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');
    final items = List<SetlistItem>.of(existing?.items ?? const []);
    var saving = false;
    final formKey = GlobalKey<FormState>();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SizedBox(
            height: MediaQuery.of(context).size.height * .88,
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 4, 18, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(existing == null ? 'Новый сет-лист' : 'Редактировать сет-лист',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameController,
                      maxLength: 90,
                      decoration: const InputDecoration(labelText: 'Название программы', border: OutlineInputBorder()),
                      validator: (value) => (value?.trim().isEmpty ?? true) ? 'Введите название' : null,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Заметка (необязательно)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: Text('Порядок песен · ${items.length}', style: Theme.of(context).textTheme.titleMedium)),
                        TextButton.icon(
                          onPressed: () async {
                            final selected = await _chooseSong(context, songs, items);
                            if (selected != null) setSheetState(() => items.add(SetlistItem.create(selected.id)));
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Добавить песню'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(child: Text('Добавьте песни из репертуара группы.'))
                          : ReorderableListView.builder(
                              itemCount: items.length,
                              onReorder: (oldIndex, newIndex) => setSheetState(() {
                                if (newIndex > oldIndex) newIndex--;
                                final item = items.removeAt(oldIndex);
                                items.insert(newIndex, item);
                              }),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                Song? song;
                                for (final candidate in songs) {
                                  if (candidate.id == item.songId) {
                                    song = candidate;
                                    break;
                                  }
                                }
                                return Card(
                                  key: ValueKey(item.id.isEmpty ? '${item.songId}-$index' : item.id),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      radius: 15,
                                      child: Text('${index + 1}', style: const TextStyle(fontSize: 12)),
                                    ),
                                    title: Text(song?.title ?? 'Песня не найдена'),
                                    subtitle: Text(song == null ? 'Ссылка сохранена, но песни нет в репертуаре' :
                                      [song.artist, song.key].where((value) => value.isNotEmpty).join(' · ')),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.drag_handle_rounded),
                                        IconButton(
                                          tooltip: 'Убрать из программы',
                                          onPressed: () => setSheetState(() => items.removeAt(index)),
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: saving ? null : () async {
                        if (!(formKey.currentState?.validate() ?? false)) return;
                        setSheetState(() => saving = true);
                        try {
                          final base = existing ?? Setlist.fromJson({
                            'id': DateTime.now().microsecondsSinceEpoch.toString(),
                            'name': nameController.text.trim(),
                            'items': <Map<String, dynamic>>[],
                          });
                          final edited = base.withEdits(
                            name: nameController.text.trim(),
                            note: noteController.text.trim(),
                            items: items,
                          );
                          await repository.saveGroupSetlist(group.id, edited);
                          ref.invalidate(groupSetlistsProvider);
                          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        } catch (error) {
                          setSheetState(() => saving = false);
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text('Не удалось сохранить сет-лист: $error')),
                            );
                          }
                        }
                      },
                      icon: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_rounded),
                      label: Text(saving ? 'Сохранение…' : 'Сохранить сет-лист'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      nameController.dispose();
      noteController.dispose();
    }
  }

  Future<Song?> _chooseSong(BuildContext context, List<Song> songs, List<SetlistItem> current) {
    final alreadyAdded = current.map((item) => item.songId).toSet();
    final available = songs.where((song) => !alreadyAdded.contains(song.id)).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return showDialog<Song>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Добавить песню'),
        content: SizedBox(
          width: 420,
          child: available.isEmpty
              ? const Text('Все песни из репертуара уже добавлены.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: available.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final song = available[index];
                    return ListTile(
                      title: Text(song.title),
                      subtitle: Text([song.artist, song.key].where((value) => value.isNotEmpty).join(' · ')),
                      onTap: () => Navigator.pop(dialogContext, song),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена'))],
      ),
    );
  }

  String _durationLabel(int seconds) => '${seconds ~/ 60} мин';
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 40),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
      ]),
    ),
  );
}
