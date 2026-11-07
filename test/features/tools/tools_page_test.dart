import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/tools/presentation/metronome_page.dart';
import 'package:bandplan/features/tools/presentation/tools_page.dart';

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
