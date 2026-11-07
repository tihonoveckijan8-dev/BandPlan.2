import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    await tester.ensureVisible(metronome);
    await tester.tap(metronome);
    await tester.pumpAndSettle();

    expect(find.text('Запустить метроном'), findsOneWidget);
    expect(find.text('Музыкальный размер'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
