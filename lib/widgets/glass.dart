import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Lightweight glass surface — uses translucent fill + border.
/// Optional blur for small regions only (performance-safe on mid-range).
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final bool blur;
  final Color? fill;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppRadii.md,
    this.blur = false,
    this.fill,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final body = Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: fill ?? AppColors.glassFillStrong,
        border: Border.all(color: AppColors.glassBorder, width: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.glassHighlight,
            (fill ?? AppColors.glassFillStrong),
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: onTap == null
            ? Padding(padding: padding ?? EdgeInsets.zero, child: child)
            : InkWell(
                borderRadius: BorderRadius.circular(radius),
                onTap: onTap,
                child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
              ),
      ),
    );

    if (!blur) return body;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: body,
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool highlight;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      padding: padding,
      onTap: onTap,
      fill: highlight
          ? AppColors.softGold.withOpacity(0.12)
          : AppColors.glassFillStrong,
      child: child,
    );
  }
}

class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;

  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.softGold,
        side: const BorderSide(color: AppColors.glassBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    );
  }
}

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: AppRadii.sm,
      padding: const EdgeInsets.all(10),
      onTap: onPressed,
      child: Icon(icon, color: AppColors.softGold, size: 20),
    );
  }
}

/// Floating liquid-glass bottom navigation.
class GlassNavigationBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const GlassNavigationBar({
    super.key,
    required this.index,
    required this.onChanged,
  });

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.schedule_rounded, 'Schedule'),
    (Icons.call_rounded, 'Calls'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom > 0 ? bottom : 16),
      child: GlassContainer(
        radius: AppRadii.pill,
        blur: true,
        fill: const Color(0xCC121C2B),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: List.generate(_items.length, (i) {
            final selected = i == index;
            final item = _items[i];
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    color: selected
                        ? AppColors.softGold.withOpacity(0.18)
                        : Colors.transparent,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedScale(
                        scale: selected ? 1.08 : 1.0,
                        duration: const Duration(milliseconds: 240),
                        child: Icon(
                          item.$1,
                          size: 22,
                          color: selected
                              ? AppColors.softGold
                              : AppColors.mutedGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected
                              ? AppColors.softGold
                              : AppColors.mutedGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
