import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/app_utils.dart';
import '../widgets/app_text_field.dart';
import '../widgets/common_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  final _forgotEmailCtrl = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  // Quick login options
  static const List<Map<String, String>> _quickLogins = [
    {
      'label': 'Super Admin',
      'email': 'superadmin@test.com',
      'color': '8B5CF6',
      'icon': 'shield',
    },
    {
      'label': 'Admin',
      'email': 'admin@test.com',
      'color': '1E3A8A',
      'icon': 'manage',
    },
    {
      'label': 'Resident',
      'email': 'user@test.com',
      'color': '22C55E',
      'icon': 'person',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
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
    _forgotEmailCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _quickFill(String email) {
    setState(() {
      _emailCtrl.text = email;
      _passCtrl.text = '123456';
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.login(_emailCtrl.text, _passCtrl.text);
    if (!mounted) return;
    if (success) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      AppUtils.showSnackBar(context, auth.error ?? 'Login failed', isError: true);
    }
  }

  void _showForgotPassword() {
    _forgotEmailCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_reset_rounded,
                        color: AppColors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reset Password',
                          style: AppTextStyles.subheading()),
                      Text('Enter your email to receive a new password',
                          style: AppTextStyles.caption()),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppTextField(
                label: 'Registered Email',
                controller: _forgotEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(Icons.email_outlined),
                hint: 'e.g., user@apartment.com',
              ),
              const SizedBox(height: 20),
              StatefulBuilder(
                builder: (stCtx, setSt) => CommonButton(
                  text: 'Reset Password',
                  gradient: const [Color(0xFF1E3A8A), Color(0xFF06B6D4)],
                  onPressed: () {
                    final email = _forgotEmailCtrl.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      AppUtils.showSnackBar(ctx, 'Enter a valid email',
                          isError: true);
                      return;
                    }
                    final auth = context.read<AuthProvider>();
                    final newPass = auth.generateForgotPassword(email);
                    Navigator.pop(ctx);
                    if (newPass == null) {
                      AppUtils.showSnackBar(
                          context, 'No account found with that email.',
                          isError: true);
                    } else {
                      AppUtils.showGeneratedCredentials(
                        context,
                        name: email,
                        email: email,
                        password: newPass,
                        role: 'Reset Password',
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _quickColor(String hex) => Color(int.parse('FF$hex', radix: 16));

  IconData _quickIcon(String icon) {
    switch (icon) {
      case 'shield':
        return Icons.shield_outlined;
      case 'manage':
        return Icons.manage_accounts_outlined;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient header (Professional Dark Navy)
          Container(
            height: MediaQuery.of(context).size.height * 0.38,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF141E30), // top (dark navy)
                  Color(0xFF243B55), // bottom (slightly lighter navy)
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
                      const SizedBox(height: 20),

                      // Brand
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.apartment_rounded,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                AppConstants.appName,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                AppConstants.tagline,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 36),

                      // Card
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
                            Text('Welcome Back',
                                style: AppTextStyles.heading2()),
                            const SizedBox(height: 4),
                            Text('Sign in to continue',
                                style: AppTextStyles.bodyMedium()),
                            const SizedBox(height: 24),

                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  AppTextField(
                                    label: 'Email Address',
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: const Icon(
                                        Icons.email_outlined, size: 20),
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Please enter email';
                                      }
                                      if (!v.contains('@')) {
                                        return 'Enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  AppTextField(
                                    label: 'Password',
                                    controller: _passCtrl,
                                    obscureText: _obscurePass,
                                    prefixIcon: const Icon(
                                        Icons.lock_outline, size: 20),
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
                                        return 'Please enter password';
                                      }
                                      if (v.length < 6) {
                                        return 'Password must be 6+ characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _showForgotPassword,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 4),
                                      ),
                                      child: Text(
                                        'Forgot Password?',
                                        style: AppTextStyles.caption(
                                                color: AppColors.blue)
                                            .copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Consumer<AuthProvider>(
                                    builder: (_, auth, __) => CommonButton(
                                      text: 'Sign In',
                                      gradient: const [
                                        Color(0xFF1E3A8A),
                                        Color(0xFF06B6D4),
                                      ],
                                      isLoading: auth.isLoading,
                                      onPressed: _login,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Quick Login
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.flash_on_outlined,
                                    size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text('Quick Login (Demo)',
                                    style: AppTextStyles.label()),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: _quickLogins.map((q) {
                                final color = _quickColor(q['color']!);
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: GestureDetector(
                                      onTap: () => _quickFill(q['email']!),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12, horizontal: 8),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: color.withOpacity(0.2),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Icon(_quickIcon(q['icon']!),
                                                color: color, size: 22),
                                            const SizedBox(height: 6),
                                            Text(
                                              q['label']!,
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: color,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
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
