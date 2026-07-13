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

class PresidentSignupScreen extends StatefulWidget {
  const PresidentSignupScreen({super.key});

  @override
  State<PresidentSignupScreen> createState() => _PresidentSignupScreenState();
}

class _PresidentSignupScreenState extends State<PresidentSignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();

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
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _codeCtrl.dispose();
    _unitCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final regProvider = context.read<RegistrationProvider>();
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
    } else {
      // President is now registered and signed in — send to login
      // so AuthProvider's normal login flow resolves the session properly.
      _showSuccessAndGoToLogin();
    }
  }

  void _showSuccessAndGoToLogin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.paid.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.paid,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Registration Complete!',
              style: AppTextStyles.heading3(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You have successfully registered as the apartment president. '
              'Please log in with your email and password to access your dashboard.',
              style: AppTextStyles.bodyMedium(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            CommonButton(
              text: 'Go to Login',
              gradient: AppColors.adminGradient,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient header
          Container(
            height: MediaQuery.of(context).size.height * 0.34,
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
                          Image.asset(
                            'assets/app_logo.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                          ),
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

                      // Form card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
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
                                      colors: AppColors.adminGradient,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.manage_accounts_outlined,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('President Sign Up',
                                        style: AppTextStyles.heading3()),
                                    Text('Register as apartment president',
                                        style: AppTextStyles.bodySmall()),
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
                                      'The Apartment Code is provided by your Super Admin.',
                                      style: AppTextStyles.toolTip(),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  AppTextField(
                                    label: 'Flat Number',
                                    hint: 'e.g., 101',
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
                                  const SizedBox(height: 24),
                                  Consumer<RegistrationProvider>(
                                    builder: (_, reg, __) => CommonButton(
                                      text: 'Register as President',
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
