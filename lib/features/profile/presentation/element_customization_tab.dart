import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_appearance.dart';
import '../../../core/theme/bandplan_theme.dart';

class ElementCustomizationTab extends ConsumerWidget {
  const ElementCustomizationTab({super.key});

  Future<void> _apply(BuildContext context, WidgetRef ref, AppAppearance appearance) async {
    try {
      await ref.read(appAppearanceProvider.notifier).saveAppearance(appearance);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить настройки элементов.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appAppearanceProvider);
    return SafeArea(
      child: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.tune_rounded, size: 38),
              const SizedBox(height: 12),
              const Text('Не удалось загрузить настройки элементов.', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => ref.invalidate(appAppearanceProvider), child: const Text('Повторить')),
            ]),
          ),
        ),
        data: (appearance) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
          children: [
            Text('Кастомизация элементов', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Настрой карточки, кнопки, поля и расстояния между элементами. Изменения применяются сразу.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45,
              ),
            ),
            const SizedBox(height: 26),
            const _ElementSectionHeading(title: 'Оттенок поверхностей', subtitle: 'Общий тон фона, карточек и полей. Акцентный цвет не меняется.'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              (AppSurfaceTone.neutral, 'Нейтральный'),
              (AppSurfaceTone.cool, 'Холодный'),
              (AppSurfaceTone.warm, 'Тёплый'),
            ].map((option) => ChoiceChip(
              label: Text(option.$2), selected: appearance.surfaceTone == option.$1,
              onSelected: (_) => _apply(context, ref, appearance.copyWith(surfaceTone: option.$1)),
            )).toList(growable: false)),
            const SizedBox(height: 28),
            const _ElementSectionHeading(title: 'Скругление элементов', subtitle: 'Отдельно настрой карточки, кнопки и поля ввода.'),
            _ElementShapePicker(title: 'Карточки', selected: appearance.cardCornerStyle,
              onSelected: (value) => _apply(context, ref, appearance.copyWith(cardCornerStyle: value))),
            const SizedBox(height: 14),
            _ElementShapePicker(title: 'Кнопки', selected: appearance.buttonCornerStyle,
              onSelected: (value) => _apply(context, ref, appearance.copyWith(buttonCornerStyle: value))),
            const SizedBox(height: 14),
            _ElementShapePicker(title: 'Поля ввода', selected: appearance.fieldCornerStyle,
              onSelected: (value) => _apply(context, ref, appearance.copyWith(fieldCornerStyle: value))),
            const SizedBox(height: 28),
            const _ElementSectionHeading(title: 'Глубина элементов', subtitle: 'Выбери выраженность объёма карточек и основных кнопок.'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              (AppDepthStyle.soft, 'Мягкая'),
              (AppDepthStyle.balanced, 'Умеренная'),
              (AppDepthStyle.flat, 'Плоская'),
            ].map((option) => ChoiceChip(
              label: Text(option.$2), selected: appearance.depthStyle == option.$1,
              onSelected: (_) => _apply(context, ref, appearance.copyWith(depthStyle: option.$1)),
            )).toList(growable: false)),
            const SizedBox(height: 28),
            const _ElementSectionHeading(title: 'Плотность интерфейса', subtitle: 'Выбери расстояния между стандартными элементами.'),
            ...[
              (AppElementDensity.compact, 'Компактная', 'Больше элементов на экране', Icons.view_compact_alt_rounded),
              (AppElementDensity.standard, 'Обычная', 'Сбалансированные отступы', Icons.view_agenda_rounded),
              (AppElementDensity.comfortable, 'Свободная', 'Больше пространства', Icons.view_day_rounded),
            ].map((option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DensityChoice(
                title: option.$2, subtitle: option.$3, icon: option.$4,
                selected: appearance.elementDensity == option.$1,
                onTap: () => _apply(context, ref, appearance.copyWith(elementDensity: option.$1)),
              ),
            )),
            const SizedBox(height: 20),
            _ElementPreview(appearance: appearance),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => _apply(context, ref, appearance.copyWith(
                  cardCornerStyle: AppCornerStyle.soft,
                  buttonCornerStyle: AppCornerStyle.soft,
                  fieldCornerStyle: AppCornerStyle.soft,
                  elementDensity: AppElementDensity.standard,
                  depthStyle: AppDepthStyle.soft,
                  surfaceTone: AppSurfaceTone.neutral,
                )),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Сбросить настройки элементов'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ElementSectionHeading extends StatelessWidget {
  const _ElementSectionHeading({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 3),
      Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      )),
    ]),
  );
}

class _ElementShapePicker extends StatelessWidget {
  const _ElementShapePicker({required this.title, required this.selected, required this.onSelected});
  final String title;
  final AppCornerStyle selected;
  final ValueChanged<AppCornerStyle> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        (AppCornerStyle.soft, 'Мягкое'),
        (AppCornerStyle.balanced, 'Среднее'),
        (AppCornerStyle.sharp, 'Строгое'),
      ].map((option) => ChoiceChip(
        label: Text(option.$2), selected: selected == option.$1,
        onSelected: (_) => onSelected(option.$1),
      )).toList(growable: false)),
    ],
  );
}

class _DensityChoice extends StatelessWidget {
  const _DensityChoice({required this.title, required this.subtitle, required this.icon, required this.selected, required this.onTap});
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.secondaryContainer : colors.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16), onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icon, color: selected ? colors.onSecondaryContainer : colors.onSurfaceVariant),
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

class _ElementPreview extends StatelessWidget {
  const _ElementPreview({required this.appearance});
  final AppAppearance appearance;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Предпросмотр', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.surfaceContainer,
              borderRadius: BorderRadius.circular(appearance.cardCornerRadius),
            ),
            child: const Text('Так будут выглядеть поверхности и карточки'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: null,
            style: FilledButton.styleFrom(shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(appearance.buttonCornerRadius),
            )),
            child: const Text('Пример кнопки'),
          ),
          const SizedBox(height: 12),
          TextField(
            readOnly: true,
            decoration: InputDecoration(
              hintText: 'Пример поля ввода',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(appearance.fieldCornerRadius)),
            ),
          ),
        ]),
      ),
    );
  }
}
