import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/apartment_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/complaint_provider.dart';
import '../providers/meeting_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/user_provider.dart';
import '../providers/ads_provider.dart';
import '../providers/community_fund_provider.dart';
import '../providers/version_provider.dart';
import '../models/notification_model.dart';
import '../models/update_status.dart';
import '../core/theme/role_theme.dart';
import '../core/services/widget_data_service.dart';
import '../core/utils/app_utils.dart';
import '../widgets/update_dialog.dart';
import '../core/app_update/presentation/providers/app_update_provider.dart';
import '../core/app_update/presentation/services/app_update_coordinator.dart';
import 'admin/admin_dashboard.dart';
import 'president/president_dashboard.dart';
import 'resident/resident_dashboard.dart';

class DashboardRouter extends StatefulWidget {
  const DashboardRouter({super.key});

  @override
  State<DashboardRouter> createState() => _DashboardRouterState();
}

class _DashboardRouterState extends State<DashboardRouter> {
  Widget _dashboardFor(
    UserRole? role, {
    String? notificationType,
    String? referenceId,
    String? referenceType,
  }) {
    debugPrint('[DASH-ROUTER] _dashboardFor → role=$role  type=$notificationType  refId=$referenceId');
    switch (role) {
      case UserRole.admin:
        debugPrint('[DASH-ROUTER] Opening: AdminDashboard');
        return AdminDashboard(
          notificationType: notificationType,
          referenceId:      referenceId,
          referenceType:    referenceType,
        );
      case UserRole.president:
        debugPrint('[DASH-ROUTER] Opening: PresidentDashboard');
        return PresidentDashboard(
          notificationType: notificationType,
          referenceId:      referenceId,
          referenceType:    referenceType,
        );
      case UserRole.resident:
        debugPrint('[DASH-ROUTER] Opening: ResidentDashboard');
        return ResidentDashboard(
          notificationType: notificationType,
          referenceId:      referenceId,
          referenceType:    referenceType,
        );
      default:
        debugPrint('[DASH-ROUTER] Opening: Scaffold (no role matched — role=$role)');
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

    // Read notification arguments.
    // FcmService._navigateFromPayload() passes a Map<String, String> containing
    // notificationType, referenceId, referenceType.
    // Legacy callers may pass a bare String (notificationType only) or null.
    final Object? args = ModalRoute.of(context)?.settings.arguments;

    // ── DEBUG ─────────────────────────────────────────────────────────────────
    debugPrint('[DASH-ROUTER] ══════════════════════════════════════');
    debugPrint('[DASH-ROUTER] build() called — args runtimeType: ${args.runtimeType}');
    debugPrint('[DASH-ROUTER] args value: $args');
    // ─────────────────────────────────────────────────────────────────────────

    final String? notificationType;
    final String? referenceId;
    final String? referenceType;
    if (args is Map) {
      notificationType = args['notificationType'] as String?;
      referenceId      = args['referenceId']      as String?;
      referenceType    = args['referenceType']    as String?;
      debugPrint('[DASH-ROUTER] args branch: Map');
    } else if (args is String) {
      notificationType = args;
      referenceId      = null;
      referenceType    = null;
      debugPrint('[DASH-ROUTER] args branch: String');
    } else {
      notificationType = null;
      referenceId      = null;
      referenceType    = null;
      debugPrint('[DASH-ROUTER] args branch: null/unknown');
    }

    debugPrint('[DASH-ROUTER] notificationType: "$notificationType"');
    debugPrint('[DASH-ROUTER] referenceId:      "$referenceId"');
    debugPrint('[DASH-ROUTER] referenceType:    "$referenceType"');
    debugPrint('[DASH-ROUTER] auth.role:        ${auth.role}');
    debugPrint('[DASH-ROUTER] ══════════════════════════════════════');

    // Wrap with _StreamStarter so all Firestore listeners are started exactly
    // once per authenticated session (it's idempotent thanks to _started flag).
    return _StreamStarter(
      child: _dashboardFor(
        auth.role,
        notificationType: notificationType,
        referenceId:      referenceId,
        referenceType:    referenceType,
      ),
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

      // ── Update check ───────────────────────────────────────────────────────
      // Android: Google Play In-App Update API via AppUpdateCoordinator.
      //          Works on ALL Android devices without Firebase Remote Config.
      // iOS/web: Firebase RC + Firestore fallback (unchanged behaviour).
      Future.delayed(const Duration(seconds: 3), () async {
        if (!mounted) return;
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          // Show Play In-App Update dialog (immediate / flexible).
          final coordinator = AppUpdateCoordinator(
            context.read<AppUpdateProvider>(),
          );
          await coordinator.runUpdateCheck(context);
          if (!mounted) return;
          // Always run Firestore version check on Android too — just for the
          // in-app notification (no dialog shown). This ensures the notification
          // appears in ALL roles' notification list regardless of whether Play
          // Core succeeds (it fails in debug builds).
          await _checkRcVersion(context, auth, user, showDialog: false);
        } else {
          await _checkRcVersion(context, auth, user);
        }
      });
      // ── End update check ───────────────────────────────────────────────────

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
          if (aptId.isNotEmpty) {
            context.read<CommunityFundProvider>().startListening(aptId);
          }
        case UserRole.resident:
          context.read<BillProvider>().startListeningForApartment(aptId);
          context
              .read<ComplaintProvider>()
              .startListeningForApartment(aptId);
          if (aptId.isNotEmpty) {
            context.read<CommunityFundProvider>().startListening(aptId);
          }
      }

      // Push initial widget snapshot after streams are started.
      // A 3-second delay lets the first Firestore snapshots arrive.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        Future.delayed(const Duration(seconds: 3), () => _pushWidgetUpdate());
      }
    });
  }

  // ── iOS / web: Firestore version check + optional dialog ────────────────
  // showDialog: false → notification only (used on Android after Play Core check)
  // showDialog: true  → notification + update dialog (iOS / web)
  Future<void> _checkRcVersion(
    BuildContext ctx,
    AuthProvider auth,
    dynamic user, {
    bool showDialog = true,
  }) async {
    final versionProvider = ctx.read<VersionProvider>();
    debugPrint('[DASH-ROUTER] Running RC/Firestore version check…');
    await versionProvider.checkVersion();
    if (!mounted) return;
    final status = versionProvider.status;
    final model  = versionProvider.model;
    if ((status == UpdateStatus.forceUpdate ||
            status == UpdateStatus.optionalUpdate) &&
        model != null) {
      final box      = Hive.box<String>('session');
      final dedupKey = 'update_notif_${model.latestVersion}';
      if (box.get(dedupKey) != 'true') {
        await box.put(dedupKey, 'true');
        if (!mounted) return;
        await ctx.read<NotificationProvider>().addAndPersistNotification(
          title:         'App Update Available',
          body:          'Version ${model.latestVersion} is available. Tap to update.',
          type:          NotificationType.appUpdate,
          targetRole:    auth.role ?? UserRole.resident,
          targetUserIds: [user.id],
        );
      }
      if (!showDialog) return;
      if (!mounted) return;
      debugPrint('[DASH-ROUTER] Showing update dialog: $status');
      showUpdateDialog(
        ctx,
        model:    model,
        isForce:  status == UpdateStatus.forceUpdate,
        onUpdate: versionProvider.openStore,
      );
    }
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

