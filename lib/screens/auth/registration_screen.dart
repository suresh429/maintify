import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../models/user_model.dart';
import '../../models/apartment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/registration_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/common_button.dart';
import '../../widgets/maintify_logo.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // ── Role ─────────────────────────────────────────────────────────────────
  String _selectedRole = 'president';

  // ── Common controllers ────────────────────────────────────────────────────
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscurePass = true;
  int  _passStrength = 0;

  // ── President-only controllers ────────────────────────────────────────────
  final _aptNameCtrl       = TextEditingController();
  final _aptAddressCtrl    = TextEditingController();
  final _totalFlatsCtrl    = TextEditingController();
  final _presidentFlatCtrl = TextEditingController();
  String _aptType   = 'Apartment';
  int    _towerCount = 1;
  List<TextEditingController> _towerNameCtrls = [
    TextEditingController(text: 'A'),
  ];

  // ── Resident-only controllers ─────────────────────────────────────────────
  final _aptCodeCtrl = TextEditingController();
  final _flatCtrl    = TextEditingController();

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _animCtrl;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _fadeAnim;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(_onPasswordChanged);
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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _aptNameCtrl.dispose();
    _aptAddressCtrl.dispose();
    _totalFlatsCtrl.dispose();
    _presidentFlatCtrl.dispose();
    _aptCodeCtrl.dispose();
    _flatCtrl.dispose();
    for (final c in _towerNameCtrls) c.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Password strength
  // ─────────────────────────────────────────────────────────────────────────

  void _onPasswordChanged() {
    final s = _computeStrength(_passCtrl.text);
    if (s != _passStrength) setState(() => _passStrength = s);
  }

  int _computeStrength(String p) {
    if (p.isEmpty) return 0;
    int s = 0;
    if (p.length >= 6)  s++;
    if (p.length >= 10) s++;
    if (p.contains(RegExp(r'[A-Z]')))             s++;
    if (p.contains(RegExp(r'[0-9]')))             s++;
    if (p.contains(RegExp(r'[!@#$%^&*(),.?]')))  s++;
    return s;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Tower controller management
  // ─────────────────────────────────────────────────────────────────────────

  void _resizeTowerCtrls(int newCount) {
    if (newCount == _towerNameCtrls.length) return;
    if (newCount > _towerNameCtrls.length) {
      for (int i = _towerNameCtrls.length; i < newCount; i++) {
        _towerNameCtrls.add(
          TextEditingController(text: String.fromCharCode(65 + i)),
        );
      }
    } else {
      for (int i = newCount; i < _towerNameCtrls.length; i++) {
        _towerNameCtrls[i].dispose();
      }
      _towerNameCtrls = _towerNameCtrls.sublist(0, newCount);
    }
    setState(() => _towerCount = newCount);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Submit
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == 'president') {
      await _submitPresident();
    } else {
      await _submitResident();
    }
  }

  Future<void> _submitPresident() async {
    final reg      = context.read<RegistrationProvider>();
    final isGated  = _aptType == 'Gated Community';
    final totalFlats = int.tryParse(_totalFlatsCtrl.text.trim()) ?? 0;

    final result = await reg.selfRegisterPresident(
      name:          _nameCtrl.text.trim(),
      email:         _emailCtrl.text.trim(),
      phone:         _phoneCtrl.text.trim(),
      password:      _passCtrl.text,
      apartmentName: _aptNameCtrl.text.trim(),
      apartmentType: _aptType,
      address:       _aptAddressCtrl.text.trim(),
      totalFlats:    totalFlats,
      towerCount:    isGated ? _towerCount : 0,
      towerNames:    isGated
          ? _towerNameCtrls.map((c) => c.text.trim()).toList()
          : [],
      presidentFlat: _presidentFlatCtrl.text.trim(),
    );

    if (!mounted) return;

    if (result.error != null) {
      AppUtils.showSnackBar(context, result.error!, isError: true);
      return;
    }

    _showVerificationSheet(
      email: _emailCtrl.text.trim(),
      user:  result.user!,
      onVerified: () => _showPresidentSuccessSheet(
        aptName:      _aptNameCtrl.text.trim(),
        aptCode:      result.aptCode ?? '',
        presidentFlat: _presidentFlatCtrl.text.trim(),
      ),
    );
  }

  Future<void> _submitResident() async {
    final reg = context.read<RegistrationProvider>();

    final result = await reg.registerResident(
      name:          _nameCtrl.text.trim(),
      email:         _emailCtrl.text.trim(),
      phone:         _phoneCtrl.text.trim(),
      password:      _passCtrl.text,
      apartmentCode: _aptCodeCtrl.text.trim().toUpperCase(),
      flatNumber:    _flatCtrl.text.trim().toUpperCase(),
    );

    if (!mounted) return;

    if (result.error != null) {
      AppUtils.showSnackBar(context, result.error!, isError: true);
      return;
    }

    _showVerificationSheet(
      email: _emailCtrl.text.trim(),
      user:  result.user!,
      onVerified: () => _showResidentSuccessSheet(
        aptName:    result.apt?.name ?? '',
        flatNumber: _flatCtrl.text.trim().toUpperCase(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Email verification bottom sheet
  // ─────────────────────────────────────────────────────────────────────────

  void _showVerificationSheet({
    required String email,
    required UserModel user,
    required VoidCallback onVerified,
  }) {
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

        return StatefulBuilder(
          builder: (ctx, setSt) {
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
                    style: AppTextStyles.bodySmall(
                        color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: AppTextStyles.label(color: AppColors.blue),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please verify your email before continuing.\n'
                    'Check your Inbox, Spam, and Promotions folders.',
                    style: AppTextStyles.caption(
                        color: cs.onSurfaceVariant),
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
                    gradient: const [Color(0xFF1E3A8A), Color(0xFF06B6D4)],
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
                        final auth = context.read<AuthProvider>();
                        await auth.loginWithUser(user);
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        onVerified();
                      } else {
                        setSt(() {
                          isChecking = false;
                          errorMsg   =
                              'Your email has not been verified yet. '
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
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(
                        'Resend Verification Email',
                        style: AppTextStyles.label(
                            color: Theme.of(ctx).colorScheme.primary),
                      ),
                      onPressed: isSending
                          ? null
                          : () async {
                              setSt(() => isSending = true);
                              final reg =
                                  context.read<RegistrationProvider>();
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
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // President success bottom sheet
  // ─────────────────────────────────────────────────────────────────────────

  void _showPresidentSuccessSheet({
    required String aptName,
    required String aptCode,
    required String presidentFlat,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
              Text('Apartment Created Successfully',
                  style: AppTextStyles.bodyMedium(
                      color: cs.onSurfaceVariant),
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
                      _SuccessRow(
                          label: 'Apartment',
                          value: aptName,
                          cs: cs),
                      const SizedBox(height: 10),
                    ],
                    _SuccessRow(
                        label: 'Code',
                        value: aptCode,
                        isCode: true,
                        cs: cs),
                    const SizedBox(height: 10),
                    _SuccessRow(
                        label: 'Your Flat',
                        value: presidentFlat,
                        cs: cs),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.paid.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.paid.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.mark_email_read_outlined,
                        size: 14, color: AppColors.paid),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your email has been verified. A welcome email '
                        'with your apartment details has been sent to '
                        'your registered email address.',
                        style: AppTextStyles.caption(
                            color: AppColors.paid),
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
                        AppUtils.showSnackBar(
                            context, 'Apartment Code copied!');
                      },
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
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
                          text:
                              'My apartment code on Maintify: $aptCode',
                        ));
                        AppUtils.showSnackBar(
                            context,
                            'Code copied — share via any app!');
                      },
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
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

  // ─────────────────────────────────────────────────────────────────────────
  // Resident success bottom sheet
  // ─────────────────────────────────────────────────────────────────────────

  void _showResidentSuccessSheet({
    required String aptName,
    required String flatNumber,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
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
                  color: AppColors.paid.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.celebration_rounded,
                    color: AppColors.paid, size: 40),
              ),
              const SizedBox(height: 16),

              Text('Welcome!',
                  style: AppTextStyles.heading2(color: cs.onSurface),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Registration Successful',
                  style: AppTextStyles.bodyMedium(
                      color: cs.onSurfaceVariant),
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
                      _SuccessRow(
                          label: 'Apartment',
                          value: aptName,
                          cs: cs),
                      const SizedBox(height: 10),
                    ],
                    _SuccessRow(
                        label: 'Your Flat',
                        value: flatNumber,
                        cs: cs),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.paid.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: AppColors.paid.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.mark_email_read_outlined,
                        size: 14, color: AppColors.paid),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your email has been verified. A welcome email '
                        'containing your registration details has been '
                        'sent to your registered email address.',
                        style: AppTextStyles.caption(
                            color: AppColors.paid),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              CommonButton(
                text: 'Continue to Dashboard',
                gradient: const [Color(0xFF1A2A4A), Color(0xFF2D4A6B)],
                icon: Icons.arrow_forward_rounded,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                      '/dashboard', (_) => false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

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
                            Text('Create Account',
                                style: AppTextStyles.heading2(
                                    color: cs.onSurface)),
                            const SizedBox(height: 4),
                            Text('Set up your Maintify account',
                                style: AppTextStyles.bodyMedium(
                                    color: cs.onSurfaceVariant)),
                            const SizedBox(height: 20),

                            // ── Role segmented button ─────────────────
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'president',
                                  icon: Icon(
                                      Icons.manage_accounts_outlined,
                                      size: 18),
                                  label: Text('President'),
                                ),
                                ButtonSegment(
                                  value: 'resident',
                                  icon: Icon(
                                      Icons.person_outline_rounded,
                                      size: 18),
                                  label: Text('Resident'),
                                ),
                              ],
                              selected: {_selectedRole},
                              onSelectionChanged: (set) => setState(() {
                                _selectedRole = set.first;
                                _formKey.currentState?.reset();
                              }),
                              style: SegmentedButton.styleFrom(
                                selectedBackgroundColor:
                                    cs.primary.withOpacity(0.12),
                                selectedForegroundColor: cs.primary,
                                side: BorderSide(
                                    color: cs.outline.withOpacity(0.5)),
                              ),
                            ),

                            const SizedBox(height: 24),

                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // ── Common fields ─────────────────
                                  AppTextField(
                                    label: 'Full Name',
                                    controller: _nameCtrl,
                                    keyboardType: TextInputType.name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    focusColor: AppColors.blue,
                                    prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                        size: 20),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Enter your full name'
                                            : null,
                                  ),
                                  const SizedBox(height: 14),

                                  AppTextField(
                                    label: 'Email Address',
                                    controller: _emailCtrl,
                                    keyboardType:
                                        TextInputType.emailAddress,
                                    focusColor: AppColors.blue,
                                    prefixIcon: const Icon(
                                        Icons.email_outlined,
                                        size: 20),
                                    validator: (v) {
                                      if (v == null ||
                                          v.trim().isEmpty) {
                                        return 'Enter your email';
                                      }
                                      if (!v.contains('@') ||
                                          !v.contains('.')) {
                                        return 'Enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  AppTextField(
                                    label: 'Mobile Number',
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    focusColor: AppColors.blue,
                                    prefixIcon: const Icon(
                                        Icons.phone_outlined,
                                        size: 20),
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                            ? 'Enter your mobile number'
                                            : null,
                                  ),
                                  const SizedBox(height: 14),

                                  AppTextField(
                                    label: 'Password',
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
                                      onPressed: () => setState(
                                          () => _obscurePass =
                                              !_obscurePass),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Enter a password';
                                      }
                                      if (v.length < 6) {
                                        return 'Minimum 6 characters';
                                      }
                                      return null;
                                    },
                                  ),

                                  if (_passCtrl.text.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    _PasswordStrengthBar(
                                        strength: _passStrength),
                                  ],

                                  const SizedBox(height: 20),

                                  // ── Role-specific fields ──────────
                                  AnimatedSwitcher(
                                    duration: const Duration(
                                        milliseconds: 300),
                                    switchInCurve: Curves.easeOut,
                                    switchOutCurve: Curves.easeIn,
                                    transitionBuilder: (child, anim) =>
                                        FadeTransition(
                                      opacity: anim,
                                      child: child,
                                    ),
                                    child: _selectedRole == 'president'
                                        ? _PresidentFields(
                                            key: const ValueKey(
                                                'president'),
                                            aptNameCtrl: _aptNameCtrl,
                                            aptAddressCtrl:
                                                _aptAddressCtrl,
                                            totalFlatsCtrl:
                                                _totalFlatsCtrl,
                                            presidentFlatCtrl:
                                                _presidentFlatCtrl,
                                            aptType: _aptType,
                                            towerCount: _towerCount,
                                            towerNameCtrls:
                                                _towerNameCtrls,
                                            onAptTypeChanged: (t) =>
                                                setState(
                                                    () => _aptType = t),
                                            onTowerCountChanged:
                                                _resizeTowerCtrls,
                                          )
                                        : _ResidentFields(
                                            key: const ValueKey(
                                                'resident'),
                                            aptCodeCtrl: _aptCodeCtrl,
                                            flatCtrl: _flatCtrl,
                                          ),
                                  ),

                                  const SizedBox(height: 24),

                                  Consumer<RegistrationProvider>(
                                    builder: (_, reg, __) => CommonButton(
                                      text: _selectedRole == 'president'
                                          ? 'Create Apartment'
                                          : 'Create Account',
                                      gradient: _selectedRole ==
                                              'president'
                                          ? AppColors.adminGradient
                                          : const [
                                              Color(0xFF1A2A4A),
                                              Color(0xFF2D4A6B),
                                            ],
                                      icon: _selectedRole == 'president'
                                          ? Icons.apartment_outlined
                                          : Icons.person_add_outlined,
                                      isLoading: reg.isLoading,
                                      onPressed: _submit,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

// ── President fields ──────────────────────────────────────────────────────────

class _PresidentFields extends StatelessWidget {
  final TextEditingController aptNameCtrl;
  final TextEditingController aptAddressCtrl;
  final TextEditingController totalFlatsCtrl;
  final TextEditingController presidentFlatCtrl;
  final String aptType;
  final int    towerCount;
  final List<TextEditingController> towerNameCtrls;
  final ValueChanged<String> onAptTypeChanged;
  final ValueChanged<int>    onTowerCountChanged;

  const _PresidentFields({
    super.key,
    required this.aptNameCtrl,
    required this.aptAddressCtrl,
    required this.totalFlatsCtrl,
    required this.presidentFlatCtrl,
    required this.aptType,
    required this.towerCount,
    required this.towerNameCtrls,
    required this.onAptTypeChanged,
    required this.onTowerCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGated = aptType == 'Gated Community';

    final borderColor = isDark
        ? Colors.white.withOpacity(0.35)
        : cs.outline;
    final dropdownDecoration = InputDecoration(
      filled: true,
      fillColor: cs.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.overdue),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.overdue, width: 1.5),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Apartment Details'),

        AppTextField(
          label: 'Apartment Name',
          hint: 'e.g., Sunflower Residency',
          controller: aptNameCtrl,
          focusColor: AppColors.blue,
          textCapitalization: TextCapitalization.words,
          prefixIcon:
              const Icon(Icons.home_work_outlined, size: 20),
          validator: (v) =>
              (v == null || v.trim().isEmpty)
                  ? 'Enter apartment name'
                  : null,
        ),
        const SizedBox(height: 14),

        DropdownButtonFormField<String>(
          value: aptType,
          isExpanded: true,
          decoration: dropdownDecoration.copyWith(
            labelText: 'Apartment Type',
            prefixIcon: IconTheme(
              data: IconThemeData(
                  color: cs.onSurfaceVariant, size: 20),
              child: const Icon(Icons.category_outlined),
            ),
          ),
          items: const ['Apartment', 'Villa', 'Gated Community']
              .map((t) =>
                  DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) {
            if (v != null) onAptTypeChanged(v);
          },
          validator: (v) =>
              v == null ? 'Select apartment type' : null,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 14),

        AppTextField(
          label: 'Apartment Address',
          hint: 'e.g., 123 Main Street, Chennai',
          controller: aptAddressCtrl,
          maxLines: 3,
          focusColor: AppColors.blue,
          textCapitalization: TextCapitalization.sentences,
          validator: (v) =>
              (v == null || v.trim().isEmpty)
                  ? 'Enter apartment address'
                  : null,
        ),

        // ── Towers section (Gated Community only) ──────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: isGated
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _SectionLabel('Towers / Blocks'),

                    DropdownButtonFormField<int>(
                      value: towerCount,
                      isExpanded: true,
                      decoration: dropdownDecoration.copyWith(
                        labelText: 'Number of Towers',
                        prefixIcon: IconTheme(
                          data: IconThemeData(
                              color: cs.onSurfaceVariant,
                              size: 20),
                          child:
                              const Icon(Icons.layers_outlined),
                        ),
                      ),
                      items: List.generate(26, (i) => i + 1)
                          .map((n) => DropdownMenuItem(
                                value: n,
                                child: Text(
                                    '$n ${n == 1 ? "Tower" : "Towers"}'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) onTowerCountChanged(v);
                      },
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...List.generate(
                      towerCount,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppTextField(
                          label: 'Tower ${i + 1} Name',
                          hint: String.fromCharCode(65 + i),
                          controller: towerNameCtrls[i],
                          focusColor: AppColors.blue,
                          prefixIcon: const Icon(
                              Icons.apartment_outlined,
                              size: 20),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Enter tower ${i + 1} name'
                                  : null,
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),

        const SizedBox(height: 14),

        AppTextField(
          label: 'Total Flats',
          hint: 'e.g., 50',
          controller: totalFlatsCtrl,
          keyboardType: TextInputType.number,
          focusColor: AppColors.blue,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          prefixIcon: const Icon(Icons.door_sliding_outlined,
              size: 20),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Enter total flats';
            }
            final n = int.tryParse(v.trim());
            if (n == null || n < 1) {
              return 'Enter a valid number';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        AppTextField(
          label: 'Your Flat Number',
          hint: isGated ? 'e.g., A-101' : 'e.g., 101',
          controller: presidentFlatCtrl,
          focusColor: AppColors.blue,
          prefixIcon:
              const Icon(Icons.door_front_door_outlined, size: 20),
          validator: (v) =>
              (v == null || v.trim().isEmpty)
                  ? 'Enter your flat number'
                  : null,
        ),
      ],
    );
  }
}

// ── Resident fields ───────────────────────────────────────────────────────────

class _ResidentFields extends StatelessWidget {
  final TextEditingController aptCodeCtrl;
  final TextEditingController flatCtrl;

  const _ResidentFields({
    super.key,
    required this.aptCodeCtrl,
    required this.flatCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Apartment Details'),

        AppTextField(
          label: 'Apartment Code',
          hint: 'e.g., SAMH4721',
          controller: aptCodeCtrl,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
                RegExp(r'[A-Za-z0-9]')),
          ],
          focusColor: AppColors.blue,
          prefixIcon:
              const Icon(Icons.vpn_key_outlined, size: 20),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Enter the Apartment Code';
            }
            if (v.trim().length < 4) {
              return 'Apartment Code must be at least 4 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 6),
        Text(
          'The Apartment Code is provided by your apartment president.',
          style: AppTextStyles.caption(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 14),

        AppTextField(
          label: 'Flat Number',
          hint: 'e.g., A-101 or 101',
          controller: flatCtrl,
          textCapitalization: TextCapitalization.characters,
          focusColor: AppColors.blue,
          prefixIcon:
              const Icon(Icons.door_front_door_outlined, size: 20),
          validator: (v) =>
              (v == null || v.trim().isEmpty)
                  ? 'Enter your flat number'
                  : null,
        ),
      ],
    );
  }
}

// ── Password strength bar ─────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final int strength;
  const _PasswordStrengthBar({required this.strength});

  int get _litSegments {
    if (strength <= 1) return 1;
    if (strength == 2) return 2;
    if (strength <= 4) return 3;
    return 4;
  }

  Color get _color {
    if (strength <= 1) return Colors.red;
    if (strength == 2) return Colors.orange;
    if (strength <= 4) return Colors.amber;
    return AppColors.paid;
  }

  String get _label {
    if (strength <= 1) return 'Weak';
    if (strength == 2) return 'Fair';
    if (strength <= 4) return 'Good';
    return 'Strong';
  }

  @override
  Widget build(BuildContext context) {
    final inactive =
        Theme.of(context).colorScheme.surfaceVariant;
    return Row(
      children: [
        ...List.generate(
          4,
          (i) => Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              decoration: BoxDecoration(
                color: i < _litSegments ? _color : inactive,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _color,
          ),
        ),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: AppTextStyles.label(color: cs.primary)),
        ],
      ),
    );
  }
}

// ── Sheet handle ──────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  final ColorScheme cs;
  const _SheetHandle({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
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
}

// ── Success detail row ────────────────────────────────────────────────────────

class _SuccessRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCode;
  final ColorScheme cs;

  const _SuccessRow({
    required this.label,
    required this.value,
    this.isCode = false,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style:
                  AppTextStyles.caption(color: cs.onSurfaceVariant)),
        ),
        Expanded(
          child: isCode
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.blue.withOpacity(0.3)),
                  ),
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.blue,
                      letterSpacing: 3,
                    ),
                  ),
                )
              : Text(value,
                  style: AppTextStyles.bodyMedium(
                      color: cs.onSurface)),
        ),
      ],
    );
  }
}
