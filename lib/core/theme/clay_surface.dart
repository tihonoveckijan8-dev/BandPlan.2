import 'package:flutter/material.dart';

import 'bandplan_theme.dart';

/// A tactile surface with balanced light and dark shadows instead of a flat card.
class ClaySurface extends StatelessWidget {
  const ClaySurface({
    super.key,
    required this.child,
    this.margin = EdgeInsets.zero,
    this.padding = EdgeInsets.zero,
    this.radius,
  });

  final Widget child;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final depth = theme.extension<BandPlanClayDepth>();
    final shape = theme.cardTheme.shape;
    final defaultRadius = shape is RoundedRectangleBorder
        ? shape.borderRadius.resolve(Directionality.of(context)).topLeft.x
        : 24.0;
    final cornerRadius = radius ?? defaultRadius;
    final borderRadius = BorderRadius.circular(cornerRadius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: depth?.surface ?? theme.colorScheme.surface,
        borderRadius: borderRadius,
        boxShadow: depth?.raisedShadows ?? const <BoxShadow>[],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          type: MaterialType.transparency,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
