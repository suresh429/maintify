import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/role_theme.dart';
import '../../core/utils/web_navigator.dart'
    if (dart.library.html) '../../core/utils/web_navigator_web.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../logout_sheet.dart';
import '../../screens/shared/notifications_screen.dart';

/// 64px top bar for the desktop web shell.
class WebTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final UserRole role;
  final VoidCallback onToggleSidebar;

  const WebTopBar({
    super.key,
    required this.title,
    required this.role,
    required this.onToggleSidebar,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = RoleTheme.of(role);
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    final unread = notifProvider.unreadCount(role);
    final user = auth.currentUser;
    final initials = user?.avatarInitials ?? '?';
    final name = user?.name ?? '';
    final displayName = name.isNotEmpty
        ? name.split(' ').first
        : role.name[0].toUpperCase() + role.name.substring(1);

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          bottom: BorderSide(
            color: cs.outline.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // ── Hamburger + page title ─────────────────────────────────────
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: onToggleSidebar,
              tooltip: 'Toggle sidebar',
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),

            const Spacer(),

            // ── Theme toggle ──────────────────────────────────────────────
            IconButton(
              icon: Icon(
                themeProvider.isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: cs.onSurfaceVariant,
              ),
              tooltip: themeProvider.isDarkMode ? 'Light mode' : 'Dark mode',
              onPressed: themeProvider.toggle,
            ),

            // ── Notification bell ─────────────────────────────────────────
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_outlined,
                        color: cs.onSurfaceVariant),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    ),
                    tooltip: 'Notifications',
                  ),
                  if (unread > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Separator ─────────────────────────────────────────────────
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: cs.outline.withValues(alpha: 0.25),
            ),

            // ── User avatar + name + role chip ────────────────────────────
            GestureDetector(
              onTap: () async {
                final nav = Navigator.of(context);
                final confirm = await showLogoutSheet(context, role);
                if (confirm == true && context.mounted) {
                  await auth.logout();
                  if (kIsWeb) {
                    navigateToStaticLanding();
                  } else {
                    nav.pushReplacementNamed('/login');
                  }
                }
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar circle
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: theme.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ).copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Role chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.effectivePrimary(context)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            theme.label,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: theme.effectivePrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: cs.onSurfaceVariant, size: 18),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
