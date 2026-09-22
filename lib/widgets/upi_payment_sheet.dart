import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'dart:io';
import '../core/services/upi_payment_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/app_utils.dart';
import '../models/apartment_model.dart';
import '../providers/bill_provider.dart';
import '../providers/apartment_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_text_field.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

/// Shows the UPI payment bottom sheet for a resident's monthly bill.
Future<void> showUpiPaymentSheet(
  BuildContext context, {
  required UserMonthlySummary summary,
  required String aptId,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _UpiInitialSheet(summary: summary, aptId: aptId),
    ),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

bool get _isAndroid {
  if (kIsWeb) return false;
  try {
    return Platform.isAndroid;
  } catch (_) {
    return false;
  }
}

/// Builds a UPI transaction note from the bill month and flat number.
/// Kept ≤ 50 chars to stay within UPI spec recommendations.
String _buildTxnNote(String month, String unitNumber) {
  final raw = 'Maint $month Flat $unitNumber';
  return raw.length > 50 ? raw.substring(0, 50) : raw;
}

/// Returns a stable color for a UPI app based on its package name.
Color _colorForPackage(String pkg) {
  switch (pkg) {
    case 'com.phonepe.app':
      return const Color(0xFF6B21D8); // PhonePe purple
    case 'com.google.android.apps.nbu.paisa.user':
    case 'com.google.android.apps.nbu.paisa.user.prod':
      return const Color(0xFF1A73E8); // Google blue
    case 'net.one97.paytm':
      return const Color(0xFF00B9F1); // Paytm cyan-blue
    case 'in.org.npci.upiapp':
      return const Color(0xFF8B1A1A); // BHIM dark-red
    case 'com.amazon.mShop.android.shopping':
      return const Color(0xFFFF9900); // Amazon orange
    case 'com.whatsapp':
      return const Color(0xFF25D366); // WhatsApp green
    case 'com.dreamplug.androidapp':
      return const Color(0xFF0A1931); // CRED dark
    default:
      return const Color(0xFF475569); // slate-600
  }
}

/// Returns up to 2 uppercase initials for an avatar.
String _initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
  final a = parts[0].isNotEmpty ? parts[0][0] : '';
  final b = parts[1].isNotEmpty ? parts[1][0] : '';
  return '$a$b'.toUpperCase();
}

// ── Step 1: Initial sheet ─────────────────────────────────────────────────────

class _UpiInitialSheet extends StatefulWidget {
  final UserMonthlySummary summary;
  final String aptId;

  const _UpiInitialSheet({required this.summary, required this.aptId});

  @override
  State<_UpiInitialSheet> createState() => _UpiInitialSheetState();
}

class _UpiInitialSheetState extends State<_UpiInitialSheet> {
  /// null  = still discovering
  /// []    = discovery complete, no apps found
  /// [...]  = apps available
  List<UpiApp>? _apps;
  bool _discovering = false;
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    if (_isAndroid) _discover();
  }

  Future<void> _discover() async {
    setState(() => _discovering = true);
    final apps = await UpiLauncher.instance.getAvailableApps();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _discovering = false;
    });
  }

  // ── Pay button handler ────────────────────────────────────────────────────

  Future<void> _onPayTapped(
    ApartmentModel apt,
    String userId,
    String unitNumber,
  ) async {
    // Re-discover if somehow still null
    final apps = _apps ?? await UpiLauncher.instance.getAvailableApps();
    if (!mounted) return;
    if (_apps == null) setState(() => _apps = apps);

    if (apps.isEmpty) {
      _showNoAppSheet(apt.upiId!, widget.summary.totalAmount, apt, userId, unitNumber);
      return;
    }

    UpiApp? selected;
    if (apps.length == 1) {
      selected = apps.first;
    } else {
      selected = await _showAppPicker(apps);
      if (!mounted || selected == null) return; // user cancelled
    }

    await _launchApp(selected, apt, userId, unitNumber);
  }

  Future<void> _launchApp(
    UpiApp app,
    ApartmentModel apt,
    String userId,
    String unitNumber,
  ) async {
    setState(() => _launching = true);

    final params = UpiPaymentParams(
      upiId: apt.upiId!,
      payeeName: apt.name,
      amount: widget.summary.totalAmount,
      txnNote: _buildTxnNote(widget.summary.month, unitNumber),
    );

    final result = await UpiLauncher.instance.launchApp(app, params);
    if (!mounted) return;
    setState(() => _launching = false);

    switch (result) {
      case UpiLaunchResult.launched:
        // UPI app opened — close this sheet, then show the "Did you pay?" sheet.
        // Payment is NOT marked paid here. Resident must submit a transaction
        // reference and the president must verify it.
        Navigator.of(context).pop();
        if (!mounted) return;
        await _showConfirmationSheet(apt, userId, unitNumber);

      case UpiLaunchResult.noAppFound:
        AppUtils.showSnackBar(
          context,
          'Could not open ${app.appName}. Please try another UPI app.',
          isError: true,
        );

      case UpiLaunchResult.error:
      case UpiLaunchResult.unsupportedPlatform:
        AppUtils.showSnackBar(
          context,
          'Could not open UPI app. Please try again.',
          isError: true,
        );
    }
  }

  // ── App picker ────────────────────────────────────────────────────────────

  Future<UpiApp?> _showAppPicker(List<UpiApp> apps) {
    return showModalBottomSheet<UpiApp>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UpiAppPickerSheet(apps: apps),
    );
  }

  // ── No-app sheet ──────────────────────────────────────────────────────────

  void _showNoAppSheet(
    String upiId,
    double amount,
    ApartmentModel apt,
    String userId,
    String unitNumber,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoUpiAppSheet(
        upiId: upiId,
        amount: amount,
        onTryGeneric: () => _launchGeneric(apt, userId, unitNumber),
      ),
    );
  }

  Future<void> _launchGeneric(
    ApartmentModel apt,
    String userId,
    String unitNumber,
  ) async {
    final result = await UpiLauncher.instance.launchGeneric(UpiPaymentParams(
      upiId: apt.upiId!,
      payeeName: apt.name,
      amount: widget.summary.totalAmount,
      txnNote: _buildTxnNote(widget.summary.month, unitNumber),
    ));
    if (!mounted) return;

    if (result == UpiLaunchResult.launched) {
      // Close both the no-app sheet and the initial sheet
      Navigator.of(context).pop(); // pop no-app sheet
      Navigator.of(context).pop(); // pop initial sheet
      if (!mounted) return;
      await _showConfirmationSheet(apt, userId, unitNumber);
    } else {
      AppUtils.showSnackBar(
        context,
        'No compatible UPI app was found on this device.',
        isError: true,
      );
    }
  }

  // ── Confirmation sheet ────────────────────────────────────────────────────

  Future<void> _showConfirmationSheet(
    ApartmentModel apt,
    String userId,
    String unitNumber,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _UpiConfirmSheet(
          summary: widget.summary,
          apt: apt,
          userId: userId,
          unitNumber: unitNumber,
          aptId: widget.aptId,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = context.read<AuthProvider>().currentUser;
    final apt = context.watch<ApartmentProvider>().findById(widget.aptId);

    if (user == null || apt == null || (apt.upiId ?? '').isEmpty) {
      return const SizedBox.shrink();
    }

    final isBusy = _discovering || _launching;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC39A51), Color(0xFF0F172A)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.currency_rupee_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pay Maintenance Bill',
                        style: AppTextStyles.subheading(color: cs.onSurface)),
                    Text(widget.summary.month,
                        style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Amount card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFC39A51), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flat ${user.unit}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppUtils.formatCurrency(widget.summary.totalAmount),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      const Text(
                        'Payment will be sent to',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    apt.name,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    apt.upiId!,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Platform-specific action area ──────────────────────────────

            if (!_isAndroid) ...[
              // Non-Android: show info only
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: cs.onSurfaceVariant, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'UPI payments are available on Android devices.',
                        style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: AppTextStyles.bodyMedium(color: cs.onSurfaceVariant)),
                ),
              ),
            ] else ...[
              // Android: show app discovery result + action buttons

              // While discovering apps, show a subtle status line
              if (_discovering)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Checking installed UPI apps…',
                        style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),

              // When discovery found apps, show a small summary
              if (!_discovering && _apps != null && _apps!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 14, color: AppColors.paid),
                      const SizedBox(width: 6),
                      Text(
                        _apps!.length == 1
                            ? 'Pay with ${_apps!.first.appName}'
                            : '${_apps!.length} UPI apps available',
                        style: AppTextStyles.caption(color: AppColors.paid),
                      ),
                    ],
                  ),
                ),

              // Buttons row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isBusy ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: Text('Cancel',
                          style: AppTextStyles.buttonText(color: cs.onSurface)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: isBusy
                          ? null
                          : () => _onPayTapped(apt, user.id, user.unit),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      icon: isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text('Pay with UPI',
                          style: AppTextStyles.buttonText()),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── App picker sheet ──────────────────────────────────────────────────────────

class _UpiAppPickerSheet extends StatelessWidget {
  final List<UpiApp> apps;

  const _UpiAppPickerSheet({required this.apps});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('Choose UPI App',
                style: AppTextStyles.heading3(color: cs.onSurface)),
            const SizedBox(height: 6),
            Text(
              'Select which app to use for this payment.',
              style: AppTextStyles.caption(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ...apps.map(
              (app) => _AppOptionTile(
                app: app,
                onTap: () => Navigator.pop(context, app),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text('Cancel',
                    style:
                        AppTextStyles.bodyMedium(color: cs.onSurfaceVariant)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppOptionTile extends StatelessWidget {
  final UpiApp app;
  final VoidCallback onTap;

  const _AppOptionTile({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _colorForPackage(app.packageName);
    final initials = _initialsFor(app.appName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.appName,
                      style: AppTextStyles.bodyLarge(color: cs.onSurface)
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (app.scheme == UpiScheme.phonePe)
                      Text(
                        'PhonePe UPI',
                        style:
                            AppTextStyles.caption(color: cs.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step 2: Confirmation sheet (after returning from UPI app) ─────────────────

class _UpiConfirmSheet extends StatefulWidget {
  final UserMonthlySummary summary;
  final ApartmentModel apt;
  final String userId;
  final String unitNumber;
  final String aptId;

  const _UpiConfirmSheet({
    required this.summary,
    required this.apt,
    required this.userId,
    required this.unitNumber,
    required this.aptId,
  });

  @override
  State<_UpiConfirmSheet> createState() => _UpiConfirmSheetState();
}

class _UpiConfirmSheetState extends State<_UpiConfirmSheet> {
  bool _showRefEntry = false;
  final _refController = TextEditingController();
  final _refFormKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_refFormKey.currentState!.validate()) return;
    final upiRef = _refController.text.trim();
    setState(() => _submitting = true);

    final billProvider = context.read<BillProvider>();
    final aptProvider = context.read<ApartmentProvider>();
    final presidentId = aptProvider.currentPresidentId(widget.aptId) ?? '';

    // Find all pending bills for this user in this month.
    // Payment is set to BillStatus.pendingApproval — NOT paid.
    // President must verify the UPI reference before it becomes paid.
    final monthBills = billProvider
        .billsForApartment(widget.aptId)
        .where((b) => b.month == widget.summary.month)
        .toList();

    bool submitted = false;
    for (final bill in monthBills) {
      final payment = billProvider.userPaymentForBill(bill.id, widget.userId);
      if (payment != null && !payment.isPaid && !payment.isPendingApproval) {
        try {
          await billProvider.submitUpiPaymentForBill(
            billId: bill.id,
            userId: widget.userId,
            aptId: widget.aptId,
            presidentId: presidentId,
            unitNumber: widget.unitNumber,
            upiRef: upiRef,
            upiIdUsed: widget.apt.upiId ?? '',
          );
          submitted = true;
        } catch (e) {
          debugPrint('[UpiPaymentSheet] submit error: $e');
        }
      }
    }

    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.of(context).pop();

    if (submitted) {
      AppUtils.showSnackBar(
        context,
        'Payment submitted for verification.',
        color: AppColors.paid,
      );
    } else {
      AppUtils.showSnackBar(context, 'Nothing to submit.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              if (!_showRefEntry) ...[
                const Icon(Icons.help_outline_rounded,
                    size: 48, color: Color(0xFF2563EB)),
                const SizedBox(height: 12),
                Text('Did you complete the payment?',
                    style: AppTextStyles.heading3(color: cs.onSurface),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  AppUtils.formatCurrency(widget.summary.totalAmount),
                  style: AppTextStyles.subheading(color: AppColors.paid)
                      .copyWith(fontSize: 20),
                ),
                const SizedBox(height: 6),
                Text('UPI: ${widget.apt.upiId}',
                    style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Not Yet',
                            style: AppTextStyles.buttonText(
                                color: cs.onSurface)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => setState(() => _showRefEntry = true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text('Yes, I Paid',
                            style: AppTextStyles.buttonText()),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text('Enter UPI Transaction ID',
                    style: AppTextStyles.heading3(color: cs.onSurface)),
                const SizedBox(height: 8),
                Text(
                  'Enter the UPI Reference / Transaction ID from your payment app.',
                  style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Form(
                  key: _refFormKey,
                  child: AppTextField(
                    controller: _refController,
                    label: 'UPI Transaction / Reference ID',
                    hint: 'e.g., 123456789012',
                    focusColor: const Color(0xFF2563EB),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Transaction ID is required';
                      }
                      if (v.trim().length < 6) {
                        return 'Enter a valid transaction ID';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top_rounded,
                          color: Color(0xFFD97706), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your payment will be marked as paid after the president verifies it.',
                          style:
                              AppTextStyles.caption(color: const Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Submit Payment',
                            style: AppTextStyles.buttonText()),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _showRefEntry = false),
                  child: Text('Back',
                      style: AppTextStyles.bodyMedium(
                          color: cs.onSurfaceVariant)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── No UPI App Sheet ──────────────────────────────────────────────────────────

class _NoUpiAppSheet extends StatefulWidget {
  final String upiId;
  final double amount;
  /// Called when the user wants to try a generic `upi://pay` launch anyway.
  final Future<void> Function() onTryGeneric;

  const _NoUpiAppSheet({
    required this.upiId,
    required this.amount,
    required this.onTryGeneric,
  });

  @override
  State<_NoUpiAppSheet> createState() => _NoUpiAppSheetState();
}

class _NoUpiAppSheetState extends State<_NoUpiAppSheet> {
  bool _trying = false;

  Future<void> _tryGeneric() async {
    setState(() => _trying = true);
    await widget.onTryGeneric();
    if (mounted) setState(() => _trying = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.phone_android_rounded,
                size: 44, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No UPI App Found',
                style: AppTextStyles.heading3(color: cs.onSurface),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'No compatible UPI app was found on this device. '
              'Open Google Pay, PhonePe, Paytm, or BHIM manually and pay to:',
              style: AppTextStyles.bodyMedium(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Tappable copy-to-clipboard UPI ID
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.upiId));
                AppUtils.showSnackBar(context, 'UPI ID copied to clipboard');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('UPI ID',
                              style: AppTextStyles.caption(
                                  color: cs.onSurfaceVariant)),
                          const SizedBox(height: 2),
                          Text(
                            widget.upiId,
                            style: AppTextStyles.bodyLarge(color: cs.onSurface)
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.copy_rounded,
                        size: 20, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Amount: ${AppUtils.formatCurrency(widget.amount)}',
              style: AppTextStyles.bodyMedium(color: cs.onSurface)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFD97706), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'After paying manually, use the "I Paid" option to submit '
                      'your UPI Transaction ID for the president to verify.',
                      style:
                          AppTextStyles.caption(color: const Color(0xFFD97706)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Try generic UPI intent — may open app chooser on some devices
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _trying ? null : _tryGeneric,
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _trying
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: cs.onSurface),
                      )
                    : Text('Try Opening UPI App',
                        style: AppTextStyles.buttonText(color: cs.onSurface)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('OK', style: AppTextStyles.buttonText()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
