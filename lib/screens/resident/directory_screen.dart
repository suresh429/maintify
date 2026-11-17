import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/role_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

/// Apartment directory — shows all members sorted: president first, then by unit.
/// Does NOT display email, phone, internal IDs, or Firebase UIDs.
class DirectoryScreen extends StatelessWidget {
  const DirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final aptId = auth.currentUser?.apartmentId ?? '';

    final isWeb = MediaQuery.sizeOf(context).width >= 600;
    final hPad = isWeb ? 24.0 : 8.0;

    return Consumer<UserProvider>(
      builder: (_, userProv, __) {
        final members = userProv.membersForApartment(aptId);

        if (members.isEmpty) {
          return _EmptyDirectory();
        }

        // Sort: president first, then by unit number
        final sorted = [...members];
        sorted.sort((a, b) {
          final aIsPresident = a.role == UserRole.president;
          final bIsPresident = b.role == UserRole.president;
          if (aIsPresident && !bIsPresident) return -1;
          if (!aIsPresident && bIsPresident) return 1;
          return a.unit.compareTo(b.unit);
        });

        return ListView.builder(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
          itemCount: sorted.length,
          itemBuilder: (_, i) {
            final tile = _MemberTile(member: sorted[i]);
            return isWeb
                ? Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: tile,
                    ),
                  )
                : tile;
          },
        );
      },
    );
  }
}

// ── Member Tile ───────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final UserModel member;

  const _MemberTile({required this.member});

  bool get _isPresident => member.role == UserRole.president;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final presidentColor =
        RoleTheme.of(UserRole.president).effectivePrimary(context);
    final residentColor =
        RoleTheme.of(UserRole.resident).effectivePrimary(context);
    final avatarColor = _isPresident ? presidentColor : residentColor;

    return GestureDetector(
      onTap: () => _showDetails(context),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: _isPresident
            ? Border.all(
                color: presidentColor.withValues(alpha: 0.35),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with colored border for president
          Container(
            decoration: _isPresident
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: presidentColor.withValues(alpha: 0.6),
                        width: 2),
                  )
                : null,
            child: CircleAvatar(
              radius: 24,
              backgroundColor: avatarColor.withValues(alpha: 0.12),
              child: Text(
                member.avatarInitials,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: avatarColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name and unit
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: AppTextStyles.subheading(color: cs.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (member.unit.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.door_front_door_outlined,
                          size: 12, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Unit ${member.unit}',
                        style: AppTextStyles.caption(
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Role chip
          _RoleChip(isPresident: _isPresident),
        ],
      ),
    ));
  }

  void _showDetails(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarColor = _isPresident
        ? RoleTheme.of(UserRole.president).effectivePrimary(context)
        : RoleTheme.of(UserRole.resident).effectivePrimary(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : cs.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

                // Avatar + name
                CircleAvatar(
                  radius: 32,
                  backgroundColor: avatarColor.withValues(alpha: 0.12),
                  child: Text(
                    member.avatarInitials,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: avatarColor,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(member.name,
                    style: AppTextStyles.heading3(color: cs.onSurface)),
                const SizedBox(height: 4),
                _RoleChip(isPresident: _isPresident),
                const SizedBox(height: 20),

                // Details list
                _DetailRow(
                  icon: Icons.door_front_door_outlined,
                  label: 'Flat / Unit',
                  value: member.unit.isNotEmpty ? member.unit : '—',
                  cs: cs,
                ),
                _DetailRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: member.email.isNotEmpty ? member.email : '—',
                  cs: cs,
                ),
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Mobile',
                  value: member.phone.isNotEmpty ? member.phone : '—',
                  cs: cs,
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Role chip ─────────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final bool isPresident;

  const _RoleChip({required this.isPresident});

  @override
  Widget build(BuildContext context) {
    final color = isPresident
        ? RoleTheme.of(UserRole.president).effectivePrimary(context)
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPresident ? Icons.star_rounded : Icons.person_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isPresident ? 'President' : 'Resident',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme cs;
  final bool isLast;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cs,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: AppTextStyles.bodyMedium(color: cs.onSurface)
                            .copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (value != '—') {
                    Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label copied'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Icon(Icons.copy_rounded,
                    size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyDirectory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 64,
                color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No Members',
                style: AppTextStyles.heading3(color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Apartment members will appear here\nonce residents register.',
              textAlign: TextAlign.center,
              style:
                  AppTextStyles.bodySmall(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
