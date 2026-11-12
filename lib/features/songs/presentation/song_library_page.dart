import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/song_providers.dart';
import '../../groups/application/group_providers.dart';
import '../domain/song.dart';
import '../domain/song_document.dart';
import 'song_lyrics_view.dart';
import '../../stage/presentation/stage_mode_page.dart';

enum _SongLibrary { group, personal }

class SongLibraryPage extends ConsumerStatefulWidget {
  const SongLibraryPage({super.key});

  @override
  ConsumerState<SongLibraryPage> createState() => _SongLibraryPageState();
}

class _SongLibraryPageState extends ConsumerState<SongLibraryPage> {
  final _searchController = TextEditingController();
  _SongLibrary _library = _SongLibrary.group;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songs = _library == _SongLibrary.group
        ? ref.watch(groupSongsProvider)
        : ref.watch(personalSongsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Каталог песен')),
      floatingActionButton: _library == _SongLibrary.group
          ? FloatingActionButton.extended(
              onPressed: () => _editSong(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Новая песня'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _library == _SongLibrary.group ? 'Репертуар группы' : 'Моя библиотека',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _library == _SongLibrary.group
                              ? 'Песни, которые доступны всей группе'
                              : 'Личные песни и заготовки',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.library_music_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<_SongLibrary>(
                segments: const [
                  ButtonSegment(
                    value: _SongLibrary.group,
                    icon: Icon(Icons.groups_outlined),
                    label: Text('Репертуар группы'),
                  ),
                  ButtonSegment(
                    value: _SongLibrary.personal,
                    icon: Icon(Icons.person_outline_rounded),
                    label: Text('Моя библиотека'),
                  ),
                ],
                selected: {_library},
                onSelectionChanged: (value) =>
                    setState(() => _library = value.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value.trim()),
                decoration: InputDecoration(
                  hintText: 'Найти песню или исполнителя',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Очистить поиск',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: songs.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _LoadError(
                  message: error.toString(),
                  onRetry: () => _library == _SongLibrary.group
                      ? ref.invalidate(groupSongsProvider)
                      : ref.invalidate(personalSongsProvider),
                ),
                data: (value) {
                  final query = _query.toLowerCase();
                  final filtered = value
                      .where((song) =>
                          query.isEmpty || song.searchableText.contains(query))
                      .toList(growable: false)
                    ..sort((a, b) => a.title.compareTo(b.title));

                  if (filtered.isEmpty) {
                    return _EmptySongs(
                      hasQuery: query.isNotEmpty,
                      isPersonal: _library == _SongLibrary.personal,
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _SongTile(
                      song: filtered[index],
                      onTap: () => _showSong(context, filtered[index]),
                      onEdit: _library == _SongLibrary.group
                          ? () => _editSong(context, filtered[index])
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSong(BuildContext context, [Song? existing]) async {
    if (_library != _SongLibrary.group) return;

    final titleController = TextEditingController(text: existing?.title ?? '');
    final artistController = TextEditingController(text: existing?.artist ?? '');
    final bpmController = TextEditingController(
      text: existing?.bpm?.toString() ?? '',
    );
    final tagsController = TextEditingController(
      text: existing?.tags.join(', ') ?? '',
    );
    var lyricsControllers = SongDocument.splitIntoColumns(
      existing?.lyrics ?? '',
      columns: existing?.lyricsColumns ?? 1,
      columnBreaks: existing?.lyricsColumnBreaks ?? const [],
    ).map((text) => TextEditingController(text: text)).toList();
    var activeLyricsColumn = 0;
    var selectedKey = existing?.key.isNotEmpty == true ? existing!.key : 'Am';
    var selectedColumns = existing?.lyricsColumns ?? 1;
    var saving = false;
    final formKey = GlobalKey<FormState>();
    var syncPending = false;
    var syncFailed = false;

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        // WHY: Flutter's default desktop bottom-sheet width is capped; a wider
        // document canvas is required for two or three editable lyric columns.
        constraints: const BoxConstraints(maxWidth: 1480),
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      existing == null ? 'Новая песня' : 'Редактировать песню',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: titleController,
                      autofocus: existing == null,
                      maxLength: 90,
                      decoration: const InputDecoration(
                        labelText: 'Название *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? 'Введите название песни'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: artistController,
                      decoration: const InputDecoration(
                        labelText: 'Исполнитель',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedKey,
                      decoration: const InputDecoration(
                        labelText: 'Тональность',
                        border: OutlineInputBorder(),
                      ),
                      // WHY: legacy songs may use flat spellings (Bb, Eb, Ab, etc.).
                      // Keep those values selectable so opening an existing song never
                      // triggers DropdownButton's missing-value assertion.
                      items: [
                        ...const [
                          'C','Cm','C#','C#m','Db','Dbm','D','Dm','D#','D#m','Eb','Ebm',
                          'E','Em','F','Fm','F#','F#m','Gb','Gbm','G','Gm','G#','G#m',
                          'Ab','Abm','A','Am','A#','A#m','Bb','Bbm','B','Bm',
                        ],
                        if (![
                          'C','Cm','C#','C#m','Db','Dbm','D','Dm','D#','D#m','Eb','Ebm',
                          'E','Em','F','Fm','F#','F#m','Gb','Gbm','G','Gm','G#','G#m',
                          'Ab','Abm','A','Am','A#','A#m','Bb','Bbm','B','Bm',
                        ].contains(selectedKey))
                          selectedKey,
                      ].map((key) => DropdownMenuItem(
                        value: key,
                        child: Text(key),
                      )).toList(),
                      onChanged: (value) {
                        if (value != null) setSheetState(() => selectedKey = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: bpmController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Темп (BPM)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final bpm = int.tryParse(text);
                        if (bpm == null || bpm < 20 || bpm > 300) {
                          return 'Укажите темп от 20 до 300 BPM';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Теги через запятую',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final chord = await _promptChord(context);
                          if (chord == null) return;
                          final target = lyricsControllers[activeLyricsColumn];
                          final selection = target.selection;
                          final start = selection.isValid ? selection.start : target.text.length;
                          final end = selection.isValid ? selection.end : target.text.length;
                          final updated = SongDocument.insertChordToken(
                            source: target.text,
                            selectionStart: start,
                            selectionEnd: end,
                            chord: chord,
                          );
                          final cursor = (start < end ? start : end) + chord.length + 2;
                          target.value = TextEditingValue(
                            text: updated,
                            selection: TextSelection.collapsed(offset: cursor),
                          );
                          setSheetState(() {});
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Вставить аккорд'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Колонки текста',
                            style: Theme.of(context).textTheme.titleSmall),
                        ),
                        SegmentedButton<int>(
                          segments: const [
                            ButtonSegment(value: 1, label: Text('1')),
                            ButtonSegment(value: 2, label: Text('2')),
                            ButtonSegment(value: 3, label: Text('3')),
                          ],
                          selected: {selectedColumns},
                          onSelectionChanged: (value) {
                            final nextCount = value.first;
                            final merged = SongDocument.joinColumns(
                              lyricsControllers.map((controller) => controller.text).toList(),
                            );
                            final split = SongDocument.splitIntoColumns(
                              merged,
                              columns: nextCount,
                            );
                            for (final controller in lyricsControllers) {
                              controller.dispose();
                            }
                            setSheetState(() {
                              selectedColumns = nextCount;
                              activeLyricsColumn = 0;
                              lyricsControllers = split
                                  .map((text) => TextEditingController(text: text))
                                  .toList();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final editors = List.generate(selectedColumns, (index) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Колонка ${index + 1}',
                                style: Theme.of(context).textTheme.labelLarge),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: lyricsControllers[index],
                                onTap: () => activeLyricsColumn = index,
                                onChanged: (_) => setSheetState(() {}),
                                minLines: 12,
                                maxLines: 18,
                                keyboardType: TextInputType.multiline,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  height: 1.55,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Текст и аккорды…',
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          );
                        });
                        if (selectedColumns > 1 && constraints.maxWidth >= 760) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var index = 0; index < editors.length; index++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: index == editors.length - 1 ? 0 : 12,
                                    ),
                                    child: editors[index],
                                  ),
                                ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            for (var index = 0; index < editors.length; index++)
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == editors.length - 1 ? 0 : 12,
                                ),
                                child: editors[index],
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('Предпросмотр документа',
                      style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SingleChildScrollView(
                        child: SongLyricsView(
                          lyrics: SongDocument.joinColumns(
                            lyricsControllers.map((controller) => controller.text).toList(),
                          ),
                          columns: selectedColumns,
                          columnBreaks: SongDocument.columnBreaksFor(
                            lyricsControllers.map((controller) => controller.text).toList(),
                          ),
                          textStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!(formKey.currentState?.validate() ?? false)) {
                                return;
                              }
                              setSheetState(() => saving = true);
                              try {
                                final group = await ref.read(activeGroupProvider.future);
                                if (group == null) {
                                  throw StateError('Сначала выберите музыкальную группу.');
                                }
                                final repository = await ref.read(songRepositoryProvider.future);
                                final bpmText = bpmController.text.trim();
                                // WHY: editing a song must not silently discard legacy tags
                                // or rewrite their capitalization when the user only edits lyrics.
                                final tags = tagsController.text
                                    .split(',')
                                    .map((tag) => tag.trim())
                                    .where((tag) => tag.isNotEmpty)
                                    .toList(growable: false);
                                final base = existing ?? Song.fromJson({
                                  'id': DateTime.now().microsecondsSinceEpoch.toString(),
                                  'title': titleController.text.trim(),
                                  'lyrics': '',
                                });
                                final edited = base.withEdits(
                                  title: titleController.text.trim(),
                                  artist: artistController.text.trim(),
                                  key: selectedKey,
                                  bpm: bpmText.isEmpty ? null : int.parse(bpmText),
                                  tags: tags,
                                  lyrics: SongDocument.joinColumns(
                                    lyricsControllers.map((controller) => controller.text).toList(),
                                  ),
                                  lyricsColumns: selectedColumns,
                                  lyricsColumnBreaks: SongDocument.columnBreaksFor(
                                    lyricsControllers.map((controller) => controller.text).toList(),
                                  ),
                                );
                                final sync = await repository.saveGroupSong(group.id, edited);
                                syncPending = sync.hasPending;
                                syncFailed = sync.hasPermanentFailure;
                                ref.invalidate(groupSongsProvider);
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop(true);
                                }
                              } catch (error) {
                                setSheetState(() => saving = false);
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                                    SnackBar(content: Text('Не удалось сохранить: $error')),
                                  );
                                }
                              }
                            },
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(saving ? 'Сохранение…' : 'Сохранить песню'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      if (saved == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(syncFailed
              ? 'Песня сохранена на устройстве, но сервер отклонил синхронизацию.'
              : syncPending
                  ? 'Песня сохранена на устройстве. Ожидает синхронизации.'
                  : 'Песня сохранена в репертуаре группы')),
        );
      }
    } finally {
      titleController.dispose();
      artistController.dispose();
      bpmController.dispose();
      tagsController.dispose();
      for (final controller in lyricsControllers) {\n        controller.dispose();\n      }
    }
  }

  Future<String?> _promptChord(BuildContext context) async {
    final controller = TextEditingController(text: 'Am');
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Добавить аккорд'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.none,
            decoration: const InputDecoration(
              labelText: 'Аккорд',
              hintText: 'Например, Am7 или D/F#',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) {
              if (SongDocument.isChordSymbol(value.trim())) {
                Navigator.of(dialogContext).pop(value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();
                if (SongDocument.isChordSymbol(value)) {
                  Navigator.of(dialogContext).pop(value);
                }
              },
              child: const Text('Вставить'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showSong(BuildContext context, Song song) {
    var semitones = 0;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final displayedSong = song.transposedBy(semitones);
          return SafeArea(
            child: FractionallySizedBox(
              heightFactor: 0.88,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => StageModePage(
                            song: song,
                            initialSemitones: semitones,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.theater_comedy_rounded),
                      label: const Text('Сценический режим'),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(song.title, style: Theme.of(context).textTheme.headlineSmall),
                        if (song.artist.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(song.artist, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text('Тональность', style: Theme.of(context).textTheme.labelLarge),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Понизить на полутон',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setSheetState(() => semitones--),
                              icon: const Icon(Icons.remove_circle_outline_rounded),
                            ),
                            Text(
                              displayedSong.key.isEmpty ? '—' : displayedSong.key,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            IconButton(
                              tooltip: 'Повысить на полутон',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setSheetState(() => semitones++),
                              icon: const Icon(Icons.add_circle_outline_rounded),
                            ),
                            if (semitones != 0)
                              TextButton(
                                onPressed: () => setSheetState(() => semitones = 0),
                                child: const Text('Сбросить'),
                              ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (song.bpm != null) _SongMeta(label: 'BPM', value: song.bpm.toString()),
                            for (final tag in song.tags) _SongMeta(label: 'Тег', value: tag),
                          ],
                        ),
                        if (semitones != 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Транспонирование применяется только к просмотру и не меняет сохранённую песню.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: displayedSong.lyrics.isEmpty
                          ? const Text('Текст песни пока не добавлен.')
                          : SongLyricsView(
                              lyrics: displayedSong.lyrics,
                              columns: displayedSong.lyricsColumns,
                              columnBreaks: displayedSong.lyricsColumnBreaks,
                              textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontFamily: 'monospace',
                                height: 1.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}

class _SongTile extends StatelessWidget {
  const _SongTile({required this.song, required this.onTap, this.onEdit});

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(song.key.isEmpty ? '♫' : song.key,
              style: Theme.of(context).textTheme.labelMedium),
        ),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [if (song.artist.isNotEmpty) song.artist, if (song.bpm != null) '${song.bpm} BPM']
              .join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                tooltip: 'Редактировать песню',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            if (song.isFavorite)
              const Icon(Icons.star_rounded, color: Colors.amber)
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _SongMeta extends StatelessWidget {
  const _SongMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label: $value'));
  }
}

class _EmptySongs extends StatelessWidget {
  const _EmptySongs({required this.hasQuery, required this.isPersonal});

  final bool hasQuery;
  final bool isPersonal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music_outlined,
                size: 44, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 12),
            Text(
              hasQuery
                  ? 'Ничего не найдено'
                  : isPersonal
                      ? 'Личная библиотека пока пуста'
                      : 'В репертуаре пока нет песен',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'Попробуйте изменить поисковый запрос.'
                  : 'Здесь появятся песни, уже сохранённые в BandPlan.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
