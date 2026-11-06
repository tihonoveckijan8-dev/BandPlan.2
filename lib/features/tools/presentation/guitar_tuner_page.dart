import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../domain/pitch_detector.dart';

class GuitarTunerPage extends StatefulWidget {
  const GuitarTunerPage({super.key});
  @override
  State<GuitarTunerPage> createState() => _GuitarTunerPageState();
}

class _GuitarTunerPageState extends State<GuitarTunerPage>
    with WidgetsBindingObserver {
  static const strings = <_String>[
    _String('E', 2, 82.4069, '6'),
    _String('A', 2, 110.0, '5'),
    _String('D', 3, 146.8324, '4'),
    _String('G', 3, 195.9977, '3'),
    _String('B', 3, 246.9417, '2'),
    _String('E', 4, 329.6276, '1'),
  ];

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  PitchDetector _detector = const PitchDetector();
  StreamSubscription<Uint8List>? _subscription;
  Uint8List _buffer = Uint8List(0);
  int _selected = 0;
  double? _frequency, _cents;
  bool _listening = false, _starting = false, _playing = false;
  String? _error;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  _String get target => strings[_selected];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _listening) {
      unawaited(_stop());
    }
  }

  Future<void> _start() async {
    if (_listening || _starting) return;
    setState(() {
      _starting = true;
      _error = null;
      _frequency = null;
      _cents = null;
    });
    try {
      if (!await _recorder.hasPermission()) {
        throw Exception('Разрешите доступ к микрофону в настройках устройства.');
      }
      // WHY: Some audio devices/browser contexts negotiate a different sample
      // rate than requested. Use the effective rate to avoid systematic pitch drift.
      await _recorder.setOnConfigChanged((config) {
        _detector = PitchDetector(sampleRate: config.sampleRate);
      });
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: true,
        echoCancel: false,
        noiseSuppress: false,
      ));
      _buffer = Uint8List(0);
      _subscription = stream.listen(_onAudio, onError: (Object error) {
        if (mounted) setState(() => _error = 'Ошибка микрофона: $error');
        unawaited(_stop());
      });
      if (mounted) setState(() { _starting = false; _listening = true; });
    } catch (error) {
      if (mounted) {
        setState(() {
          _starting = false;
          _error = error.toString().toLowerCase().contains('permission')
              ? 'Нет доступа к микрофону. Разрешите его в настройках.'
              : 'Не удалось запустить микрофон. Проверьте разрешение и повторите.';
        });
      }
    }
  }

  void _onAudio(Uint8List chunk) {
    // WHY: Stream packet sizes differ by platform; process fixed 4096-sample
    // windows so pitch detection remains stable on Android, iOS and Web.
    final joined = Uint8List(_buffer.length + chunk.length)
      ..setRange(0, _buffer.length, _buffer)
      ..setRange(_buffer.length, _buffer.length + chunk.length, chunk);
    const frameBytes = 8192;
    if (joined.length < frameBytes) {
      _buffer = joined;
      return;
    }
    final frame = Uint8List.sublistView(joined, joined.length - frameBytes);
    _buffer = Uint8List.sublistView(joined, joined.length - frameBytes ~/ 2);
    final hz = _detector.detect(frame);
    final now = DateTime.now();
    if (now.difference(_lastUpdate).inMilliseconds < 50) return;
    _lastUpdate = now;
    if (!mounted) return;
    if (hz == null) {
      if (_frequency != null) setState(() { _frequency = null; _cents = null; });
      return;
    }
    final cents = 1200 * math.log(hz / target.hz) / math.ln2;
    setState(() { _frequency = hz; _cents = cents; });
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {
      // WHY: A route change can race with the platform recorder shutdown.
    }
    if (mounted) {
      setState(() {
        _listening = false;
        _starting = false;
        _frequency = null;
        _cents = null;
      });
    }
  }

  Future<void> _reference() async {
    if (_playing) return;
    await _stop();
    setState(() { _playing = true; _error = null; });
    try {
      await _player.play(BytesSource(_wav(target.hz), mimeType: 'audio/wav'));
      await _player.onPlayerComplete.first;
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось воспроизвести эталонную ноту.');
    } finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  Uint8List _wav(double hz) {
    const rate = 44100, count = 44100, dataBytes = count * 2;
    final data = ByteData(44 + dataBytes);
    void tag(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        data.setUint8(offset + i, value.codeUnitAt(i));
      }
    }
    tag(0, 'RIFF');
    data.setUint32(4, 36 + dataBytes, Endian.little);
    tag(8, 'WAVE'); tag(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    data.setUint32(40, dataBytes, Endian.little);
    for (var i = 0; i < count; i++) {
      final fade = math.min(1.0, math.min(i / 600, (count - i) / 600));
      final sample = math.sin(2 * math.pi * hz * i / rate) * 0.22 * fade;
      data.setInt16(44 + i * 2, (sample * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cents = _cents;
    final tuned = cents != null && cents.abs() <= 5;
    final accent = cents == null
        ? theme.colorScheme.primary
        : tuned ? const Color(0xFF249B68) : theme.colorScheme.primary;
    final status = cents == null
        ? (_listening ? 'ИГРАЙТЕ НА СТРУНЕ' : 'ГОТОВ К НАСТРОЙКЕ')
        : tuned ? 'НАСТРОЕНО' : cents < 0 ? 'НИЖЕ ЭТАЛОНА' : 'ВЫШЕ ЭТАЛОНА';

    return Scaffold(
      appBar: AppBar(title: const Text('Гитарный тюнер')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Text('Стандартный строй', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('E2 · A2 · D3 · G3 · B3 · E4',
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
                Text('${target.note}', style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 76, height: 1, fontWeight: FontWeight.w700, color: accent)),
                const SizedBox(height: 8),
                Text(_frequency == null
                    ? 'Цель ${target.hz.toStringAsFixed(2)} Hz'
                    : '${_frequency!.toStringAsFixed(2)} Hz',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 22),
                SizedBox(height: 76, child: CustomPaint(
                  painter: _MeterPainter(
                    position: (cents == null ? 0.0 : cents / 50).clamp(-1.0, 1.0).toDouble(),
                    color: accent,
                    muted: cents == null,
                    track: theme.colorScheme.onSurfaceVariant,
                  ),
                  child: const SizedBox.expand(),
                )),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('−50'), const Text('0'), const Text('+50'),
                ]),
                const SizedBox(height: 10),
                Text(cents == null ? (_listening ? 'Слушаю…' : 'Микрофон выключен')
                    : '${cents > 0 ? '+' : ''}${cents.toStringAsFixed(1)} cents',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: accent, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 18),
            Row(children: [
              for (var i = 0; i < strings.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _StringChip(
                  value: strings[i], selected: i == _selected,
                  onTap: () => setState(() {
                    _selected = i; _frequency = null; _cents = null;
                  }),
                )),
              ],
            ]),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _starting ? null : (_listening ? _stop : _start),
              icon: _starting
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
              label: Text(_starting ? 'Подключаем микрофон…'
                  : _listening ? 'Остановить микрофон' : 'Начать настройку'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _playing ? null : _reference,
              icon: const Icon(Icons.volume_up_rounded),
              label: Text(_playing ? 'Воспроизводим…'
                  : 'Послушать эталон ${target.note}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(14)),
                child: Text(_error!,
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

class _StringChip extends StatelessWidget {
  const _StringChip({required this.value, required this.selected, required this.onTap});
  final _String value;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Column(children: [
            Text(value.name, style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurface)),
            Text(value.number, style: theme.textTheme.labelSmall),
          ]),
        ),
      ),
    );
  }
}

class _MeterPainter extends CustomPainter {
  const _MeterPainter({required this.position, required this.color,
    required this.muted, required this.track});
  final double position;
  final Color color, track;
  final bool muted;
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, y = size.height - 8;
    final half = math.min(size.width * .43, 190.0).toDouble();
    final base = Paint()..color = track.withOpacity(.32)
      ..strokeWidth = 3..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx - half, y), Offset(cx + half, y), base);
    for (var i = -5; i <= 5; i++) {
      final x = cx + half * i / 5;
      canvas.drawLine(Offset(x, y - (i == 0 || i.abs() == 5 ? 25 : 13)),
        Offset(x, y + 1), Paint()..color = track.withOpacity(.55)
          ..strokeWidth = i == 0 ? 2 : 1.2);
    }
    final x = cx + half * position;
    final needle = Paint()..color = muted ? track.withOpacity(.7) : color
      ..strokeWidth = 3.5..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x, y - 35), Offset(x, y + 3), needle);
    canvas.drawCircle(Offset(x, y - 38), 5, Paint()..color = needle.color);
    canvas.drawCircle(Offset(cx, y), 5, Paint()..color = needle.color);
  }
  @override
  bool shouldRepaint(covariant _MeterPainter old) =>
      old.position != position || old.color != color ||
      old.muted != muted || old.track != track;
}

class _String {
  const _String(this.name, this.octave, this.hz, this.number);
  final String name, number;
  final int octave;
  final double hz;
  String get note => '$name$octave';
}
