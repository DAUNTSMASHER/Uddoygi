import 'package:flutter/material.dart';
import '../core/design_system.dart';

class UButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final IconData? icon;
  final double? width;
  final bool isFullWidth;

  const UButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.icon,
    this.width,
    this.isFullWidth = false,
  });

  @override
  State<UButton> createState() => _UButtonState();
}

class _UButtonState extends State<UButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.backgroundColor ?? theme.colorScheme.primary;
    final onPrimaryColor = widget.foregroundColor ?? theme.colorScheme.onPrimary;

    Widget buttonChild = widget.isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: onPrimaryColor,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 20, color: onPrimaryColor),
                const SizedBox(width: 10),
              ],
              Text(
                widget.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: onPrimaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          );

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SizedBox(
          width: widget.isFullWidth ? double.infinity : widget.width,
          height: 52,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: onPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: UddoygiDesign.borderM,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              elevation: 0,
            ).copyWith(
              overlayColor: WidgetStateProperty.all(onPrimaryColor.withOpacity(0.1)),
            ),
            child: buttonChild,
          ),
        ),
      ),
    );
  }
}
