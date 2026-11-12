import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

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

/// Immersive, text-only performance view with pinch zoom and track navigation.
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
  late int _trackIndex;
  final TransformationController _transformController = TransformationController();

  StageModeTrack get _track => widget.queue.isEmpty
      ? StageModeTrack(
          song: widget.song,
          semitones: widget.initialSemitones,
          note: widget.performanceNote,
        )
      : widget.queue[_trackIndex];

  Song get _song => _track.song.transposedBy(_track.semitones);

  @override
  void initState() {
    super.initState();
    _trackIndex = widget.queue.isEmpty
        ? 0
        : widget.initialTrackIndex.clamp(0, widget.queue.length - 1).toInt();
    // WHY: performance mode must use the entire display, not the app chrome.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _moveTrack(int delta) {
    final next = _trackIndex + delta;
    if (next < 0 || next >= widget.queue.length) return;
    setState(() {
      _trackIndex = next;
      _transformController.value = Matrix4.identity();
    });
  }

  @override
  void dispose() {
    _transformController.dispose();
    // WHY: restore the normal system bars when leaving the immersive stage.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final song = _song;
    final hasQueue = widget.queue.length > 1;
    final textColor = Colors.white;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.55,
                    maxScale: 3.2,
                    boundaryMargin: const EdgeInsets.all(240),
                    clipBehavior: Clip.none,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                        child: song.lyrics.isEmpty
                            ? Center(
                                child: Text(
                                  'Текст песни пока не добавлен.',
                                  style: TextStyle(color: textColor, fontSize: 28),
                                ),
                              )
                            : Align(
                                alignment: Alignment.topLeft,
                                child: SongLyricsView(
                                  lyrics: song.lyrics,
                                  columns: song.lyricsColumns,
                                  columnBreaks: song.lyricsColumnBreaks,
                                  textStyle: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 30,
                                    height: 1.55,
                                    color: textColor,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                if (hasQueue) ...[
                  Positioned(
                    left: 12,
                    bottom: 14,
                    child: _StageNavigationButton(
                      tooltip: 'Предыдущая песня',
                      icon: Icons.skip_previous_rounded,
                      enabled: _trackIndex > 0,
                      onPressed: () => _moveTrack(-1),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 14,
                    child: _StageNavigationButton(
                      tooltip: 'Следующая песня',
                      icon: Icons.skip_next_rounded,
                      enabled: _trackIndex < widget.queue.length - 1,
                      onPressed: () => _moveTrack(1),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StageNavigationButton extends StatelessWidget {
  const _StageNavigationButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 34),
        color: Colors.white,
        disabledColor: Colors.white24,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(.12),
          padding: const EdgeInsets.all(14),
        ),
      );
}
