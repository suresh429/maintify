import 'package:flutter/material.dart';

/// Modern horizontally-scrollable pill filter bar.
/// Renders options as fully-rounded pills with smooth animated state transitions.
///
/// Selected  → solid [activeColor] background, white bold text, subtle shadow
/// Unselected → #E2E8F0 background, #475569 medium text, no shadow
class PillFilterBar extends StatelessWidget {
  final List<String> options;
  final String selected;
  final Color activeColor;
  final void Function(String) onChanged;

  /// Left/right padding of the scroll area.
  final EdgeInsetsGeometry padding;

  /// Gap between pills.
  final double gap;

  const PillFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.activeColor,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.gap = 8,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, __) => SizedBox(width: gap),
        itemBuilder: (_, i) {
          final opt = options[i];
          final isActive = opt == selected;
          return _PillItem(
            label: opt,
            isActive: isActive,
            activeColor: activeColor,
            onTap: () => onChanged(opt),
          );
        },
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _PillItem({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: isActive ? activeColor : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? const Color(0xFFFFFFFF) : const Color(0xFF475569),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
