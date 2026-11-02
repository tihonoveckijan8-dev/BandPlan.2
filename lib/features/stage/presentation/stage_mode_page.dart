import 'dart:async';

import 'package:flutter/material.dart';

import '../../songs/domain/song.dart';

/// Read-only performance screen with a cancellable, adjustable text scroller.
class StageModePage extends StatefulWidget {
  const StageModePage({
    super.key,
    required this.song,
    this.initialSemitones = 0,
    this.performanceNote = '',
  });

  final Song song;
  final int initialSemitones;
  final String performanceNote;

  @override
  State<StageModePage> createState() => _StageModePageState();
}

class _StageModePageState extends State<StageModePage> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  double _fontSize = 30;
  double _speed = 24;
  bool _isScrolling = false;
  bool _showChords = true;

  Song get _song => widget.song.transposedBy(widget.initialSemitones);

  String get _lyrics {
    if (_showChords) return _song.lyrics;
    // WHY: hide chord tokens only; section labels such as [Куплет] stay visible.
    return _song.lyrics.replaceAll(
      RegExp(r'\[(?:[A-G](?:#|b)?)(?:(?:maj|min|m|M|dim|aug|sus[24]?|add\d+|no\d+|omit\d+|\d+|[b#]\d+|ø|°|\+|-)*)?(?:/[A-G](?:#|b)?)?\]'),
      '',
    );
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
    return Scaffold(
      appBar: AppBar(
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
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
                      if (song.key.isNotEmpty) _StageChip(label: song.key),
                      if (song.bpm != null) _StageChip(label: '${song.bpm} BPM'),
                      if (widget.initialSemitones != 0)
                        _StageChip(
                          label: '${widget.initialSemitones > 0 ? '+' : ''}${widget.initialSemitones} пт.',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.performanceNote.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(widget.performanceNote),
                ),
              ),
            const Divider(height: 1),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 36),
                  child: SelectableText(
                    _lyrics.isEmpty ? 'Текст песни пока не добавлен.' : _lyrics,
                    style: TextStyle(
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.text_fields_rounded),
                      IconButton(
                        tooltip: 'Уменьшить текст',
                        onPressed: () => _changeFont(-2),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Expanded(
                        child: Center(child: Text('${_fontSize.round()} px')),
                      ),
                      IconButton(
                        tooltip: 'Увеличить текст',
                        onPressed: () => _changeFont(2),
                        icon: const Icon(Icons.add_rounded),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: _isScrolling ? _pauseScroll : _startScroll,
                        icon: Icon(_isScrolling ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        label: Text(_isScrolling ? 'Пауза' : 'Автопрокрутка'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.slow_motion_video_rounded, size: 20),
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
                        width: 54,
                        child: Text('${_speed.round()} px/с', textAlign: TextAlign.end),
                      ),
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
