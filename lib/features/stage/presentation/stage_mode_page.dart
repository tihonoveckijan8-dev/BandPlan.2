import 'dart:async';

import 'package:flutter/material.dart';

import '../../songs/domain/song.dart';
import '../../songs/presentation/song_lyrics_view.dart';

/// A setlist-specific song view; the source repertoire record remains untouched.
class StageModeTrack {
  const StageModeTrack({
    required this.song,
    this.semitones = 0,
    this.note = '',
  });

  final Song song;
  final int semitones;
  final String note;
}

/// Read-only performance screen with cancellable scrolling and optional track navigation.
class StageModePage extends StatefulWidget {
  const StageModePage({
    super.key,
    required this.song,
    this.initialSemitones = 0,
    this.performanceNote = '',
    this.queue = const [],
    this.initialTrackIndex = 0,
  });

  final Song song;
  final int initialSemitones;
  final String performanceNote;
  final List<StageModeTrack> queue;
  final int initialTrackIndex;

  @override
  State<StageModePage> createState() => _StageModePageState();
}

class _StageModePageState extends State<StageModePage> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  late int _trackIndex;
  double _fontSize = 30;
  double _speed = 24;
  bool _isScrolling = false;
  bool _showChords = true;
  int _liveSemitones = 0;

  StageModeTrack get _track => widget.queue.isEmpty
      ? StageModeTrack(
          song: widget.song,
          semitones: widget.initialSemitones,
          note: widget.performanceNote,
        )
      : widget.queue[_trackIndex];

  int get _effectiveSemitones => _track.semitones + _liveSemitones;

  Song get _song => _track.song.transposedBy(_effectiveSemitones);

  @override
  void initState() {
    super.initState();
    _trackIndex = widget.queue.isEmpty
        ? 0
        : widget.initialTrackIndex.clamp(0, widget.queue.length - 1).toInt();
  }

  String get _lyrics {
    final lyrics = _song.lyrics;
    if (_showChords) return lyrics;
    // WHY: hide chord tokens only; section labels such as [Куплет] stay visible.
    return lyrics.replaceAll(
      RegExp(r'\[(?:[A-G](?:#|b)?)(?:(?:maj|min|m|M|dim|aug|sus[24]?|add\d+|no\d+|omit\d+|\d+|[b#]\d+|ø|°|\+|-)*)?(?:/[A-G](?:#|b)?)?\]'),
      '',
    );
  }

  void _moveTrack(int delta) {
    final next = _trackIndex + delta;
    if (next < 0 || next >= widget.queue.length) return;
    _pauseScroll();
    setState(() {
      _trackIndex = next;
      _liveSemitones = 0;
      // WHY: each song starts at its first line instead of inheriting the prior song's offset.
      _scrollController.jumpTo(0);
    });
  }

  void _startScroll() {
    if (_isScrolling) return;
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 1) {
      _scrollController.jumpTo(0);
    }
    setState(() => _isScrolling = true);
    _scrollTimer?.cancel();
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final next = (position.pixels + _speed * 0.05)
          .clamp(0.0, position.maxScrollExtent)
          .toDouble();
      _scrollController.jumpTo(next);
      if (next >= position.maxScrollExtent) _pauseScroll();
    });
  }

  void _pauseScroll() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
    if (mounted && _isScrolling) setState(() => _isScrolling = false);
  }

  void _changeFont(double delta) {
    setState(() => _fontSize = (_fontSize + delta).clamp(18, 54).toDouble());
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = _song;
    final colorScheme = Theme.of(context).colorScheme;
    final hasQueue = widget.queue.length > 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (hasQueue)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('${_trackIndex + 1}/${widget.queue.length}'),
              ),
            ),
          IconButton(
            tooltip: _showChords ? 'Скрыть аккорды' : 'Показать аккорды',
            onPressed: () => setState(() => _showChords = !_showChords),
            icon: Icon(_showChords ? Icons.music_note_rounded : Icons.music_off_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (song.artist.isNotEmpty)
                    Text(song.artist, style: Theme.of(context).textTheme.titleMedium),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (song.key.isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Понизить тональность на полтона',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() => _liveSemitones--),
                              icon: const Icon(Icons.remove_circle_outline_rounded),
                            ),
                            _StageChip(label: song.key),
                            IconButton(
                              tooltip: 'Повысить тональность на полтона',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() => _liveSemitones++),
                              icon: const Icon(Icons.add_circle_outline_rounded),
                            ),
                          ],
                        ),
                      if (song.bpm != null) _StageChip(label: '${song.bpm} BPM'),
                      if (_effectiveSemitones != 0)
                        _StageChip(
                          label: '${_effectiveSemitones > 0 ? '+' : ''}${_effectiveSemitones} пт.',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (_track.note.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_track.note),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  key: ValueKey('stage-lyrics-${_trackIndex}'),
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 36),
                  child: _lyrics.isEmpty
                      ? const Text('Текст песни пока не добавлен.')
                      : SongLyricsView(
                          lyrics: _lyrics,
                          textStyle: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: _fontSize,
                            height: 1.65,
                            color: colorScheme.onSurface,
                          ),
                        ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasQueue)
                    Row(
                      children: [
                        // WHY: icon-only navigation preserves 48px touch targets without
                        // forcing long labels into the narrow phone control bar.
                        IconButton.filledTonal(
                          tooltip: 'Предыдущая песня',
                          onPressed: _trackIndex > 0 ? () => _moveTrack(-1) : null,
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Песня ${_trackIndex + 1} из ${widget.queue.length}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Следующая песня',
                          onPressed: _trackIndex < widget.queue.length - 1
                              ? () => _moveTrack(1)
                              : null,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      const Icon(Icons.text_fields_rounded, size: 20),
                      IconButton(
                        tooltip: 'Уменьшить текст',
                        onPressed: () => _changeFont(-2),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Expanded(child: Center(child: Text('${_fontSize.round()} px'))),
                      IconButton(
                        tooltip: 'Увеличить текст',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _changeFont(2),
                        icon: const Icon(Icons.add_rounded),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: _isScrolling ? 'Пауза' : 'Автопрокрутка',
                        child: FilledButton.tonal(
                          onPressed: _isScrolling ? _pauseScroll : _startScroll,
                          child: Icon(
                            _isScrolling ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.slow_motion_video_rounded, size: 18),
                      Expanded(
                        child: Slider(
                          min: 5,
                          max: 80,
                          divisions: 15,
                          value: _speed,
                          label: '${_speed.round()} px/с',
                          onChanged: (value) => setState(() => _speed = value),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text('${_speed.round()}', textAlign: TextAlign.end),
                      ),
                      const Text(' px/с'),
                    ],
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

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Chip(
        visualDensity: VisualDensity.compact,
        label: Text(label),
      );
}
