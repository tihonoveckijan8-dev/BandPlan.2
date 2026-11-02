import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/song_providers.dart';
import '../domain/song.dart';

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
      body: SafeArea(
        child: Column(
          children: [
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
                  hintText: 'Название, исполнитель или текст песни',
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

  Future<void> _showSong(BuildContext context, Song song) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                        style: Theme.of(context).textTheme.headlineSmall),
                    if (song.artist.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(song.artist,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (song.key.isNotEmpty) _SongMeta(label: 'Тональность', value: song.key),
                        if (song.bpm != null) _SongMeta(label: 'BPM', value: '${song.bpm}'),
                        for (final tag in song.tags) _SongMeta(label: 'Тег', value: tag),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: SelectableText(
                    song.lyrics.isEmpty ? 'Текст песни пока не добавлен.' : song.lyrics,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.65,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

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
        trailing: song.isFavorite
            ? const Icon(Icons.star_rounded, color: Colors.amber)
            : const Icon(Icons.chevron_right_rounded),
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
