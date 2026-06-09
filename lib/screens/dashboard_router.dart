import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/apartment_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/complaint_provider.dart';
import '../providers/meeting_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
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

    // Wrap with _StreamStarter so all Firestore listeners are started exactly
    // once per authenticated session (it's idempotent thanks to _started flag).
    final dashboard = _StreamStarter(child: _dashboardFor(auth.role));

    if (auth.isFirstLogin) {
      return _FirstLoginWrapper(child: dashboard);
    }

    return dashboard;
  }
}

/// Starts all Firestore stream listeners once per login session.
/// Placed at the root of authenticated navigation so streams live as long
/// as the user is signed in, and are cancelled on logout/dispose.
class _StreamStarter extends StatefulWidget {
  final Widget child;
  const _StreamStarter({required this.child});

  @override
  State<_StreamStarter> createState() => _StreamStarterState();
}

class _StreamStarterState extends State<_StreamStarter> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser!;
    final aptId = user.apartmentId ?? '';
    final role = auth.role!;

    // Start all Firestore listeners
    context.read<ApartmentProvider>().startListening();
    context.read<UserProvider>().startListening();
    context.read<NotificationProvider>().startListening(role);
    context.read<MeetingProvider>().startListening(aptId);

    switch (role) {
      case UserRole.superAdmin:
        context.read<BillProvider>().startListeningAll();
        break;
      case UserRole.admin:
        context.read<BillProvider>().startListeningForApartment(aptId);
        context
            .read<ComplaintProvider>()
            .startListeningForApartment(aptId);
        break;
      case UserRole.user:
        context.read<BillProvider>().startListeningForApartment(aptId);
        context
            .read<ComplaintProvider>()
            .startListeningForUser(user.id);
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
