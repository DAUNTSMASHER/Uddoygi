import 'package:flutter/material.dart';
import '../core/design_system.dart';

class UCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final double? width;
  final double? height;
  final bool showShadow;
  final bool isGlass;
  final double? opacity;
  final Border? border;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;

  const UCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.width,
    this.height,
    this.showShadow = true,
    this.isGlass = false,
    this.opacity,
    this.border,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (isGlass) {
      return Container(
        width: width,
        height: height,
        margin: margin,
        decoration: UddoygiDesign.glass(
          color: color ?? theme.colorScheme.surface,
          opacity: opacity ?? 0.1,
          radius: borderRadius,
          border: border,
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(UddoygiDesign.space16),
          child: child,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: borderRadius ?? UddoygiDesign.borderM,
        border: border ?? Border.all(color: theme.colorScheme.primary.withOpacity(0.05)),
        boxShadow: showShadow ? UddoygiDesign.shadowSoft : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? UddoygiDesign.borderM,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(UddoygiDesign.space16),
            child: child,
          ),
        ),
      ),
    );
  }
}
