import 'package:flutter/material.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_colors.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;
  final double? width;

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.gradient,
    this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        // FIX: mainAxisSize.min — the Column wraps its children instead of
        // expanding to fill whatever height the parent offers.  Previously
        // MainAxisSize.max caused unbounded-height assertions when the card
        // sat inside a scrollable column with no fixed height.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white54,
                    size: 14,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // FIX: Text widgets that carry dynamic content (currency amounts,
            // long labels) now clamp to a single line with ellipsis so they
            // never push the Column taller than the card's painted area.
            Text(
              value,
              style: AppTextStyles.heading2(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: AppTextStyles.bodySmall(
                  color: Colors.white.withOpacity(0.85)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: AppTextStyles.caption(
                    color: Colors.white.withOpacity(0.7)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Vertical padding reduced (12→9) to reclaim 6 px of inner height.
        // Horizontal padding kept at 14 to preserve the visual breathing room.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          // GridView cells carry a TIGHT height constraint (both min and max
          // equal the cell height).  mainAxisSize.max fills that space;
          // mainAxisAlignment.center then vertically centres the content
          // within it, giving natural padding above and below regardless of
          // device size.  This is the correct pattern for fixed-height parents.
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon pill: padding reduced 7→6, icon size 18→16.
            // Saves 2 px in height (14→12 for top+bottom padding).
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 8), // was 10 — saves 2 px
            // FittedBox scales the value text DOWN when the cell is too
            // narrow/shallow (e.g. accessibility large-text mode, iPad split
            // view, iPhone SE).  It never scales UP, so the design stays sharp
            // on large screens.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppTextStyles.heading3(color: AppColors.textPrimary),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: AppTextStyles.bodySmall(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
