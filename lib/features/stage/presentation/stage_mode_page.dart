import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../../core/stage_mode_visibility.dart';
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
  Timer? _controlsHideTimer;
  bool _controlsVisible = true;

  void _scheduleControlsHide() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

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
    stageModeIsActive.value = true;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleControlsHide();
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
    _controlsHideTimer?.cancel();
    stageModeIsActive.value = false;
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
      body: GestureDetector(
        // WHY: a tap on the performance canvas reveals controls temporarily;
        // the lyrics stay unobstructed during normal use.
        behavior: HitTestBehavior.translucent,
        onTap: _showControls,
        child: SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final viewPadding = MediaQuery.of(context).viewPadding;
            // WHY: stage lyrics and chords use fixed, readable sizes on every display.
            final horizontalPadding = width < 600 ? 18.0 : width < 1000 ? 28.0 : 40.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    // WHY: let long lyrics keep their natural height so the performer
                    // can pan through the complete document instead of seeing a clipped viewport.
                    constrained: false,
                    minScale: 0.55,
                    maxScale: 3.2,
                    boundaryMargin: const EdgeInsets.all(240),
                    clipBehavior: Clip.none,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          width < 600 ? 22 : 28,
                          horizontalPadding,
                          width < 600 ? 30 : 36,
                        ),
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
                                  textStyle: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                    height: 1.45,
                                    color: Colors.white,
                                  ),
                                  chordStyle: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 18,
                                    height: 1,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 10,
                          right: 10,
                          child: SafeArea(
                            child: _StageNavigationButton(
                              tooltip: 'Выйти из режима сцены',
                              icon: Icons.close_rounded,
                              enabled: true,
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                          ),
                        ),
                        if (hasQueue) ...[
                          Positioned(
                            bottom: (viewPadding.bottom + 14).clamp(14.0, 48.0).toDouble(),
                            left: (viewPadding.left + 12).clamp(12.0, 40.0).toDouble(),
                            child: _StageNavigationButton(
                              tooltip: 'Предыдущая песня',
                              icon: Icons.skip_previous_rounded,
                              enabled: _trackIndex > 0,
                              onPressed: () => _moveTrack(-1),
                            ),
                          ),
                          Positioned(
                            right: (viewPadding.right + 12).clamp(12.0, 40.0).toDouble(),
                            bottom: (viewPadding.bottom + 14).clamp(14.0, 48.0).toDouble(),
                            child: _StageNavigationButton(
                              tooltip: 'Следующая песня',
                              icon: Icons.skip_next_rounded,
                              enabled: _trackIndex < widget.queue.length - 1,
                              onPressed: () => _moveTrack(1),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
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
