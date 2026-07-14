import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/apartment_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/complaint_provider.dart';
import '../providers/meeting_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
import '../providers/registration_provider.dart';
import '../core/theme/role_theme.dart';
import 'super_admin/super_admin_dashboard.dart';
import 'admin/admin_dashboard.dart';
import 'user/user_dashboard.dart';
import 'login_screen.dart';

class DashboardRouter extends StatelessWidget {
  const DashboardRouter({super.key});

  Widget _dashboardFor(UserRole? role, {String? notificationType}) {
    switch (role) {
      case UserRole.superAdmin:
        return SuperAdminDashboard(notificationType: notificationType);
      case UserRole.admin:
        return AdminDashboard(notificationType: notificationType);
      case UserRole.user:
        return UserDashboard(notificationType: notificationType);
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

    // Read notification type passed by FcmService when a push notification is tapped.
    final notificationType =
        ModalRoute.of(context)?.settings.arguments as String?;

    // Wrap with _StreamStarter so all Firestore listeners are started exactly
    // once per authenticated session (it's idempotent thanks to _started flag).
    return _StreamStarter(
      child: _dashboardFor(auth.role, notificationType: notificationType),
    );
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
    _started = true; // set synchronously so rebuilds before the frame don't double-start

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      final user = auth.currentUser!;
      final aptId = user.apartmentId ?? '';
      final role = auth.role!;

      // Start all Firestore listeners
      context.read<ApartmentProvider>().startListening();
      context.read<UserProvider>().startListening();
      // Each user only sees notifications written with their own userId.
      context.read<NotificationProvider>().startListening(user.id);
      context.read<MeetingProvider>().startListening(aptId);

      switch (role) {
        case UserRole.superAdmin:
          context.read<BillProvider>().startListeningAll();
          break;
        case UserRole.admin:
          context.read<BillProvider>().startListeningForApartment(aptId);
          context.read<ComplaintProvider>().startListeningForApartment(aptId);
          context.read<RegistrationProvider>().startListeningRequests(aptId);
          break;
        case UserRole.user:
          // Pass userId so BillProvider streams only this user's payment docs,
          // avoiding loading every resident's payment records.
          context.read<BillProvider>().startListeningForApartment(aptId, userId: user.id);
          context
              .read<ComplaintProvider>()
              .startListeningForUser(user.id);
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

