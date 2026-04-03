import 'package:flutter/material.dart';
import '../../../config/app_theme.dart';

class DashboardHoverCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;

  const DashboardHoverCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.width,
    this.height,
  });

  @override
  State<DashboardHoverCard> createState() => _DashboardHoverCardState();
}

class _DashboardHoverCardState extends State<DashboardHoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        width: widget.width,
        height: widget.height,
        padding: widget.padding,
        transform: Matrix4.diagonal3Values(_isHovered ? 1.015 : 1.0, _isHovered ? 1.015 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isHovered ? AppColors.accentCyan.withValues(alpha: 0.5) : AppColors.panelBorder,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered ? AppColors.hoverGlow : Colors.transparent,
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: widget.child,
      ),
    );
  }
}
