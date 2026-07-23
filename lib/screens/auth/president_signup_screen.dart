import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/auth_provider.dart';
import '../../providers/registration_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/common_button.dart';
import '../../widgets/maintify_logo.dart';

/// President Activation Screen — for the SECONDARY flow where the Super Admin
/// has already created the apartment and the president activates it using the
/// invitation email's Apartment Code.
class PresidentSignupScreen extends StatefulWidget {
  const PresidentSignupScreen({super.key});

  @override
  State<PresidentSignupScreen> createState() => _PresidentSignupScreenState();
}

class _PresidentSignupScreenState extends State<PresidentSignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _codeCtrl  = TextEditingController();
  final _unitCtrl  = TextEditingController();

  bool _obscurePass = true;

  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _codeCtrl.dispose();
    _unitCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final regProvider  = context.read<RegistrationProvider>();
    final authProvider = context.read<AuthProvider>();
    final notifProvider = context.read<NotificationProvider>();

    final result = await regProvider.registerPresident(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      apartmentCode: _codeCtrl.text.trim().toUpperCase(),
      unit: _unitCtrl.text.trim(),
      notifProvider: notifProvider,
    );

    if (!mounted) return;

    if (result.error != null) {
      AppUtils.showSnackBar(context, result.error!, isError: true);
      return;
    }

    // Establish session without going through login screen
    await authProvider.loginWithUser(result.user!);

    if (!mounted) return;

    await _showSuccessDialog(
      aptName: result.apt?.name ?? '',
      aptCode: result.apt?.code ?? _codeCtrl.text.trim().toUpperCase(),
      presidentFlat: _unitCtrl.text.trim(),
    );
  }

  Future<void> _showSuccessDialog({
    required String aptName,
    required String aptCode,
    required String presidentFlat,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.paid.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.celebration_rounded,
                      color: AppColors.paid, size: 40),
                ),
                const SizedBox(height: 18),
                Text('Welcome, President!',
                    style: AppTextStyles.heading2(color: cs.onSurface),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('Your apartment account has been activated successfully.',
                    style:
                        AppTextStyles.bodyMedium(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),

                // Details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (aptName.isNotEmpty) ...[
                        _DialogRow(
                            label: 'Apartment Name',
                            value: aptName,
                            cs: cs),
                        const SizedBox(height: 12),
                      ],
                      _DialogRow(
                          label: 'Apartment Code',
                          value: aptCode,
                          isCode: true,
                          cs: cs),
                      const SizedBox(height: 12),
                      _DialogRow(
                          label: 'Your Flat',
                          value: presidentFlat,
                          cs: cs),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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
                          size: 15, color: AppColors.paid),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "We've sent your apartment details and Apartment Code to your registered email address. Please check your inbox for future reference.",
                          style: AppTextStyles.caption(
                              color: AppColors.paid),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                CommonButton(
                  text: 'Continue',
                  gradient: AppColors.adminGradient,
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/dashboard',
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.34,
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
                          const MaintifyLogo(size: 64),
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

                      const SizedBox(height: 32),

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
                                    Text('Enter your invitation code',
                                        style: AppTextStyles.bodySmall(
                                            color: cs.onSurfaceVariant)),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  AppTextField(
                                    label: 'Email Address',
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    focusColor: AppColors.blue,
                                    prefixIcon: const Icon(
                                        Icons.email_outlined,
                                        size: 20),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!v.contains('@')) {
                                        return 'Enter a valid email address';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  AppTextField(
                                    label: 'Apartment Code',
                                    hint: 'e.g., SAMH4721',
                                    controller: _codeCtrl,
                                    focusColor: AppColors.blue,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    prefixIcon: const Icon(
                                        Icons.apartment_outlined,
                                        size: 20),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Please enter the Apartment Code';
                                      }
                                      if (v.trim().length < 4) {
                                        return 'Apartment Code must be at least 4 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'The Apartment Code is in your invitation email.',
                                      style: AppTextStyles.toolTip(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  AppTextField(
                                    label: 'Flat Number',
                                    hint: 'e.g., A-101',
                                    controller: _unitCtrl,
                                    focusColor: AppColors.blue,
                                    keyboardType: TextInputType.text,
                                    prefixIcon: const Icon(
                                        Icons.door_front_door_outlined,
                                        size: 20),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Please enter your flat number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  AppTextField(
                                    label: 'Password',
                                    controller: _passCtrl,
                                    obscureText: _obscurePass,
                                    focusColor: AppColors.blue,
                                    prefixIcon: const Icon(Icons.lock_outline,
                                        size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePass
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(
                                          () => _obscurePass = !_obscurePass),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Please enter a password';
                                      }
                                      if (v.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  Consumer<RegistrationProvider>(
                                    builder: (_, reg, __) => CommonButton(
                                      text: 'Activate Apartment',
                                      gradient: AppColors.adminGradient,
                                      icon: Icons.how_to_reg_outlined,
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

class _DialogRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isCode;
  final ColorScheme cs;

  const _DialogRow({
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
          width: 110,
          child:
              Text(label, style: AppTextStyles.caption(color: cs.onSurfaceVariant)),
        ),
        Expanded(
          child: isCode
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppColors.blue.withOpacity(0.3)),
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
                  style: AppTextStyles.bodyMedium(color: cs.onSurface)),
        ),
      ],
    );
  }
}
