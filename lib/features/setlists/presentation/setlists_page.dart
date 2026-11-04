import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../groups/application/group_providers.dart';
import '../../songs/application/song_providers.dart';
import '../../songs/domain/song.dart';
import '../../events/application/event_providers.dart';
import '../../events/domain/group_event.dart';
import '../application/setlist_providers.dart';
import '../domain/setlist.dart';
import 'setlist_run_page.dart';

class SetlistsPage extends ConsumerWidget {
  const SetlistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setlists = ref.watch(groupSetlistsProvider);
    final songs = ref.watch(groupSongsProvider);
    final events = ref.watch(groupEventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Сет-листы')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: songs.hasValue ? () => _editSetlist(context, ref, songs.value!, events.asData?.value ?? const <GroupEvent>[]) : null,
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
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(Icons.queue_music_rounded, size: 38,
                              color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                        const SizedBox(height: 18),
                        Text('Соберите программу выступления',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                )),
                        const SizedBox(height: 8),
                        Text(
                          'Добавьте песни из репертуара группы, задайте порядок и запускайте сет-лист в режиме исполнения.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: songs.hasValue
                              ? () => _editSetlist(context, ref, songs.value!,
                                  events.asData?.value ?? const <GroupEvent>[])
                              : null,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Создать сет-лист'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            final songMap = {for (final song in songs.asData?.value ?? const <Song>[]) song.id: song};
            final eventMap = {for (final event in events.asData?.value ?? const <GroupEvent>[]) event.id: event};
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
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
                      if (_linkedEventLabel(setlist, eventMap).isNotEmpty)
                        'Событие: ${_linkedEventLabel(setlist, eventMap)}',
                      if (setlist.note.isNotEmpty) setlist.note,
                    ].join(' · '), maxLines: 3, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Начать исполнение',
                          // WHY: execution is a separate read-only flow; editing remains on card tap.
                          onPressed: songs.hasValue && setlist.items.isNotEmpty
                              ? () => _startSetlist(context, setlist, songs.value!)
                              : null,
                          icon: const Icon(Icons.play_arrow_rounded),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Действия с сет-листом',
                          onSelected: (action) {
                            if (action == 'delete') {
                              _confirmDeleteSetlist(context, ref, setlist);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.delete_outline_rounded),
                                title: Text('Удалить сет-лист'),
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                    onTap: () => _editSetlist(context, ref, songs.asData?.value ?? const <Song>[], events.asData?.value ?? const <GroupEvent>[], setlist),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDeleteSetlist(
    BuildContext context,
    WidgetRef ref,
    Setlist setlist,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить сет-лист?'),
        content: Text('«${setlist.name}» будет удалён. Песни из репертуара останутся без изменений.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final group = await ref.read(activeGroupProvider.future);
      final repository = await ref.read(setlistRepositoryProvider.future);
      if (group == null) {
        throw StateError('Не удалось определить активную группу.');
      }
      final sync = await repository.deleteGroupSetlist(group.id, setlist.id);
      ref.invalidate(groupSetlistsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(sync.hasPermanentFailure ? 'Сет-лист удалён локально, но сервер отклонил синхронизацию.' : sync.hasPending ? 'Удаление сет-листа сохранено на устройстве. Ожидает синхронизации.' : 'Сет-лист «${setlist.name}» удалён.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить сет-лист: $error')),
        );
      }
    }
  }

  Future<void> _startSetlist(BuildContext context, Setlist setlist, List<Song> songs) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SetlistRunPage(setlist: setlist, songs: songs),
      ),
    );
  }

  Future<void> _editSetlist(
    BuildContext context,
    WidgetRef ref,
    List<Song> songs,
    List<GroupEvent> events, [
    Setlist? existing,
  ]) async {
    final group = await ref.read(activeGroupProvider.future);
    if (group == null || !context.mounted) return;
    final repository = await ref.read(setlistRepositoryProvider.future);

    final nameController = TextEditingController(text: existing?.name ?? '');
    final noteController = TextEditingController(text: existing?.note ?? '');
    final items = List<SetlistItem>.of(existing?.items ?? const []);
    GroupEvent? inferredEvent;
    for (final event in events) {
      if (event.setlistId == existing?.id) {
        inferredEvent = event;
        break;
      }
    }
    var linkedEventId = existing?.eventId.isNotEmpty == true
        ? existing!.eventId
        : (inferredEvent?.id ?? '');
    final linkedEventExists = events.any((event) => event.id == linkedEventId);
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
                    DropdownButtonFormField<String>(
                      value: linkedEventId.isEmpty ? null : linkedEventId,
                      decoration: const InputDecoration(labelText: 'Связанное событие', border: OutlineInputBorder()),
                      items: [
                        const DropdownMenuItem<String>(value: '', child: Text('Без события')),
                        if (linkedEventId.isNotEmpty && !linkedEventExists)
                          DropdownMenuItem<String>(
                            value: linkedEventId,
                            enabled: false,
                            child: const Text('Связанное событие недоступно'),
                          ),
                        ...events.map((event) => DropdownMenuItem<String>(
                          value: event.id,
                          child: Text('${event.title} · ${event.date}', overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: (value) => setSheetState(() => linkedEventId = value ?? ''),
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
                                    subtitle: Text(song == null
                                        ? 'Ссылка сохранена, но песни нет в репертуаре'
                                        : [
                                            song.artist,
                                            song.transposedBy(item.shift).key,
                                            if (item.shift != 0) '${item.shift > 0 ? '+' : ''}${item.shift} пт.',
                                            if (item.note.isNotEmpty) item.note,
                                          ].where((value) => value.isNotEmpty).join(' · ')),
                                    // WHY: keep the drag handle and per-song actions in one compact row on mobile.
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.drag_handle_rounded),
                                        PopupMenuButton<String>(
                                          tooltip: 'Настройки песни в сет-листе',
                                          onSelected: (action) async {
                                            switch (action) {
                                              case 'down':
                                                setSheetState(() {
                                                  items[index] = item.withEdits(shift: item.shift - 1);
                                                });
                                                break;
                                              case 'up':
                                                setSheetState(() {
                                                  items[index] = item.withEdits(shift: item.shift + 1);
                                                });
                                                break;
                                              case 'note':
                                                final updatedNote = await _editItemNote(context, item.note);
                                                if (updatedNote != null) {
                                                  setSheetState(() {
                                                    items[index] = item.withEdits(note: updatedNote);
                                                  });
                                                }
                                                break;
                                              case 'remove':
                                                setSheetState(() => items.removeAt(index));
                                                break;
                                            }
                                          },
                                          itemBuilder: (context) => const [
                                            PopupMenuItem(value: 'down', child: Text('Понизить на полутон')),
                                            PopupMenuItem(value: 'up', child: Text('Повысить на полутон')),
                                            PopupMenuItem(value: 'note', child: Text('Заметка к песне')),
                                            PopupMenuItem(value: 'remove', child: Text('Убрать из программы')),
                                          ],
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
                            eventId: linkedEventId,
                          );
                          final sync = await repository.saveGroupSetlist(group.id, edited);
                          ref.invalidate(groupSetlistsProvider);
                          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                          if (context.mounted && sync.hasPending) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(sync.hasPermanentFailure
                                  ? 'Сет-лист сохранён локально, но сервер отклонил синхронизацию.'
                                  : 'Сет-лист сохранён на устройстве. Ожидает синхронизации.')),
                            );
                          }
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

  Future<String?> _editItemNote(BuildContext context, String initialNote) async {
    final controller = TextEditingController(text: initialNote);
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Заметка к песне'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            maxLength: 300,
            decoration: const InputDecoration(
              hintText: 'Например: начать после вступления',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
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

  String _linkedEventLabel(Setlist setlist, Map<String, GroupEvent> eventMap) {
    GroupEvent? event = eventMap[setlist.eventId];
    if (event == null) {
      for (final candidate in eventMap.values) {
        if (candidate.setlistId == setlist.id) {
          event = candidate;
          break;
        }
      }
    }
    if (event == null) return setlist.eventId.isNotEmpty ? 'Событие недоступно' : '';
    return [event.title, event.date].where((value) => value.isNotEmpty).join(' · ');
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
