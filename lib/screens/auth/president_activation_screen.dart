import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/president_invitation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/registration_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/common_button.dart';
import '../../widgets/maintify_logo.dart';

class PresidentActivationScreen extends StatefulWidget {
  const PresidentActivationScreen({super.key});

  @override
  State<PresidentActivationScreen> createState() =>
      _PresidentActivationScreenState();
}

class _PresidentActivationScreenState extends State<PresidentActivationScreen>
    with SingleTickerProviderStateMixin {
  final _tokenCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscurePass = true;

  PresidentInvitationModel? _invitation;
  String?                   _createdUid;
  bool                      _isVerifying = false;

  late AnimationController _animCtrl;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _passCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Step 1: Validate token ────────────────────────────────────────────────

  Future<void> _verifyToken() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      AppUtils.showSnackBar(context, 'Please enter your activation token.',
          isError: true);
      return;
    }

    final reg    = context.read<RegistrationProvider>();
    final result = await reg.validateInvitationToken(token);

    if (!mounted) return;

    if (result.error != null) {
      AppUtils.showSnackBar(context, result.error!, isError: true);
      return;
    }

    setState(() => _invitation = result.invitation);
  }

  // ── Step 2: Activate account ──────────────────────────────────────────────

  Future<void> _activate() async {
    if (_invitation == null) return;
    if (_passCtrl.text.length < 6) {
      AppUtils.showSnackBar(
          context, 'Password must be at least 6 characters.', isError: true);
      return;
    }

    final reg    = context.read<RegistrationProvider>();
    final result = await reg.beginPresidentActivation(
      invitation: _invitation!,
      password:   _passCtrl.text,
    );

    if (!mounted) return;

    if (result.error != null) {
      AppUtils.showSnackBar(context, result.error!, isError: true);
      return;
    }

    _createdUid = result.uid;
    _showVerificationSheet();
  }

  // ── Email verification bottom sheet ──────────────────────────────────────

  void _showVerificationSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool isChecking = false;
        bool isSending  = false;
        String? errorMsg;

        return StatefulBuilder(builder: (ctx, setSt) {
          final cs = Theme.of(ctx).colorScheme;
          return Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              28, 20, 28,
              MediaQuery.of(ctx).viewInsets.bottom + 36,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetHandle(cs: cs),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      color: AppColors.blue, size: 40),
                ),
                const SizedBox(height: 18),

                Text('Verify Your Email',
                    style: AppTextStyles.heading3(color: cs.onSurface),
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  "We've sent a verification email to",
                  style: AppTextStyles.bodySmall(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _invitation?.presidentEmail ?? '',
                  style: AppTextStyles.label(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please verify your email before continuing.\n'
                  'Check your Inbox, Spam, and Promotions folders.',
                  style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),

                if (errorMsg != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.overdue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.overdue.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 14, color: AppColors.overdue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(errorMsg!,
                              style: AppTextStyles.caption(
                                  color: AppColors.overdue)),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                CommonButton(
                  text: "I've Verified My Email",
                  gradient: AppColors.adminGradient,
                  icon: Icons.verified_outlined,
                  isLoading: isChecking,
                  onPressed: () async {
                    setSt(() {
                      isChecking = true;
                      errorMsg   = null;
                    });
                    final reg      = context.read<RegistrationProvider>();
                    final verified = await reg.checkEmailVerified();
                    if (!ctx.mounted) return;

                    if (verified) {
                      // Complete activation (creates Firestore docs + welcome email)
                      final result = await reg.completePresidentActivation(
                        invitation: _invitation!,
                        uid:        _createdUid!,
                      );
                      if (!ctx.mounted) return;

                      if (result.error != null) {
                        setSt(() {
                          isChecking = false;
                          errorMsg   = result.error;
                        });
                        return;
                      }

                      // Establish session
                      final auth = context.read<AuthProvider>();
                      await auth.loginWithUser(result.user!);
                      if (!ctx.mounted) return;

                      Navigator.of(ctx).pop();
                      _showSuccessSheet();
                    } else {
                      setSt(() {
                        isChecking = false;
                        errorMsg   = 'Your email has not been verified yet. '
                            'Please check your inbox and try again.';
                      });
                    }
                  },
                ),

                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: isSending
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text('Resend Verification Email',
                        style: AppTextStyles.label(
                            color: Theme.of(ctx).colorScheme.primary)),
                    onPressed: isSending
                        ? null
                        : () async {
                            setSt(() => isSending = true);
                            final reg = context.read<RegistrationProvider>();
                            await reg.resendVerificationEmail();
                            if (!ctx.mounted) return;
                            setSt(() => isSending = false);
                            AppUtils.showSnackBar(
                              context,
                              'Verification email sent. Check your inbox.',
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                TextButton(
                  onPressed: () async {
                    final reg = context.read<RegistrationProvider>();
                    await reg.abortRegistration();
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/login', (_) => false);
                  },
                  child: Text(
                    'Back to Login',
                    style: AppTextStyles.caption(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ── Success bottom sheet ──────────────────────────────────────────────────

  void _showSuccessSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs       = Theme.of(ctx).colorScheme;
        final aptCode  = _invitation?.apartmentCode ?? '';
        final aptName  = _invitation?.apartmentName ?? '';
        final flatNum  = _invitation?.presidentFlatNumber ?? '';

        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              28, 20, 28, MediaQuery.of(ctx).viewInsets.bottom + 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(cs: cs),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.paid.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration_rounded,
                    color: AppColors.paid, size: 40),
              ),
              const SizedBox(height: 16),

              Text('Congratulations!',
                  style: AppTextStyles.heading2(color: cs.onSurface),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Apartment Activated Successfully',
                  style: AppTextStyles.bodyMedium(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  children: [
                    if (aptName.isNotEmpty) ...[
                      _InfoRow(label: 'Apartment', value: aptName, cs: cs),
                      const SizedBox(height: 10),
                    ],
                    _InfoRow(
                        label: 'Code',
                        value: aptCode,
                        isCode: true,
                        cs: cs),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Your Flat', value: flatNum, cs: cs),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.paid.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.paid.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.mark_email_read_outlined,
                        size: 14, color: AppColors.paid),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your account has been verified. A welcome email with '
                        'your apartment details has been sent to your registered '
                        'email address.',
                        style: AppTextStyles.caption(color: AppColors.paid),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              CommonButton(
                text: 'Continue to Dashboard',
                gradient: AppColors.adminGradient,
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                      '/dashboard', (_) => false);
                },
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Code'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: aptCode));
                        AppUtils.showSnackBar(ctx, 'Apartment Code copied!');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: AppTextStyles.caption(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share Code'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                            text: 'My apartment code on Maintify: $aptCode'));
                        AppUtils.showSnackBar(
                            ctx, 'Code copied — share via any app!');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: AppTextStyles.caption(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.30,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF141E30), Color(0xFF243B55)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // Header row
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.arrow_back_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const MaintifyLogo(size: 56),
                          const SizedBox(width: 10),
                          Text(
                            AppConstants.appName,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(isDark ? 0.4 : 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                        colors: AppColors.adminGradient),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                      Icons.manage_accounts_outlined,
                                      color: Colors.white,
                                      size: 22),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Activate Apartment',
                                        style: AppTextStyles.heading3(
                                            color: cs.onSurface)),
                                    Text('Enter your invitation token',
                                        style: AppTextStyles.bodySmall(
                                            color: cs.onSurfaceVariant)),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // ── Step 1: token entry ───────────────────────
                            AppTextField(
                              label: 'Activation Token',
                              hint: 'e.g., ABC123XYZ456',
                              controller: _tokenCtrl,
                              focusColor: AppColors.blue,
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[A-Za-z0-9]')),
                                LengthLimitingTextInputFormatter(12),
                              ],
                              prefixIcon: const Icon(Icons.vpn_key_outlined,
                                  size: 20),
                              readOnly: _invitation != null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your activation token is in the invitation email from your Super Admin.',
                              style: AppTextStyles.caption(
                                  color: cs.onSurfaceVariant),
                            ),

                            // ── Token verified → show read-only details ───
                            AnimatedSize(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut,
                              child: _invitation == null
                                  ? const SizedBox.shrink()
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 20),

                                        // Verified badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color:
                                                AppColors.paid.withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: AppColors.paid
                                                    .withOpacity(0.2)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                  Icons.verified_rounded,
                                                  size: 16,
                                                  color: AppColors.paid),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Invitation verified',
                                                style: AppTextStyles.label(
                                                    color: AppColors.paid),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 16),

                                        // Read-only apartment info
                                        _ReadOnlyField(
                                          label: 'Email Address',
                                          value:
                                              _invitation!.presidentEmail,
                                          icon: Icons.email_outlined,
                                          cs: cs,
                                        ),
                                        const SizedBox(height: 12),
                                        _ReadOnlyField(
                                          label: 'Apartment Name',
                                          value: _invitation!.apartmentName,
                                          icon: Icons.apartment_outlined,
                                          cs: cs,
                                        ),
                                        const SizedBox(height: 12),
                                        _ReadOnlyField(
                                          label: 'Apartment Code',
                                          value: _invitation!.apartmentCode,
                                          icon: Icons.pin_outlined,
                                          cs: cs,
                                          isCode: true,
                                        ),
                                        const SizedBox(height: 16),

                                        // Password field
                                        AppTextField(
                                          label: 'Create Password',
                                          controller: _passCtrl,
                                          obscureText: _obscurePass,
                                          focusColor: AppColors.blue,
                                          prefixIcon: const Icon(
                                              Icons.lock_outline,
                                              size: 20),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePass
                                                  ? Icons
                                                      .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              size: 20,
                                            ),
                                            onPressed: () => setState(() =>
                                                _obscurePass = !_obscurePass),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Minimum 6 characters.',
                                          style: AppTextStyles.caption(
                                              color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                            ),

                            const SizedBox(height: 24),

                            Consumer<RegistrationProvider>(
                              builder: (_, reg, __) => CommonButton(
                                text: _invitation == null
                                    ? 'Verify Token'
                                    : 'Activate Account',
                                gradient: AppColors.adminGradient,
                                icon: _invitation == null
                                    ? Icons.search_rounded
                                    : Icons.how_to_reg_outlined,
                                isLoading: reg.isLoading || _isVerifying,
                                onPressed: _invitation == null
                                    ? _verifyToken
                                    : _activate,
                              ),
                            ),

                            if (_invitation != null) ...[
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton(
                                  onPressed: () => setState(() {
                                    _invitation = null;
                                    _tokenCtrl.clear();
                                    _passCtrl.clear();
                                  }),
                                  child: Text(
                                    'Use a different token',
                                    style: AppTextStyles.caption(
                                        color: cs.onSurfaceVariant),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          '© 2026 Maintify · All rights reserved',
                          style: AppTextStyles.caption(),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final ColorScheme cs;
  final bool isCode;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
    required this.cs,
    this.isCode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: isCode
                      ? const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 3,
                        )
                      : AppTextStyles.bodyMedium(color: cs.onSurface),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  final ColorScheme cs;
  const _SheetHandle({required this.cs});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: cs.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCode;
  final ColorScheme cs;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isCode = false,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: isCode
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.adminGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                  )
                : Text(value,
                    style: AppTextStyles.bodyMedium(color: cs.onSurface)),
          ),
        ],
      );
}
