import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../providers/registration_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/common_button.dart';
import '../../widgets/maintify_logo.dart';

class ResidentSignupScreen extends StatefulWidget {
  const ResidentSignupScreen({super.key});

  @override
  State<ResidentSignupScreen> createState() => _ResidentSignupScreenState();
}

class _ResidentSignupScreenState extends State<ResidentSignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _flatCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;

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
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _flatCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final regProvider = context.read<RegistrationProvider>();
    final notifProvider = context.read<NotificationProvider>();

    final error = await regProvider.registerResident(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passCtrl.text,
      apartmentCode: _codeCtrl.text.trim().toUpperCase(),
      unit: _flatCtrl.text.trim(),
      notifProvider: notifProvider,
    );

    if (!mounted) return;

    if (error != null) {
      AppUtils.showSnackBar(context, error, isError: true);
    } else {
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (ctx) {
        final sheetCs = Theme.of(ctx).colorScheme;
        return Container(
        decoration: BoxDecoration(
          color: sheetCs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: sheetCs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: sheetCs.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hourglass_top_rounded,
                color: sheetCs.primary,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Request Submitted!',
              style: AppTextStyles.heading3(color: sheetCs.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your registration request has been sent to the apartment president for approval. '
              'You will be notified once approved — then you can log in.',
              style: AppTextStyles.bodyMedium(color: sheetCs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            CommonButton(
              text: 'Back to Login',
              gradient: const [Color(0xFF1E3A8A), Color(0xFF06B6D4)],
              icon: Icons.login_rounded,
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
            ),
          ],
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
          // Gradient header
          Container(
            height: MediaQuery.of(context).size.height * 0.30,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF141E30),
                  Color(0xFF243B55),
                ],
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

                      // Back + brand
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
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
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

                      const SizedBox(height: 28),

                      // Form card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1A2A4A),
                                        Color(0xFF2D4A6B),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Resident Sign Up',
                                        style: AppTextStyles.heading3(color: cs.onSurface)),
                                    Text('Join your apartment community',
                                        style: AppTextStyles.bodySmall(color: cs.onSurfaceVariant)),
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
                                    label: 'Full Name',
                                    controller: _nameCtrl,
                                    keyboardType: TextInputType.name,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    focusColor: AppColors.blue,
                                    prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                        size: 20),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Please enter your full name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
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
                                    label: 'Phone Number',
                                    controller: _phoneCtrl,
                                    keyboardType: TextInputType.phone,
                                    focusColor: AppColors.blue,
                                    prefixIcon: const Icon(
                                        Icons.phone_outlined,
                                        size: 20),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Please enter your phone number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  AppTextField(
                                    label: 'Flat Number',
                                    hint: 'e.g., 101, 202',
                                    controller: _flatCtrl,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    focusColor: AppColors.blue,
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
                                    label: 'Apartment Code',
                                    hint: 'e.g., SAMH4721',
                                    controller: _codeCtrl,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    focusColor: AppColors.blue,
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
                                  const SizedBox(height: 16),
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
                                  const SizedBox(height: 16),
                                  AppTextField(
                                    label: 'Confirm Password',
                                    controller: _confirmPassCtrl,
                                    obscureText: _obscureConfirm,
                                    focusColor: AppColors.blue,
                                    prefixIcon: const Icon(
                                        Icons.lock_outline,
                                        size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(
                                          () => _obscureConfirm =
                                              !_obscureConfirm),
                                    ),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Please confirm your password';
                                      }
                                      if (v != _passCtrl.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // Info note
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: cs.primary.withOpacity(isDark ? 0.12 : 0.06),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: cs.primary.withOpacity(isDark ? 0.3 : 0.15)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.info_outline,
                                            size: 16, color: cs.primary),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Your request will be reviewed by the apartment president. '
                                            'You can log in only after approval.',
                                            style: AppTextStyles.caption(
                                                color: cs.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 24),
                                  Consumer<RegistrationProvider>(
                                    builder: (_, reg, __) => CommonButton(
                                      text: 'Submit Request',
                                      gradient: const [
                                        Color(0xFF1A2A4A),
                                        Color(0xFF2D4A6B),
                                      ],
                                      icon: Icons.send_outlined,
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
