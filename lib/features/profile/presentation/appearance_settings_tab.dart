import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_appearance.dart';

class AppearanceSettingsTab extends ConsumerWidget {
  const AppearanceSettingsTab({super.key});

  static const _themes = <_ThemeOption>[
    _ThemeOption(value: AppThemeChoice.system, label: 'Как в системе', description: 'Автоматически', icon: Icons.brightness_auto_rounded),
    _ThemeOption(value: AppThemeChoice.light, label: 'Светлая', description: 'Светлый интерфейс', icon: Icons.light_mode_rounded),
    _ThemeOption(value: AppThemeChoice.dark, label: 'Тёмная', description: 'Мягкий тёмный фон', icon: Icons.dark_mode_rounded),
    _ThemeOption(value: AppThemeChoice.amoled, label: 'AMOLED', description: 'Чёрный фон', icon: Icons.contrast_rounded),
  ];

  static const _accents = <_AccentOption>[
    _AccentOption('Синий', 0xFF1554FF),
    _AccentOption('Фиолетовый', 0xFF7657FF),
    _AccentOption('Бирюзовый', 0xFF0B9B83),
    _AccentOption('Оранжевый', 0xFFE58A28),
    _AccentOption('Розовый', 0xFFE05D83),
    _AccentOption('Голубой', 0xFF12A6C7),
  ];

  static const _corners = <_CornerOption>[
    _CornerOption(AppCornerStyle.soft, 'Мягкие', 'Более округлые'),
    _CornerOption(AppCornerStyle.balanced, 'Стандартные', 'Умеренное скругление'),
    _CornerOption(AppCornerStyle.sharp, 'Строгие', 'Компактная форма'),
  ];

  Future<void> _apply(BuildContext context, WidgetRef ref, AppAppearance appearance) async {
    try {
      await ref.read(appAppearanceProvider.notifier).saveAppearance(appearance);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить настройки оформления.')),
      );
    }
  }

  Future<void> _chooseCustomAccent(
    BuildContext context,
    WidgetRef ref,
    AppAppearance appearance,
  ) async {
    final controller = TextEditingController(
      text: appearance.accentColor.value.toRadixString(16).substring(2).toUpperCase(),
    );
    try {
      final colorValue = await showDialog<int>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final raw = controller.text.trim().replaceFirst('#', '');
            final valid = raw.length == 6 &&
                RegExp(r'^[0-9a-fA-F]+').hasMatch(raw);
            final parsed = valid ? (0xFF000000 | int.parse(raw, radix: 16)) : null;
            return AlertDialog(
              title: const Text('Свой цвет элементов'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Введи HEX-код цвета. Он будет использоваться для кнопок и активных элементов.',
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'HEX',
                      prefixText: '#',
                      helperText: 'Например, 1554FF',
                      counterText: '',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: parsed == null
                              ? Theme.of(dialogContext).colorScheme.surfaceContainerHighest
                              : Color(parsed),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        valid ? '#' + raw.toUpperCase() : 'Проверь код цвета',
                        style: Theme.of(dialogContext).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: parsed == null
                      ? null
                      : () => Navigator.of(dialogContext).pop(parsed),
                  child: const Text('Применить'),
                ),
              ],
            );
          },
        ),
      );
      if (colorValue != null && context.mounted) {
        await _apply(
          context,
          ref,
          appearance.copyWith(accentColorValue: colorValue),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearanceState = ref.watch(appAppearanceProvider);

    return SafeArea(
      child: appearanceState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.palette_outlined, size: 38),
                const SizedBox(height: 12),
                const Text('Не удалось загрузить настройки оформления.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(appAppearanceProvider),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
        data: (appearance) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
          children: [
            Text('Внешний вид', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Настрой приложение под себя. Изменения применяются сразу и сохраняются на устройстве.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 26),
            const _SectionHeading(title: 'Тема приложения', subtitle: 'Выбери, как будет выглядеть BandPlan.'),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _themes.map((option) {
                    final selected = appearance.themeChoice == option.value;
                    return SizedBox(
                      width: width,
                      child: _ThemeChoiceCard(
                        option: option,
                        selected: selected,
                        onTap: () => _apply(context, ref, appearance.copyWith(themeChoice: option.value)),
                      ),
                    );
                  }).toList(growable: false),
                );
              },
            ),
            const SizedBox(height: 28),
            const _SectionHeading(title: 'Цвет элементов', subtitle: 'Цвет кнопок, активных вкладок и выделений.'),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                ..._accents.map((option) {
                  final selected = appearance.accentColorValue == option.colorValue;
                  return _AccentChoice(
                    option: option,
                    selected: selected,
                    onTap: () => _apply(context, ref, appearance.copyWith(accentColorValue: option.colorValue)),
                  );
                }),
                _CustomAccentChoice(
                  color: appearance.accentColor,
                  selected: !_accents.any((option) => option.colorValue == appearance.accentColorValue),
                  onTap: () => _chooseCustomAccent(context, ref, appearance),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const _SectionHeading(
              title: 'Форма отдельных элементов',
              subtitle: 'Меняй скругление карточек, кнопок и полей независимо друг от друга.',
            ),
            _ElementShapePicker(
              title: 'Карточки',
              selected: appearance.cardCornerStyle,
              options: _corners,
              onSelected: (value) => _apply(context, ref, appearance.copyWith(cardCornerStyle: value)),
            ),
            const SizedBox(height: 14),
            _ElementShapePicker(
              title: 'Кнопки',
              selected: appearance.buttonCornerStyle,
              options: _corners,
              onSelected: (value) => _apply(context, ref, appearance.copyWith(buttonCornerStyle: value)),
            ),
            const SizedBox(height: 14),
            _ElementShapePicker(
              title: 'Поля ввода',
              selected: appearance.fieldCornerStyle,
              options: _corners,
              onSelected: (value) => _apply(context, ref, appearance.copyWith(fieldCornerStyle: value)),
            ),
            const SizedBox(height: 28),
            const _SectionHeading(
              title: 'Глубина элементов',
              subtitle: 'Выбери, насколько выражен объём карточек и основных кнопок.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                (AppDepthStyle.soft, 'Мягкая'),
                (AppDepthStyle.balanced, 'Умеренная'),
                (AppDepthStyle.flat, 'Плоская'),
              ].map((option) => ChoiceChip(
                label: Text(option.$2),
                selected: appearance.depthStyle == option.$1,
                onSelected: (_) => _apply(
                  context,
                  ref,
                  appearance.copyWith(depthStyle: option.$1),
                ),
              )).toList(growable: false),
            ),
            const SizedBox(height: 28),
            const _SectionHeading(title: 'Плотность интерфейса', subtitle: 'Настрой размеры и расстояния между стандартными элементами.'),
            ...[
              (AppElementDensity.compact, 'Компактные', 'Больше элементов на экране', Icons.view_compact_alt_rounded),
              (AppElementDensity.standard, 'Обычные', 'Сбалансированные отступы', Icons.view_agenda_rounded),
              (AppElementDensity.comfortable, 'Свободные', 'Больше пространства', Icons.view_day_rounded),
            ].map((option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DensityChoice(
                title: option.$2,
                subtitle: option.$3,
                icon: option.$4,
                selected: appearance.elementDensity == option.$1,
                onTap: () => _apply(context, ref, appearance.copyWith(elementDensity: option.$1)),
              ),
            )),
            const SizedBox(height: 24),
            _AppearancePreview(appearance: appearance),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => _apply(context, ref, AppAppearance.defaults),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Сбросить настройки оформления'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(subtitle, style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ThemeChoiceCard extends StatelessWidget {
  const _ThemeChoiceCard({required this.option, required this.selected, required this.onTap});

  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highlight = Theme.of(context).brightness == Brightness.light
        ? Colors.white.withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.035);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : colors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: colors.shadow.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(3, 4)),
              BoxShadow(color: highlight, blurRadius: 10, offset: const Offset(-3, -3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(option.icon, color: selected ? colors.primary : colors.onSurfaceVariant),
                  const Spacer(),
                  if (selected) Icon(Icons.check_circle_rounded, color: colors.primary),
                ],
              ),
              const SizedBox(height: 14),
              Text(option.label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(option.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentChoice extends StatelessWidget {
  const _AccentChoice({required this.option, required this.selected, required this.onTap});

  final _AccentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(option.colorValue);
    return Tooltip(
      message: option.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Цвет ${option.label}',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: selected
                    ? [BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 12, spreadRadius: 2)]
                    : const [],
              ),
              child: selected ? const Icon(Icons.check_rounded, color: Colors.white) : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomAccentChoice extends StatelessWidget {
  const _CustomAccentChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Свой цвет',
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Выбрать собственный цвет элементов',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected ? color : colors.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? color : colors.outlineVariant,
                  width: selected ? 2 : 1,
                ),
                boxShadow: selected
                    ? [BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 12, spreadRadius: 2)]
                    : const [],
              ),
              child: Icon(
                selected ? Icons.check_rounded : Icons.colorize_rounded,
                color: selected ? Colors.white : colors.onSurfaceVariant,
                size: 19,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({required this.appearance});

  final AppAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = appearance.cardCornerRadius;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: appearance.depthElevation == 0
            ? const []
            : [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.10 * (appearance.depthElevation / 2)),
                  blurRadius: 12 * (appearance.depthElevation / 2),
                  offset: const Offset(3, 4),
                ),
                BoxShadow(
                  color: colors.surface.withValues(alpha: 0.75),
                  blurRadius: 10,
                  offset: const Offset(-3, -3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Предпросмотр элементов', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(radius * 0.8)),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(radius * 0.65)),
                  child: Icon(Icons.music_note_rounded, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Репетиция', style: Theme.of(context).textTheme.titleSmall),
                      Text('Сегодня · 19:00', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: appearance.accentColor,
                borderRadius: BorderRadius.circular(appearance.buttonCornerRadius),
              ),
              child: const Text(
                'Кнопка',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ElementShapePicker extends StatelessWidget {
  const _ElementShapePicker({
    required this.title,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String title;
  final AppCornerStyle selected;
  final List<_CornerOption> options;
  final ValueChanged<AppCornerStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) => Tooltip(
            message: option.description,
            child: ChoiceChip(
              label: Text(option.label),
              selected: selected == option.value,
              onSelected: (_) => onSelected(option.value),
            ),
          )).toList(growable: false),
        ),
      ],
    );
  }
}

class _ThemeOption {
  const _ThemeOption({required this.value, required this.label, required this.description, required this.icon});

  final AppThemeChoice value;
  final String label;
  final String description;
  final IconData icon;
}

class _AccentOption {
  const _AccentOption(this.label, this.colorValue);

  final String label;
  final int colorValue;
}

class _CornerOption {
  const _CornerOption(this.value, this.label, this.description);

  final AppCornerStyle value;
  final String label;
  final String description;
}

class _DensityChoice extends StatelessWidget {
  const _DensityChoice({required this.title, required this.subtitle, required this.icon, required this.selected, required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(children: [
            Icon(icon, color: selected ? colors.primary : colors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ])),
            if (selected) Icon(Icons.check_circle_rounded, color: colors.primary),
          ]),
        ),
      ),
    );
  }
}
).hasMatch(raw);
            final parsed = valid ? (0xFF000000 | int.parse(raw, radix: 16)) : null;
            return AlertDialog(
              title: const Text('Свой цвет элементов'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Введи HEX-код цвета. Он будет использоваться для кнопок и активных элементов.',
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    maxLength: 6,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'HEX',
                      prefixText: '#',
                      helperText: 'Например, 1554FF',
                      counterText: '',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: parsed == null
                              ? Theme.of(dialogContext).colorScheme.surfaceContainerHighest
                              : Color(parsed),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        valid ? '#${raw.toUpperCase()}' : 'Проверь код цвета',
                        style: Theme.of(dialogContext).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: parsed == null
                      ? null
                      : () => Navigator.of(dialogContext).pop(parsed),
                  child: const Text('Применить'),
                ),
              ],
            );
          },
        ),
      );
      if (colorValue != null && context.mounted) {
        await _apply(
          context,
          ref,
          appearance.copyWith(accentColorValue: colorValue),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearanceState = ref.watch(appAppearanceProvider);

    return SafeArea(
      child: appearanceState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.palette_outlined, size: 38),
                const SizedBox(height: 12),
                const Text('Не удалось загрузить настройки оформления.', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(appAppearanceProvider),
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        ),
        data: (appearance) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
          children: [
            Text('Внешний вид', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Настрой приложение под себя. Изменения применяются сразу и сохраняются на устройстве.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 26),
            const _SectionHeading(title: 'Тема приложения', subtitle: 'Выбери, как будет выглядеть BandPlan.'),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _themes.map((option) {
                    final selected = appearance.themeChoice == option.value;
                    return SizedBox(
                      width: width,
                      child: _ThemeChoiceCard(
                        option: option,
                        selected: selected,
                        onTap: () => _apply(context, ref, appearance.copyWith(themeChoice: option.value)),
                      ),
                    );
                  }).toList(growable: false),
                );
              },
            ),
            const SizedBox(height: 28),
            const _SectionHeading(title: 'Цвет элементов', subtitle: 'Цвет кнопок, активных вкладок и выделений.'),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: _accents.map((option) {
                final selected = appearance.accentColorValue == option.colorValue;
                return _AccentChoice(
                  option: option,
                  selected: selected,
                  onTap: () => _apply(context, ref, appearance.copyWith(accentColorValue: option.colorValue)),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 28),
            const _SectionHeading(
              title: 'Форма отдельных элементов',
              subtitle: 'Меняй скругление карточек, кнопок и полей независимо друг от друга.',
            ),
            _ElementShapePicker(
              title: 'Карточки',
              selected: appearance.cardCornerStyle,
              options: _corners,
              onSelected: (value) => _apply(context, ref, appearance.copyWith(cardCornerStyle: value)),
            ),
            const SizedBox(height: 14),
            _ElementShapePicker(
              title: 'Кнопки',
              selected: appearance.buttonCornerStyle,
              options: _corners,
              onSelected: (value) => _apply(context, ref, appearance.copyWith(buttonCornerStyle: value)),
            ),
            const SizedBox(height: 14),
            _ElementShapePicker(
              title: 'Поля ввода',
              selected: appearance.fieldCornerStyle,
              options: _corners,
              onSelected: (value) => _apply(context, ref, appearance.copyWith(fieldCornerStyle: value)),
            ),
            const SizedBox(height: 28),
            const _SectionHeading(
              title: 'Глубина элементов',
              subtitle: 'Выбери, насколько выражен объём карточек и основных кнопок.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                (AppDepthStyle.soft, 'Мягкая'),
                (AppDepthStyle.balanced, 'Умеренная'),
                (AppDepthStyle.flat, 'Плоская'),
              ].map((option) => ChoiceChip(
                label: Text(option.$2),
                selected: appearance.depthStyle == option.$1,
                onSelected: (_) => _apply(
                  context,
                  ref,
                  appearance.copyWith(depthStyle: option.$1),
                ),
              )).toList(growable: false),
            ),
            const SizedBox(height: 28),
            const _SectionHeading(title: 'Плотность интерфейса', subtitle: 'Настрой размеры и расстояния между стандартными элементами.'),
            ...[
              (AppElementDensity.compact, 'Компактные', 'Больше элементов на экране', Icons.view_compact_alt_rounded),
              (AppElementDensity.standard, 'Обычные', 'Сбалансированные отступы', Icons.view_agenda_rounded),
              (AppElementDensity.comfortable, 'Свободные', 'Больше пространства', Icons.view_day_rounded),
            ].map((option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DensityChoice(
                title: option.$2,
                subtitle: option.$3,
                icon: option.$4,
                selected: appearance.elementDensity == option.$1,
                onTap: () => _apply(context, ref, appearance.copyWith(elementDensity: option.$1)),
              ),
            )),
            const SizedBox(height: 24),
            _AppearancePreview(appearance: appearance),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => _apply(context, ref, AppAppearance.defaults),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Сбросить настройки оформления'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: textTheme.titleMedium),
          const SizedBox(height: 3),
          Text(subtitle, style: textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ThemeChoiceCard extends StatelessWidget {
  const _ThemeChoiceCard({required this.option, required this.selected, required this.onTap});

  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final highlight = Theme.of(context).brightness == Brightness.light
        ? Colors.white.withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.035);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : colors.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: colors.shadow.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(3, 4)),
              BoxShadow(color: highlight, blurRadius: 10, offset: const Offset(-3, -3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(option.icon, color: selected ? colors.primary : colors.onSurfaceVariant),
                  const Spacer(),
                  if (selected) Icon(Icons.check_circle_rounded, color: colors.primary),
                ],
              ),
              const SizedBox(height: 14),
              Text(option.label, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(option.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccentChoice extends StatelessWidget {
  const _AccentChoice({required this.option, required this.selected, required this.onTap});

  final _AccentOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(option.colorValue);
    return Tooltip(
      message: option.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: 'Цвет ${option.label}',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: selected
                    ? [BoxShadow(color: color.withValues(alpha: 0.32), blurRadius: 12, spreadRadius: 2)]
                    : const [],
              ),
              child: selected ? const Icon(Icons.check_rounded, color: Colors.white) : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({required this.appearance});

  final AppAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = appearance.cardCornerRadius;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: appearance.depthElevation == 0
            ? const []
            : [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.10 * (appearance.depthElevation / 2)),
                  blurRadius: 12 * (appearance.depthElevation / 2),
                  offset: const Offset(3, 4),
                ),
                BoxShadow(
                  color: colors.surface.withValues(alpha: 0.75),
                  blurRadius: 10,
                  offset: const Offset(-3, -3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Предпросмотр элементов', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(radius * 0.8)),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: BorderRadius.circular(radius * 0.65)),
                  child: Icon(Icons.music_note_rounded, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Репетиция', style: Theme.of(context).textTheme.titleSmall),
                      Text('Сегодня · 19:00', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: appearance.accentColor,
                borderRadius: BorderRadius.circular(appearance.buttonCornerRadius),
              ),
              child: const Text(
                'Кнопка',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ElementShapePicker extends StatelessWidget {
  const _ElementShapePicker({
    required this.title,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String title;
  final AppCornerStyle selected;
  final List<_CornerOption> options;
  final ValueChanged<AppCornerStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) => Tooltip(
            message: option.description,
            child: ChoiceChip(
              label: Text(option.label),
              selected: selected == option.value,
              onSelected: (_) => onSelected(option.value),
            ),
          )).toList(growable: false),
        ),
      ],
    );
  }
}

class _ThemeOption {
  const _ThemeOption({required this.value, required this.label, required this.description, required this.icon});

  final AppThemeChoice value;
  final String label;
  final String description;
  final IconData icon;
}

class _AccentOption {
  const _AccentOption(this.label, this.colorValue);

  final String label;
  final int colorValue;
}

class _CornerOption {
  const _CornerOption(this.value, this.label, this.description);

  final AppCornerStyle value;
  final String label;
  final String description;
}

class _DensityChoice extends StatelessWidget {
  const _DensityChoice({required this.title, required this.subtitle, required this.icon, required this.selected, required this.onTap});
  final String title, subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.primaryContainer : colors.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(children: [
            Icon(icon, color: selected ? colors.primary : colors.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ])),
            if (selected) Icon(Icons.check_circle_rounded, color: colors.primary),
          ]),
        ),
      ),
    );
  }
}
