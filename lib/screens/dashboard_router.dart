import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/role_theme.dart';
import '../widgets/change_password_sheet.dart';
import 'super_admin/super_admin_dashboard.dart';
import 'admin/admin_dashboard.dart';
import 'user/user_dashboard.dart';
import 'login_screen.dart';

class DashboardRouter extends StatelessWidget {
  const DashboardRouter({super.key});

  Widget _dashboardFor(UserRole? role) {
    switch (role) {
      case UserRole.superAdmin:
        return const SuperAdminDashboard();
      case UserRole.admin:
        return const AdminDashboard();
      case UserRole.user:
        return const UserDashboard();
      default:
        return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    if (auth.isFirstLogin) {
      return _FirstLoginWrapper(child: _dashboardFor(auth.role));
    }

    return _dashboardFor(auth.role);
  }
}

/// Wraps the dashboard and forces the change-password bottom sheet open on
/// first frame. The sheet is non-dismissible — once the user sets a new
/// password [AuthProvider.isFirstLogin] becomes false and the wrapper is
/// removed from the tree by [DashboardRouter].
class _FirstLoginWrapper extends StatefulWidget {
  final Widget child;
  const _FirstLoginWrapper({required this.child});

  @override
  State<_FirstLoginWrapper> createState() => _FirstLoginWrapperState();
}

class _FirstLoginWrapperState extends State<_FirstLoginWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showChangePasswordSheet(context, isFirstLogin: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
