import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/apartment_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/complaint_provider.dart';
import '../providers/meeting_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
import '../providers/ads_provider.dart';
import '../core/theme/role_theme.dart';
import '../core/services/widget_data_service.dart';
import '../core/utils/app_utils.dart';
import 'admin/admin_dashboard.dart';
import 'president/president_dashboard.dart';
import 'resident/resident_dashboard.dart';

class DashboardRouter extends StatefulWidget {
  const DashboardRouter({super.key});

  @override
  State<DashboardRouter> createState() => _DashboardRouterState();
}

class _DashboardRouterState extends State<DashboardRouter> {
  Widget _dashboardFor(UserRole? role, {String? notificationType}) {
    switch (role) {
      case UserRole.admin:
        return AdminDashboard(notificationType: notificationType);
      case UserRole.president:
        return PresidentDashboard(notificationType: notificationType);
      case UserRole.resident:
        return ResidentDashboard(notificationType: notificationType);
      default:
        return const Scaffold();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      });
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      );
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

class _StreamStarterState extends State<_StreamStarter> with WidgetsBindingObserver {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh widget data whenever user returns to the app.
      Future.delayed(const Duration(seconds: 1), () => _pushWidgetUpdate());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      final user = auth.currentUser!;
      final aptId = user.apartmentId ?? '';
      final role = auth.role!;

      context.read<ApartmentProvider>().startListening();
      context.read<UserProvider>().startListening();
      context.read<NotificationProvider>().startListening(user.id);
      context.read<MeetingProvider>().startListening(aptId);
      context.read<AdsProvider>().startListening(aptId.isEmpty ? null : aptId);

      switch (role) {
        case UserRole.admin:
          context.read<BillProvider>().startListeningAll();
        case UserRole.president:
          context.read<BillProvider>().startListeningForApartment(aptId);
          context.read<ComplaintProvider>().startListeningForApartment(aptId);
        case UserRole.resident:
          context.read<BillProvider>().startListeningForApartment(aptId);
          context
              .read<ComplaintProvider>()
              .startListeningForApartment(aptId);
      }

      // Push initial widget snapshot after streams are started.
      // A 3-second delay lets the first Firestore snapshots arrive.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        Future.delayed(const Duration(seconds: 3), () => _pushWidgetUpdate());
      }
    });
  }

  /// Reads current app state and pushes a snapshot to iOS WidgetKit.
  /// Silently no-ops if any data is not yet loaded.
  void _pushWidgetUpdate() {
    if (!mounted || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn || auth.currentUser == null) return;

      final user = auth.currentUser!;
      final aptProvider = context.read<ApartmentProvider>();
      final billProvider = context.read<BillProvider>();

      final apt = user.apartmentId != null
          ? aptProvider.findById(user.apartmentId!)
          : null;

      int pendingCount = 0;
      String? pendingAmountDisplay;

      switch (auth.role) {
        case UserRole.resident:
          pendingCount = billProvider.pendingUserBillsCount(user.id);
          final due = billProvider.totalDueForUser(user.id);
          if (due > 0) pendingAmountDisplay = '₹${due.toStringAsFixed(0)}';
        case UserRole.president:
          if (user.apartmentId != null) {
            final summaries =
                billProvider.monthlyBillsForApartment(user.apartmentId!);
            if (summaries.isNotEmpty) {
              pendingCount = summaries.first.pendingFlats;
            }
          }
        case UserRole.admin:
        case null:
          break;
      }

      WidgetDataService.update(
        isLoggedIn: true,
        apartmentName: apt?.name,
        residentName: AppUtils.displayFirstName(user.name),
        userRole: auth.role?.name,
        pendingBillCount: pendingCount,
        pendingAmountDisplay: pendingAmountDisplay,
      );
    } catch (e) {
      debugPrint('[Widget] _pushWidgetUpdate error (non-critical): $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

