import 'package:flutter/material.dart';

import '../core/theme/bandplan_theme.dart';
import 'router.dart';

class BandPlanApp extends StatelessWidget {
  const BandPlanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'BandPlan',
      debugShowCheckedModeBanner: false,
      theme: BandPlanTheme.light(),
      darkTheme: BandPlanTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: bandPlanRouter,
    );
  }
}
