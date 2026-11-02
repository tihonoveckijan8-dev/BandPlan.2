import 'package:flutter/material.dart';

import '../../songs/domain/song.dart';
import '../domain/setlist.dart';
import '../../stage/presentation/stage_mode_page.dart';
import '../../songs/presentation/song_lyrics_view.dart';

/// Read-only performance view. Per-item transposition is applied to a temporary
/// Song view so the original repertoire record is never modified.
class SetlistRunPage extends StatefulWidget {
  const SetlistRunPage({
    super.key,
    required this.setlist,
    required this.songs,
  });

  final Setlist setlist;
  final List<Song> songs;

  @override
  State<SetlistRunPage> createState() => _SetlistRunPageState();
}

class _SetlistRunPageState extends State<SetlistRunPage> {
  int _index = 0;

  Map<String, Song> get _songById => {
        for (final song in widget.songs) song.id: song,
      };

  SetlistItem get _item => widget.setlist.items[_index];

  Song? get _sourceSong => _songById[_item.songId];

  Song? get _displayedSong => _sourceSong?.transposedBy(_item.shift);

  void _move(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.setlist.items.length) return;
    setState(() => _index = next);
  }

  void _openStage(BuildContext context) {
    final queue = <StageModeTrack>[];
    var currentTrackIndex = 0;
    for (var i = 0; i < widget.setlist.items.length; i++) {
      final item = widget.setlist.items[i];
      final song = _songById[item.songId];
      if (song == null) continue;
      // WHY: map the selected setlist item after missing songs are skipped.
      if (i == _index) currentTrackIndex = queue.length;
      queue.add(StageModeTrack(song: song, semitones: item.shift, note: item.note));
    }
    if (queue.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => StageModePage(
          song: queue[currentTrackIndex].song,
          queue: queue,
          initialTrackIndex: currentTrackIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final source = _sourceSong;
    final song = _displayedSong;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.setlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_sourceSong != null)
            IconButton(
              tooltip: 'Сценический режим',
              onPressed: () => _openStage(context),
              icon: const Icon(Icons.theater_comedy_rounded),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '${_index + 1} / ${widget.setlist.items.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.setlist.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  widget.setlist.note,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song?.title ?? 'Песня не найдена',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (song != null && song.artist.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(song.artist, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (song != null && song.key.isNotEmpty)
                        _RunMeta(label: 'Тональность', value: song.key),
                      if (song?.bpm != null)
                        _RunMeta(label: 'BPM', value: song!.bpm.toString()),
                      if (song?.durationSeconds != null && song!.durationSeconds! > 0)
                        _RunMeta(
                          label: 'Длительность',
                          value: '${song.durationSeconds! ~/ 60} мин',
                        ),
                      if (item.shift != 0)
                        _RunMeta(
                          label: 'Сдвиг',
                          value: '${item.shift > 0 ? '+' : ''}${item.shift} пт.',
                        ),
                    ],
                  ),
                  if (item.note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.sticky_note_2_outlined, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(item.note)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: source == null
                    ? const Text('Эта песня больше не доступна в репертуаре группы.')
                    : song!.lyrics.isEmpty
                        ? const Text('Текст песни пока не добавлен.')
                        : SongLyricsView(
                            // WHY: setlist execution must render chord anchors like Stage mode,
                            // not expose the stored [Chord] tokens as plain lyric text.
                            lyrics: song.lyrics,
                            textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontFamily: 'monospace',
                                  height: 1.7,
                                ),
                          ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _index > 0 ? () => _move(-1) : null,
                      icon: const Icon(Icons.skip_previous_rounded),
                      label: const Text('Назад'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _index < widget.setlist.items.length - 1
                          ? () => _move(1)
                          : () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        _index < widget.setlist.items.length - 1
                            ? Icons.skip_next_rounded
                            : Icons.check_rounded,
                      ),
                      label: Text(
                        _index < widget.setlist.items.length - 1
                            ? 'Следующая'
                            : 'Завершить',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RunMeta extends StatelessWidget {
  const _RunMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text('$label: $value'),
    );
  }
}
