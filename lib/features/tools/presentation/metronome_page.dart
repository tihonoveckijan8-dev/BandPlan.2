import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../domain/metronome_pattern.dart';

class MetronomePage extends StatefulWidget {
  const MetronomePage({super.key});

  @override
  State<MetronomePage> createState() => _MetronomePageState();
}

class _MetronomePageState extends State<MetronomePage>
    with WidgetsBindingObserver {
  static const _signatures = <(int, int)>[
    (2, 4), (3, 4), (4, 4), (5, 4), (6, 8), (9, 8), (12, 8),
  ];

  final _player = AudioPlayer();
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  int _bpm = 100;
  int _beat = -1;
  int _nextBeat = 0;
  bool _running = false;
  late MetronomePattern _pattern = MetronomePattern.commonTime(4, 4);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_player.setReleaseMode(ReleaseMode.stop));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _running) _stop();
  }

  void _setSignature((int, int) signature) {
    _stop();
    setState(() {
      _pattern = MetronomePattern.commonTime(signature.$1, signature.$2);
      _beat = -1;
    });
  }

  Future<void> _start() async {
    if (_running) return;
    setState(() {
      _running = true;
      _beat = -1;
      _nextBeat = 0;
    });
    // WHY: Stopwatch-based deadlines prevent Timer.periodic drift from
    // accumulating over long rehearsal sessions.
    _clock
      ..reset()
      ..start();
    await _tick();
  }

  Future<void> _tick() async {
    if (!_running || !mounted) return;
    final index = _nextBeat;
    setState(() => _beat = index);
    unawaited(_click(_pattern.isAccented(index)));
    _nextBeat = (_nextBeat + 1) % _pattern.beatsPerBar;
    final interval = _pattern.beatDuration(_bpm);
    final targetUs = _clock.elapsedMicroseconds + interval.inMicroseconds;
    _timer?.cancel();
    _timer = Timer(Duration(microseconds: math.max(
      0, targetUs - _clock.elapsedMicroseconds)), _tick);
  }

  Future<void> _click(bool accented) async {
    try {
      // WHY: The click is synthesized locally; no network or bundled media
      // is needed, and the accent uses a higher, stronger transient.
      await _player.stop();
      await _player.play(BytesSource(_clickWav(accented),
          mimeType: 'audio/wav'));
    } catch (_) {
      if (mounted) setState(() => _running = false);
      _timer?.cancel();
    }
  }

  Uint8List _clickWav(bool accented) {
    const rate = 44100;
    final count = accented ? 3308 : 2646;
    final bytes = count * 2;
    final data = ByteData(44 + bytes);
    void tag(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        data.setUint8(offset + i, value.codeUnitAt(i));
      }
    }
    tag(0, 'RIFF');
    data.setUint32(4, 36 + bytes, Endian.little);
    tag(8, 'WAVE'); tag(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, rate, Endian.little);
    data.setUint32(28, rate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    data.setUint32(40, bytes, Endian.little);
    final frequency = accented ? 1760.0 : 1320.0;
    final amplitude = accented ? .72 : .42;
    for (var i = 0; i < count; i++) {
      final envelope = math.exp(-i / (accented ? 390.0 : 320.0));
      final sample = math.sin(2 * math.pi * frequency * i / rate) *
          amplitude * envelope;
      data.setInt16(44 + i * 2, (sample * 32767).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    if (mounted) setState(() {
      _running = false;
      _beat = -1;
      _nextBeat = 0;
    });
    unawaited(_player.stop());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _clock.stop();
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final signature = ' ${_pattern.beatsPerBar}/${_pattern.denominator}';
    return Scaffold(
      appBar: AppBar(title: const Text('Метроном')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('РИТМ И ТЕМП',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent, fontWeight: FontWeight.w800,
                      letterSpacing: 1.3)),
                  const SizedBox(height: 5),
                  Text('Настройте пульс композиции',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
                ],
              )),
              _MetronomeStatus(running: _running),
            ]),
            const SizedBox(height: 18),
            Text('Темп', style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(22),
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
                Text('$_bpm', style: theme.textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.w800, color: accent, fontSize: 68)),
                Text('BPM$signature', style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2)),
                const SizedBox(height: 14),
                Slider(
                  min: 30, max: 240, divisions: 210,
                  value: _bpm.toDouble(),
                  onChanged: _running ? null : (value) =>
                      setState(() => _bpm = value.round()),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  IconButton(
                    tooltip: 'Минус 1 BPM',
                    onPressed: _running || _bpm <= 30 ? null : () =>
                        setState(() => _bpm--),
                    icon: const Icon(Icons.remove_circle_outline_rounded)),
                  Text('30', style: theme.textTheme.labelSmall),
                  Text('240', style: theme.textTheme.labelSmall),
                  IconButton(
                    tooltip: 'Плюс 1 BPM',
                    onPressed: _running || _bpm >= 240 ? null : () =>
                        setState(() => _bpm++),
                    icon: const Icon(Icons.add_circle_outline_rounded)),
                ]),
              ]),
            ),
            const SizedBox(height: 24),
            _MetronomeSectionTitle(title: 'Музыкальный размер',
              subtitle: 'Выберите размер такта'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final item in _signatures)
                ChoiceChip(
                  label: Text('${item.$1}/${item.$2}'),
                  selected: item.$1 == _pattern.beatsPerBar &&
                      item.$2 == _pattern.denominator,
                  onSelected: _running ? null : (_) => _setSignature(item),
                ),
            ]),
            const SizedBox(height: 24),
            _MetronomeSectionTitle(title: 'Акценты по долям',
              subtitle: 'Коснитесь доли, чтобы включить или выключить акцент'),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              const spacing = 8.0;
              final columns = constraints.maxWidth >= 390 ? 7 : 6;
              final width = (constraints.maxWidth -
                  spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (var i = 0; i < _pattern.beatsPerBar; i++)
                    SizedBox(
                      width: width,
                      child: _BeatDot(
                        index: i,
                        active: _beat == i,
                        accented: _pattern.isAccented(i),
                        onTap: _running ? null : () => setState(() =>
                            _pattern = _pattern.toggleAccent(i)),
                      ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 26),
            FilledButton.icon(
              onPressed: _running ? _stop : _start,
              icon: Icon(_running ? Icons.stop_rounded : Icons.play_arrow_rounded),
              label: Text(_running ? 'Остановить' : 'Запустить метроном'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(58)),
            ),
            const SizedBox(height: 12),
            Text(_running
                ? 'Идёт отсчёт · доля ${_beat + 1} из ${_pattern.beatsPerBar}'
                : 'Готов к репетиции',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _BeatDot extends StatelessWidget {
  const _BeatDot({required this.index, required this.active,
    required this.accented, this.onTap});
  final int index;
  final bool active, accented;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Material(
      color: active ? color : accented
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 17),
          child: Column(children: [
            Text('${index + 1}', style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: active ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface)),
            const SizedBox(height: 5),
            Icon(accented ? Icons.volume_up_rounded : Icons.circle_outlined,
              size: 17,
              color: active ? theme.colorScheme.onPrimary :
                  accented ? color : theme.colorScheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}


class _MetronomeSectionTitle extends StatelessWidget {
  const _MetronomeSectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant)),
    ]);
  }
}

class _MetronomeStatus extends StatelessWidget {
  const _MetronomeStatus({required this.running});
  final bool running;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = running ? const Color(0xFF249B68) : theme.colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(running ? 'ИГРАЕТ' : 'ГОТОВ',
            style: theme.textTheme.labelSmall?.copyWith(color: color,
              fontWeight: FontWeight.w800, letterSpacing: .7)),
        ]),
      ),
    );
  }
}
