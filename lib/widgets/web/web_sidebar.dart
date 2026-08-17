import 'package:flutter/material.dart';
import '../../core/theme/role_theme.dart';
import '../maintify_logo.dart';

/// A navigation item for the web sidebar.
class WebNavItem {
  final IconData icon;
  final String label;

  const WebNavItem({required this.icon, required this.label});
}

/// Professional dark sidebar for desktop web layout.
///
/// Background is always [Color(0xFF0A0F1C)] regardless of app theme.
/// Width toggles between 240px (expanded) and 68px (icon-only, collapsed).
class WebSidebar extends StatefulWidget {
  final UserRole role;
  final List<WebNavItem> navItems;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onLogout;

  const WebSidebar({
    super.key,
    required this.role,
    required this.navItems,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.expanded,
    required this.onToggle,
    required this.onLogout,
  });

  @override
  State<WebSidebar> createState() => _WebSidebarState();
}

class _WebSidebarState extends State<WebSidebar> {
  int? _hoveredIndex;

  static const _bgColor = Color(0xFF0A0F1C);
  static const _dividerColor = Color(0xFF1E293B);

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(widget.role);
    final roleColor = theme.darkPrimary; // Always use the lighter variant on dark bg

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: widget.expanded ? 240 : 68,
      decoration: const BoxDecoration(
        color: _bgColor,
        border: Border(
          right: BorderSide(color: Color(0xFF1A2035), width: 1),
        ),
      ),
      child: Column(
        children: [
          // ── Logo section ────────────────────────────────────────────────
          _buildLogoSection(roleColor),

          // ── Nav items ───────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.navItems.length,
              itemBuilder: (_, i) => _buildNavItem(i, roleColor),
            ),
          ),

          // ── Bottom: divider + logout ─────────────────────────────────────
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildLogoSection(Color roleColor) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
      ),
      child: widget.expanded
          ? Row(
              children: [
                const MaintifyLogo(size: 40, backgroundOpacity: 0.18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Maintify',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Smart Living',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: const MaintifyLogo(size: 40, backgroundOpacity: 0.18),
            ),
    );
  }

  Widget _buildNavItem(int index, Color roleColor) {
    final item = widget.navItems[index];
    final isActive = widget.currentIndex == index;
    final isHovered = _hoveredIndex == index;

    Color bgColor = Colors.transparent;
    if (isActive) {
      bgColor = roleColor.withValues(alpha: 0.15);
    } else if (isHovered) {
      bgColor = Colors.white.withValues(alpha: 0.05);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: GestureDetector(
        onTap: () => widget.onIndexChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border(
                    left: BorderSide(color: roleColor, width: 3),
                  )
                : null,
          ),
          child: widget.expanded
              ? Row(
                  children: [
                    SizedBox(
                      width: isActive ? 13 : 16,
                      // account for active left border
                    ),
                    Icon(
                      item.icon,
                      size: 24,
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Icon(
                    item.icon,
                    size: 24,
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(color: _dividerColor, height: 1),
        const SizedBox(height: 8),
        // Logout item
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onLogout,
            child: Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: widget.expanded
                  ? Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(Icons.logout_rounded,
                            size: 22,
                            color: Colors.red[400]),
                        const SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.red[400],
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Icon(Icons.logout_rounded,
                          size: 22, color: Colors.red[400]),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
