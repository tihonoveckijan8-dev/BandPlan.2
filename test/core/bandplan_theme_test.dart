import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/theme/bandplan_theme.dart';

void main() {
  test('soft-clay theme exposes two opposing surface shadows', () {
    final theme = BandPlanTheme.light();
    final depth = theme.extension<BandPlanClayDepth>();

    expect(depth, isNotNull);
    expect(depth!.raisedShadows, hasLength(2));
    expect(theme.cardTheme.elevation, greaterThan(0));
  });

  test('flat depth preference removes decorative surface shadows', () {
    final theme = BandPlanTheme.light(depthElevation: 0);
    final depth = theme.extension<BandPlanClayDepth>();

    expect(depth, isNotNull);
    expect(depth!.raisedShadows, isEmpty);
  });

  test('dark and AMOLED themes keep the same clay depth contract', () {
    for (final theme in [
      BandPlanTheme.dark(),
      BandPlanTheme.amoled(),
    ]) {
      final depth = theme.extension<BandPlanClayDepth>();
      expect(depth, isNotNull);
      expect(depth!.raisedShadows, hasLength(2));
    }
  });
}
