import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/app_utils.dart';
import '../widgets/app_text_field.dart';
import '../widgets/common_button.dart';
import '../widgets/maintify_logo.dart';

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

    // Show a one-time banner if this session was terminated by another login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      if (auth.sessionExpired) {
        auth.clearSessionExpired();
        AppUtils.showSnackBar(
          context,
          'Signed out — another device logged in with your account.',
          color: Colors.redAccent,
        );
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _forgotEmailCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.login(_emailCtrl.text, _passCtrl.text);
    if (!mounted) return;
    if (success) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (auth.emailNotVerified) {
      auth.clearEmailNotVerified();
      _showEmailNotVerifiedSheet();
    } else {
      AppUtils.showSnackBar(context, auth.error ?? 'Login failed', isError: true);
    }
  }

  void _showEmailNotVerifiedSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool _isSending = false;
        return StatefulBuilder(
          builder: (ctx, setSt) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mark_email_unread_outlined,
                        color: Colors.orange, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text('Email Not Verified',
                      style: AppTextStyles.heading3(
                          color: Theme.of(ctx).colorScheme.onSurface),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    'Please verify your email before logging in.\n'
                    'Check your inbox for a verification link.',
                    style: AppTextStyles.bodySmall(
                        color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  CommonButton(
                    text: 'Resend Verification Email',
                    gradient: const [Color(0xFF1E3A8A), Color(0xFF06B6D4)],
                    icon: Icons.send_outlined,
                    isLoading: _isSending,
                    onPressed: () async {
                      setSt(() => _isSending = true);
                      final auth = context.read<AuthProvider>();
                      final sent = await auth.resendEmailVerification(
                        _emailCtrl.text.trim(),
                        _passCtrl.text,
                      );
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      AppUtils.showSnackBar(
                        context,
                        sent
                            ? 'Verification email sent. Please check your inbox.'
                            : 'Could not send email. Check your credentials.',
                        isError: !sent,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Dismiss',
                        style: AppTextStyles.caption(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    color: Theme.of(ctx).colorScheme.outlineVariant,
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
                      color: Theme.of(ctx).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_reset_rounded,
                        color: Theme.of(ctx).colorScheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reset Password',
                          style: AppTextStyles.subheading(color: Theme.of(ctx).colorScheme.onSurface)),
                      Text('Enter your email to receive a new password',
                          style: AppTextStyles.caption(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
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
                  onPressed: () async {
                    final email = _forgotEmailCtrl.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      AppUtils.showSnackBar(ctx, 'Enter a valid email',
                          isError: true);
                      return;
                    }
                    final auth = context.read<AuthProvider>();
                    final result = await auth.generateForgotPassword(email);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (result == null) {
                      AppUtils.showSnackBar(
                          context, 'No account found with that email.',
                          isError: true);
                    } else {
                      AppUtils.showSnackBar(
                          context,
                          'Password reset email sent to $email.',
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                          const MaintifyLogo(size: 64),
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
                          color: cs.surface,
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
                                style: AppTextStyles.heading2(color: cs.onSurface)),
                            const SizedBox(height: 4),
                            Text('Sign in to continue',
                                style: AppTextStyles.bodyMedium(color: cs.onSurfaceVariant)),
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
                                                color: cs.primary)
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
                     /* Container(
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
                      ),*/

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'New to Maintify?',
                            style: AppTextStyles.caption(
                                color: AppColors.textSecondary),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/signup'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Sign Up',
                              style: AppTextStyles.caption(
                                      color: cs.primary)
                                  .copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Invitation-based activation entry point
                      Center(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.how_to_reg_outlined, size: 16),
                          label: const Text('Activate Existing Apartment'),
                          onPressed: () =>
                              Navigator.pushNamed(context, '/activate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.primary,
                            side: BorderSide(
                                color: cs.primary.withOpacity(0.4)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            textStyle: AppTextStyles.caption()
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          '© 2026 Maintify · All rights reserved',
                          style: AppTextStyles.caption(
                              color: cs.onSurfaceVariant),
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
