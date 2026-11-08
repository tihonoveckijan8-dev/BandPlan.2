import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bandplan/features/tools/presentation/chord_library_page.dart';
import 'package:bandplan/features/tools/presentation/guitar_tuner_page.dart';
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

  testWidgets('metronome controls fit a phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1554FF))),
      home: const MetronomePage(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('РИТМ И ТЕМП'), findsOneWidget);
    // WHY: The ListView lazily builds lower sections only after scrolling.
    await tester.scrollUntilVisible(
      find.text('Акценты по долям'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Музыкальный размер'), findsOneWidget);
    expect(find.text('Акценты по долям'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Запустить метроном'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Запустить метроном'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('metronome tempo presets update the BPM display',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1554FF))),
      home: const MetronomePage(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('metronome-tempo-120')));
    await tester.pumpAndSettle();

    expect(find.text('120'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('metronome beat controls keep touch targets on compact phones',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1554FF))),
      home: const MetronomePage(),
    ));
    await tester.pumpAndSettle();

    // WHY: The metronome lives in a lazy ListView, so scroll its beat grid
    // into the tree before checking the compact touch targets.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('metronome-beat-0')),
      180,
      scrollable: find.byType(Scrollable).first,
    );

    for (var beat = 0; beat < 4; beat++) {
      final tile = find.byKey(ValueKey('metronome-beat-$beat'));
      expect(tile, findsOneWidget);
      expect(tester.getSize(tile).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('metronome time-signature chips keep touch targets on compact phones',
      (tester) async {
    for (final width in [320.0, 360.0]) {
      await tester.binding.setSurfaceSize(Size(width, 640));
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1554FF))),
        home: const MetronomePage(),
      ));
      await tester.pumpAndSettle();

      // WHY: Scroll the lazy list to measure the actual interactive chip bounds.
      final firstSignature =
          find.byKey(const ValueKey('metronome-signature-2-4'));
      await tester.scrollUntilVisible(
        firstSignature,
        180,
        scrollable: find.byType(Scrollable).first,
      );

      for (final signature in [
        '2-4', '3-4', '4-4', '5-4', '6-8', '9-8', '12-8',
      ]) {
        final chip = find.byKey(ValueKey('metronome-signature-$signature'));
        expect(chip, findsOneWidget);
        expect(tester.getSize(chip).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('chord library filters and renders on a phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1554FF))),
      home: const ChordLibraryPage(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Найдите своё звучание'), findsOneWidget);
    expect(find.text('Тип аккорда'), findsOneWidget);
    expect(find.text('Инструмент'), findsOneWidget);
    expect(find.text('C'), findsWidgets);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Минор'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Am'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Am'), findsOneWidget);
    expect(find.text('C'), findsNothing);
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

  testWidgets('tools workshop adapts to a wide dark-theme viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1554FF),
          brightness: Brightness.dark,
        ),
      ),
      home: const ToolsPage(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Рабочие инструменты'), findsOneWidget);
    expect(find.text('4 инструмента'), findsOneWidget);
    expect(find.text('Гитарный тюнер'), findsOneWidget);
    expect(find.text('Скрипичный тюнер'), findsOneWidget);
    expect(find.text('Метроном'), findsOneWidget);
    expect(find.text('Библиотека аккордов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all tool screens render in a dark phone theme',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1554FF),
        brightness: Brightness.dark,
      ),
    );
    final pages = <Widget>[
      const GuitarTunerPage(),
      const ViolinTunerPage(),
      const MetronomePage(),
      const ChordLibraryPage(),
    ];

    for (final page in pages) {
      await tester.pumpWidget(MaterialApp(theme: darkTheme, home: page));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });


  testWidgets('tools workshop adapts to a tablet-width viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1554FF),
          brightness: Brightness.light,
        ),
      ),
      home: const ToolsPage(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Рабочие инструменты'), findsOneWidget);
    expect(find.text('Гитарный тюнер'), findsOneWidget);
    expect(find.text('Скрипичный тюнер'), findsOneWidget);
    expect(find.text('Метроном'), findsOneWidget);
    expect(find.text('Библиотека аккордов'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all tool screens render in a light phone theme',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1554FF),
        brightness: Brightness.light,
      ),
    );
    final pages = <Widget>[
      const GuitarTunerPage(),
      const ViolinTunerPage(),
      const MetronomePage(),
      const ChordLibraryPage(),
    ];

    for (final page in pages) {
      await tester.pumpWidget(MaterialApp(theme: lightTheme, home: page));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });


  testWidgets('guitar string selectors keep comfortable touch width on compact phones',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1554FF)),
      ),
      home: const GuitarTunerPage(),
    ));
    await tester.pumpAndSettle();

    for (final stringNumber in ['6', '5', '4', '3', '2', '1']) {
      final selector = find.ancestor(
        of: find.text(stringNumber),
        matching: find.byType(InkWell),
      ).first;
      expect(tester.getSize(selector).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(selector).height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('violin string selectors keep touch targets on compact phones',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1554FF)),
      ),
      home: const ViolinTunerPage(),
    ));
    await tester.pumpAndSettle();

    for (final note in ['G', 'D', 'A', 'E']) {
      final selector = find.ancestor(
        of: find.text(note),
        matching: find.byType(InkWell),
      ).first;
      expect(tester.getSize(selector).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(selector).height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('chord cards stack diagrams on compact phone screens',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1554FF)),
      ),
      home: const ChordLibraryPage(),
    ));
    await tester.pumpAndSettle();

    final diagram = find.byKey(const ValueKey('chord-diagram-C'));
    await tester.scrollUntilVisible(
      diagram,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    final notesHeading = find.text('СОСТАВ АККОРДА').first;
    expect(tester.getRect(diagram).top,
        greaterThan(tester.getRect(notesHeading).top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('all tool screens remain usable at a compact phone width',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1554FF)),
    );
    final pages = <Widget>[
      const ToolsPage(),
      const GuitarTunerPage(),
      const ViolinTunerPage(),
      const MetronomePage(),
      const ChordLibraryPage(),
    ];

    for (final page in pages) {
      await tester.pumpWidget(MaterialApp(theme: theme, home: page));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

}
