import 'package:flutter/material.dart';

class ChordLibraryPage extends StatefulWidget {
  const ChordLibraryPage({super.key});
  @override
  State<ChordLibraryPage> createState() => _ChordLibraryPageState();
}

class _ChordLibraryPageState extends State<ChordLibraryPage> {
  static const chords = <_Chord>[
    _Chord('C', 'Мажор', ['C', 'E', 'G'], [null, 3, 2, 0, 1, 0]),
    _Chord('G', 'Мажор', ['G', 'B', 'D'], [3, 2, 0, 0, 0, 3]),
    _Chord('D', 'Мажор', ['D', 'F♯', 'A'], [null, null, 0, 2, 3, 2]),
    _Chord('A', 'Мажор', ['A', 'C♯', 'E'], [null, 0, 2, 2, 2, 0]),
    _Chord('E', 'Мажор', ['E', 'G♯', 'B'], [0, 2, 2, 1, 0, 0]),
    _Chord('F', 'Мажор', ['F', 'A', 'C'], [1, 3, 3, 2, 1, 1]),
    _Chord('Am', 'Минор', ['A', 'C', 'E'], [null, 0, 2, 2, 1, 0]),
    _Chord('Em', 'Минор', ['E', 'G', 'B'], [0, 2, 2, 0, 0, 0]),
    _Chord('Dm', 'Минор', ['D', 'F', 'A'], [null, null, 0, 2, 3, 1]),
    _Chord('Bm', 'Минор', ['B', 'D', 'F♯'], [null, 2, 4, 4, 3, 2], baseFret: 2),
  ];
  String filter = 'Все', search = '';
  String instrument = 'Гитара';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = chords.where((chord) =>
      (filter == 'Все' || chord.quality == filter) &&
      (chord.name.toLowerCase().contains(search.toLowerCase()) ||
       chord.notes.join(' ').toLowerCase().contains(search.toLowerCase()))).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Библиотека аккордов')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('АККОРДЫ И ГАРМОНИЯ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 7),
                Text('Найдите своё звучание',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800, letterSpacing: -.5)),
                const SizedBox(height: 5),
                Text('Аппликатуры и состав аккордов',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
              ],
            )),
            const SizedBox(width: 8),
            _ChordCount(count: visible.length),
          ]),
          const SizedBox(height: 18),
          TextField(
            decoration: InputDecoration(
              hintText: 'Найти аккорд или ноту',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(.45),
                  width: 1.2)),
            ),
            onChanged: (value) => setState(() => search = value.trim()),
          ),
          const SizedBox(height: 16),
          Text('Тип аккорда', style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in ['Все', 'Мажор', 'Минор'])
              ChoiceChip(label: Text(item), selected: filter == item,
                onSelected: (_) => setState(() => filter = item)),
          ]),
          const SizedBox(height: 14),
          Text('Инструмент', style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in ['Гитара', 'Клавишные'])
              ChoiceChip(label: Text(item), selected: instrument == item,
                onSelected: (_) => setState(() => instrument = item)),
          ]),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            const Padding(padding: EdgeInsets.all(28),
              child: Text('Аккорды не найдены', textAlign: TextAlign.center))
          else
            for (final chord in visible) ...[
              _ChordCard(chord: chord, showPiano: instrument == 'Клавишные'),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 8),
          Text('Схемы: слева направо от 6-й струны к 1-й. × — не играть, ○ — открытая струна.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Chord {
  const _Chord(this.name, this.quality, this.notes, this.frets, {this.baseFret = 1});
  final String name, quality;
  final List<String> notes;
  final List<int?> frets;
  final int baseFret;
}

class _ChordCard extends StatelessWidget {
  const _ChordCard({required this.chord, required this.showPiano});
  final _Chord chord;
  final bool showPiano;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: theme.colorScheme.shadow.withOpacity(
            theme.brightness == Brightness.dark ? .2 : .06),
            blurRadius: 18, offset: const Offset(0, 7)),
          BoxShadow(color: theme.colorScheme.surface.withOpacity(
            theme.brightness == Brightness.dark ? .16 : .86),
            blurRadius: 2, offset: const Offset(0, -1)),
        ],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(chord.name, style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.primary, fontWeight: FontWeight.w800,
            height: 1)),
          const SizedBox(height: 4),
          Text(chord.quality, style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Text('СОСТАВ АККОРДА',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800, letterSpacing: .8)),
          const SizedBox(height: 4),
          Text(chord.notes.join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600)),
        ])),
        const SizedBox(width: 10),
        showPiano ? _PianoDiagram(chord: chord) : _ChordDiagram(chord: chord),
      ]),
    );
  }
}

class _ChordDiagram extends StatelessWidget {
  const _ChordDiagram({required this.chord});
  final _Chord chord;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Аппликатура ' + chord.name,
      child: SizedBox(
        width: 126, height: 142,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            for (final fret in chord.frets)
              Text(fret == null ? '×' : fret == 0 ? '○' : '',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: fret == null ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant)),
          ]),
          Expanded(child: CustomPaint(
            painter: _DiagramPainter(
              frets: chord.frets, baseFret: chord.baseFret,
              lineColor: theme.colorScheme.onSurfaceVariant.withOpacity(.6),
              dotColor: theme.colorScheme.primary),
            child: const SizedBox.expand())),
          if (chord.baseFret > 1)
            Text('Лад ' + chord.baseFret.toString(),
              style: theme.textTheme.labelSmall),
        ]),
      ),
    );
  }
}

class _DiagramPainter extends CustomPainter {
  const _DiagramPainter({required this.frets, required this.baseFret,
    required this.lineColor, required this.dotColor});
  final List<int?> frets;
  final int baseFret;
  final Color lineColor, dotColor;
  @override
  void paint(Canvas canvas, Size size) {
    const left = 7.0, top = 3.0;
    final width = size.width - 14, height = size.height - 6;
    final sx = width / 5, fy = height / 4;
    final line = Paint()..color = lineColor..strokeWidth = 1.2;
    for (var i = 0; i < 6; i++) {
      final x = left + i * sx;
      canvas.drawLine(Offset(x, top), Offset(x, top + height), line);
    }
    for (var i = 0; i <= 4; i++) {
      final y = top + i * fy;
      final p = Paint()..color = lineColor
        ..strokeWidth = i == 0 && baseFret == 1 ? 3 : 1.2;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), p);
    }
    final dot = Paint()..color = dotColor;
    for (var i = 0; i < frets.length; i++) {
      final fret = frets[i];
      if (fret == null || fret == 0) continue;
      final row = fret - baseFret;
      if (row < 0 || row >= 4) continue;
      canvas.drawCircle(Offset(left + i * sx, top + (row + .5) * fy),
        5.5, dot);
    }
  }
  @override
  bool shouldRepaint(covariant _DiagramPainter old) =>
    old.frets != frets || old.baseFret != baseFret ||
    old.lineColor != lineColor || old.dotColor != dotColor;
}


class _PianoDiagram extends StatelessWidget {
  const _PianoDiagram({required this.chord});
  final _Chord chord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Клавиши аккорда ' + chord.name,
      child: SizedBox(
        width: 126,
        height: 142,
        child: Column(children: [
          Text('Клавиши', style: theme.textTheme.labelSmall),
          Expanded(child: CustomPaint(
            painter: _PianoPainter(
              notes: chord.notes.toSet(),
              whiteColor: theme.colorScheme.surface,
              blackColor: theme.colorScheme.onSurface,
              activeColor: theme.colorScheme.primary,
              lineColor: theme.colorScheme.outlineVariant,
            ),
            child: const SizedBox.expand(),
          )),
          Text('C · D · E · F · G · A · B',
            style: theme.textTheme.labelSmall?.copyWith(fontSize: 8)),
        ]),
      ),
    );
  }
}

class _PianoPainter extends CustomPainter {
  const _PianoPainter({
    required this.notes,
    required this.whiteColor,
    required this.blackColor,
    required this.activeColor,
    required this.lineColor,
  });

  final Set<String> notes;
  final Color whiteColor, blackColor, activeColor, lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    const whiteNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    const blackNotes = ['C♯', 'D♯', '', 'F♯', 'G♯', 'A♯'];
    final whiteWidth = size.width / 7;
    final whitePaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < whiteNotes.length; i++) {
      whitePaint.color = notes.contains(whiteNotes[i]) ? activeColor : whiteColor;
      final rect = Rect.fromLTWH(i * whiteWidth, 0, whiteWidth, size.height);
      canvas.drawRect(rect, whitePaint);
      canvas.drawRect(rect, borderPaint);
    }

    final blackWidth = whiteWidth * .56;
    final blackHeight = size.height * .62;
    final blackPaint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < blackNotes.length; i++) {
      if (blackNotes[i].isEmpty) continue;
      final left = (i + 1) * whiteWidth - blackWidth / 2;
      final rect = Rect.fromLTWH(left, 0, blackWidth, blackHeight);
      blackPaint.color = notes.contains(blackNotes[i]) ? activeColor : blackColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        blackPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PianoPainter old) =>
      old.notes != notes ||
      old.whiteColor != whiteColor ||
      old.blackColor != blackColor ||
      old.activeColor != activeColor ||
      old.lineColor != lineColor;
}


class _ChordCount extends StatelessWidget {
  const _ChordCount({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(.09),
        borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        child: Column(children: [
          Text('$count', style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary, fontWeight: FontWeight.w800,
            height: 1)),
          const SizedBox(height: 3),
          Text('НАЙДЕНО', style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary, fontSize: 8,
            fontWeight: FontWeight.w800, letterSpacing: .5)),
        ]),
      ),
    );
  }
}
