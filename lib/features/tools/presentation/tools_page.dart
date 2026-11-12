import 'package:flutter/material.dart';

import 'chord_library_page.dart';
import 'guitar_tuner_page.dart';
import 'metronome_page.dart';
import 'violin_tuner_page.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Инструменты'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1100;
          final horizontalPadding = isDesktop ? 32.0 : (constraints.maxWidth >= 720 ? 28.0 : 18.0);
          final columns = isDesktop ? 4 : constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 340 ? 2 : 1;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              8,
              horizontalPadding,
              32,
            ),
            children: [
              _WorkshopHeader(compact: isDesktop),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Рабочие инструменты',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(.09),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      child: Text(
                        '4 инструмента',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: columns,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: columns == 1 ? 1.8 : (isDesktop ? 1.48 : 0.92),
                children: [
                  _ToolTile(
                    icon: Icons.graphic_eq_rounded,
                    title: 'Гитарный тюнер',
                    subtitle: 'Настройка по микрофону',
                    accent: colors.primary,
                    compact: isDesktop,
                    onTap: () => _open(context, const GuitarTunerPage()),
                  ),
                  _ToolTile(
                    icon: Icons.music_note_rounded,
                    title: 'Скрипичный тюнер',
                    subtitle: 'G3 · D4 · A4 · E5',
                    accent: const Color(0xFF249B68),
                    compact: isDesktop,
                    onTap: () => _open(context, const ViolinTunerPage()),
                  ),
                  _ToolTile(
                    icon: Icons.speed_rounded,
                    title: 'Метроном',
                    subtitle: 'Темп, размер и акценты',
                    accent: const Color(0xFFE39A32),
                    compact: isDesktop,
                    onTap: () => _open(context, const MetronomePage()),
                  ),
                  _ToolTile(
                    icon: Icons.piano_rounded,
                    title: 'Библиотека аккордов',
                    subtitle: 'Аппликатуры и ноты',
                    accent: const Color(0xFF8A68D8),
                    compact: isDesktop,
                    onTap: () => _open(context, const ChordLibraryPage()),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _PracticeHint(),
            ],
          );
        },
      ),
    );
  }

  // WHY: Keep tool routes centralized so this visual refresh does not change
  // the existing navigation behavior or the individual tool implementations.
  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }
}

class _WorkshopHeader extends StatelessWidget {
  const _WorkshopHeader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(compact ? 26 : 22, compact ? 17 : 22, 18, compact ? 16 : 20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withOpacity(dark ? .24 : .09),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
          BoxShadow(
            color: colors.surface.withOpacity(dark ? .22 : .95),
            blurRadius: 2,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -2,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: CustomPaint(
                size: const Size(116, 104),
                painter: _SoundWavePainter(
                  color: colors.primary.withOpacity(.12),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 17,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'BANDPLAN WORKSHOP',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.25,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 13),
              Text(
                'Звучать точнее.\nИграть увереннее.',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                  letterSpacing: -0.7,
                ),
              ),
              SizedBox(height: compact ? 5 : 9),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Text(
                  'Всё необходимое для настройки и подготовки к репетиции — в одном месте.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
              SizedBox(height: compact ? 10 : 17),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SoundChip(label: 'TUNER'),
                  const SizedBox(width: 7),
                  _SoundChip(label: 'TEMPO'),
                  const SizedBox(width: 7),
                  _SoundChip(label: 'CHORDS'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoundChip extends StatelessWidget {
  const _SoundChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 9,
                letterSpacing: .8,
                fontWeight: FontWeight.w800,
                color: colors.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    this.compact = false,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final bool compact;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: EdgeInsets.all(compact ? 18 : 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withOpacity(dark ? .17 : .055),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: colors.surface.withOpacity(dark ? .16 : .8),
                blurRadius: 1,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(.13),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: accent, size: 23),
                      ),
                      const Spacer(),
                      Icon(Icons.north_east_rounded, size: 18,
                        color: colors.onSurfaceVariant.withOpacity(.7)),
                    ]),
                    const SizedBox(height: 18),
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800, letterSpacing: -.25)),
                    const SizedBox(height: 5),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant)),
                    const Spacer(),
                    Row(children: [
                      Text('Открыть инструмент',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 15, color: accent),
                    ]),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(.12),
                          borderRadius: BorderRadius.circular(16)),
                        child: Icon(icon, color: accent, size: 26)),
                      const Spacer(),
                      Icon(Icons.arrow_outward_rounded, size: 18,
                        color: colors.onSurfaceVariant.withOpacity(.65)),
                    ]),
                    const SizedBox(height: 14),
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800, height: 1.2)),
                    const SizedBox(height: 5),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant, height: 1.3)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PracticeHint extends StatelessWidget {
  const _PracticeHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates_outlined, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Совет: настрой инструмент перед началом репетиции.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurface,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundWavePainter extends CustomPainter {
  const _SoundWavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const heights = [18.0, 32.0, 48.0, 27.0, 58.0, 39.0, 22.0];
    for (var i = 0; i < heights.length; i++) {
      final x = 10.0 + i * 15.0;
      final center = size.height / 2;
      canvas.drawLine(
        Offset(x, center - heights[i] / 2),
        Offset(x, center + heights[i] / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SoundWavePainter oldDelegate) =>
      oldDelegate.color != color;
}
