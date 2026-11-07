import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/tools/presentation/metronome_page.dart';
import 'package:bandplan/features/tools/presentation/tools_page.dart';
import 'package:bandplan/features/tools/presentation/violin_tuner_page.dart';

void main() {
  testWidgets('tools workshop fits a phone viewport and shows all tools',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1554FF)),
        ),
        home: const ToolsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Звучать точнее.\nИграть увереннее.'), findsOneWidget);
    expect(find.text('Гитарный тюнер'), findsOneWidget);
    expect(find.text('Скрипичный тюнер'), findsOneWidget);
    expect(find.text('Метроном'), findsOneWidget);
    expect(find.text('Библиотека аккордов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets('violin tuner uses the shared tuner layout on a phone',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1554FF)),
        ),
        home: const ViolinTunerPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Стандартный строй'), findsOneWidget);
    expect(find.text('G3 · D4 · A4 · E5'), findsOneWidget);
    expect(find.byType(SegmentedButton<bool>), findsOneWidget);
    expect(find.text('Автоопределение'), findsOneWidget);
    expect(find.text('Вручную'), findsOneWidget);
    expect(find.text('Начать настройку'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('metronome card opens the existing metronome screen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1554FF)),
        ),
        home: const ToolsPage(),
      ),
    );

    final metronome = find.text('Метроном');
    final metronomeCard = find.ancestor(
      of: metronome,
      matching: find.byType(InkWell),
    ).first;
    await tester.ensureVisible(metronomeCard);
    await tester.tap(metronomeCard);
    await tester.pumpAndSettle();

    expect(find.byType(MetronomePage), findsOneWidget);
    expect(find.text('Метроном'), findsOneWidget);
    expect(find.text('Темп'), findsOneWidget);

    // WHY: ListView builds lower controls lazily, so scroll before asserting
    // the start button exists in the rendered viewport.
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Запустить метроном'), findsOneWidget);
    expect(find.text('Музыкальный размер'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
