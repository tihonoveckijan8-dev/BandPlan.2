import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../domain/pitch_detector.dart';

class ViolinTunerPage extends StatefulWidget {
  const ViolinTunerPage({super.key});
  @override
  State<ViolinTunerPage> createState() => _ViolinTunerPageState();
}

class _ViolinTunerPageState extends State<ViolinTunerPage>
    with WidgetsBindingObserver {
  static const notes = <_ViolinNote>[
    _ViolinNote('G', 3, 195.9977),
    _ViolinNote('D', 4, 293.6648),
    _ViolinNote('A', 4, 440),
    _ViolinNote('E', 5, 659.2551),
  ];
  final recorder = AudioRecorder();
  final detector = const PitchDetector(sampleRate: 44100);
  final stabilizer = PitchStabilizer();
  StreamSubscription<Uint8List>? subscription;
  Uint8List buffer = Uint8List(0);
  int selected = 2;
  bool autoSelect = true, listening = false, starting = false;
  double? frequency, cents;
  String? error;
  DateTime lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  _ViolinNote get target => notes[selected];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && listening) unawaited(stop());
  }

  Future<void> start() async {
    if (listening || starting) return;
    setState(() { starting = true; error = null; frequency = null; cents = null; });
    try {
      if (!await recorder.hasPermission()) throw StateError('permission denied');
      final stream = await recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits, sampleRate: 44100, numChannels: 1,
        autoGain: true, echoCancel: false, noiseSuppress: false,
      ));
      buffer = Uint8List(0);
      stabilizer.reset();
      subscription = stream.listen(onAudio, onError: (Object _) {
        if (mounted) setState(() => error = 'Ошибка микрофона. Проверьте разрешение.');
        unawaited(stop());
      });
      if (mounted) setState(() { starting = false; listening = true; });
    } catch (_) {
      if (mounted) setState(() {
        starting = false;
        error = 'Не удалось включить микрофон. Разрешите доступ и попробуйте снова.';
      });
    }
  }

  void onAudio(Uint8List chunk) {
    final joined = Uint8List(buffer.length + chunk.length)
      ..setRange(0, buffer.length, buffer)
      ..setRange(buffer.length, buffer.length + chunk.length, chunk);
    // WHY: Fixed PCM windows keep estimates stable across browser audio packet sizes.
    const frameBytes = 16384;
    if (joined.length < frameBytes) { buffer = joined; return; }
    final frame = Uint8List.sublistView(joined, joined.length - frameBytes);
    buffer = Uint8List.sublistView(joined, joined.length - frameBytes ~/ 2);
    final now = DateTime.now();
    if (now.difference(lastUpdate).inMilliseconds < 65) return;
    lastUpdate = now;
    final hz = stabilizer.add(detector.detect(frame));
    if (!mounted) return;
    if (hz == null) {
      if (frequency != null) setState(() { frequency = null; cents = null; });
      return;
    }
    if (autoSelect) {
      var best = 0, distance = double.infinity;
      for (var i = 0; i < notes.length; i++) {
        final current = (1200 * math.log(hz / notes[i].hz) / math.ln2).abs();
        if (current < distance) { best = i; distance = current; }
      }
      selected = best;
    }
    setState(() {
      frequency = hz;
      cents = 1200 * math.log(hz / target.hz) / math.ln2;
    });
  }

  Future<void> stop() async {
    await subscription?.cancel();
    subscription = null;
    try {
      if (await recorder.isRecording()) await recorder.stop();
    } catch (_) {
      // WHY: Route changes may race with the browser recorder shutdown.
    }
    if (mounted) setState(() {
      listening = false; starting = false; frequency = null; cents = null;
      stabilizer.reset();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(subscription?.cancel());
    unawaited(recorder.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentCents = cents;
    final tuned = currentCents != null && currentCents.abs() <= 5;
    final accent = currentCents == null
        ? theme.colorScheme.primary
        : tuned ? const Color(0xFF249B68) : theme.colorScheme.primary;
    final status = currentCents == null
        ? (listening ? 'ИГРАЙТЕ НА СТРУНЕ' : 'ГОТОВ К НАСТРОЙКЕ')
        : tuned ? 'НАСТРОЕНО'
        : currentCents < 0 ? 'НИЖЕ ЭТАЛОНА' : 'ВЫШЕ ЭТАЛОНА';

    return Scaffold(
      appBar: AppBar(title: const Text('Скрипичный тюнер')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Text('Стандартный строй', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('G3 · D4 · A4 · E5',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.1,
              )),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(color: theme.colorScheme.shadow.withOpacity(.08),
                    blurRadius: 20, offset: const Offset(0, 8)),
                  BoxShadow(color: theme.colorScheme.surface.withOpacity(.9),
                    blurRadius: 1, offset: const Offset(0, -1)),
                ],
              ),
              child: Column(children: [
                Text(status, style: theme.textTheme.labelMedium?.copyWith(
                  color: accent, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 14),
                Text(target.name, style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 76, height: 1, fontWeight: FontWeight.w700, color: accent)),
                const SizedBox(height: 8),
                Text(frequency == null
                    ? 'Цель ${target.hz.toStringAsFixed(2)} Hz'
                    : '${frequency!.toStringAsFixed(2)} Hz',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 22),
                SizedBox(height: 76, child: CustomPaint(
                  painter: _ViolinMeterPainter(
                    position: (currentCents == null
                        ? 0.0 : currentCents / 50).clamp(-1.0, 1.0).toDouble(),
                    color: accent,
                    muted: currentCents == null,
                    track: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: const SizedBox.expand(),
                )),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('−50'), const Text('0'), const Text('+50'),
                ]),
                const SizedBox(height: 10),
                Text(currentCents == null
                    ? (listening ? 'Слушаю…' : 'Микрофон выключен')
                    : '${currentCents > 0 ? '+' : ''}${currentCents.toStringAsFixed(1)} cents',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: accent, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 18),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Автоопределение')),
                ButtonSegment(value: false, label: Text('Вручную')),
              ],
              selected: {autoSelect},
              showSelectedIcon: false,
              onSelectionChanged: (selection) => setState(() {
                autoSelect = selection.first;
                frequency = null;
                cents = null;
                stabilizer.reset();
              }),
            ),
            const SizedBox(height: 12),
            // WHY: Keep the four string selectors evenly sized while
            // reserving a reliable touch target on compact PWA viewports.
            Row(
              children: [
                for (var i = 0; i < notes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _ViolinStringChip(
                      value: notes[i],
                      selected: selected == i,
                      onTap: () => setState(() {
                        selected = i;
                        autoSelect = false;
                        frequency = null;
                        cents = null;
                        stabilizer.reset();
                      }),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: starting ? null : (listening ? stop : start),
              icon: starting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(listening ? Icons.stop_rounded : Icons.mic_rounded),
              label: Text(starting ? 'Запуск микрофона…'
                  : listening ? 'Остановить настройку' : 'Начать настройку'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14)),
                child: Text(error!,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer)),
              ),
            ],
            const SizedBox(height: 16),
            Text('Выберите струну и сыграйте открытый звук. Индикатор покажет, '
                'насколько нота ниже или выше эталона.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ViolinNote {
  const _ViolinNote(this.note, this.octave, this.hz);
  final String note;
  final int octave;
  final double hz;
  String get name => note + octave.toString();
}

class _ViolinStringChip extends StatelessWidget {
  const _ViolinStringChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final _ViolinNote value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value.note, style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: selected ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface)),
                Text(value.octave.toString(), style: theme.textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViolinMeterPainter extends CustomPainter {
  const _ViolinMeterPainter({
    required this.position,
    required this.color,
    required this.muted,
    required this.track,
  });

  final double position;
  final Color color, track;
  final bool muted;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, y = size.height - 8;
    final half = math.min(size.width * .43, 190.0).toDouble();
    final base = Paint()
      ..color = track.withOpacity(.32)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - half, y), Offset(cx + half, y), base);
    for (var i = -5; i <= 5; i++) {
      final x = cx + half * i / 5;
      canvas.drawLine(
        Offset(x, y - (i == 0 || i.abs() == 5 ? 25 : 13)),
        Offset(x, y + 1),
        Paint()
          ..color = track.withOpacity(.55)
          ..strokeWidth = i == 0 ? 2 : 1.2,
      );
    }
    final x = cx + half * position;
    final needle = Paint()
      ..color = muted ? track.withOpacity(.7) : color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, y - 35), Offset(x, y + 3), needle);
    canvas.drawCircle(Offset(x, y - 38), 5, Paint()..color = needle.color);
    canvas.drawCircle(Offset(cx, y), 5, Paint()..color = needle.color);
  }

  @override
  bool shouldRepaint(covariant _ViolinMeterPainter old) =>
      old.position != position || old.color != color ||
      old.muted != muted || old.track != track;
}
