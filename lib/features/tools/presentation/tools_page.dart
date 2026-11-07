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
    return Scaffold(
      appBar: AppBar(title: const Text('Инструменты')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Музыкальная мастерская',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('Инструменты для репетиций и подготовки к выступлению.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 22),
          _ToolCard(icon: Icons.tune_rounded, title: 'Гитарный тюнер',
            subtitle: 'Точная настройка по микрофону',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const GuitarTunerPage()))),
          const SizedBox(height: 12),
          _ToolCard(icon: Icons.music_note_rounded, title: 'Скрипичный тюнер',
            subtitle: 'G3 · D4 · A4 · E5',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const ViolinTunerPage()))),
          const SizedBox(height: 12),
          _ToolCard(icon: Icons.speed_rounded, title: 'Метроном',
            subtitle: 'Темп, размер, доли и акценты',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const MetronomePage()))),
          const SizedBox(height: 12),
          _ToolCard(icon: Icons.piano_rounded, title: 'Библиотека аккордов',
            subtitle: 'Гитарные аппликатуры и ноты',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const ChordLibraryPage())),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.icon, required this.title,
    required this.subtitle, required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(
                color: accent.withOpacity(.12),
                borderRadius: BorderRadius.circular(17)),
              child: Icon(icon, size: 28, color: accent)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant)),
              ])),
            Icon(Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}
