import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/config/app_config.dart';
import '../core/theme/app_text_styles.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/app_utils.dart';
import '../widgets/app_text_field.dart';
import '../widgets/common_button.dart';
import '../widgets/web/auth_web_layout.dart';

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
        bool isSending = false;
        return StatefulBuilder(
          builder: (ctx, setSt) => Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                24, 16, 24, 32 + MediaQuery.of(ctx).viewPadding.bottom),
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
                      color: Colors.orange.withValues(alpha: 0.1),
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
                    isLoading: isSending,
                    onPressed: () async {
                      setSt(() => isSending = true);
                      final auth = context.read<AuthProvider>();
                      final sent = await auth.resendEmailVerification(
                        _emailCtrl.text.trim(),
                        _passCtrl.text,
                      );
                      if (!ctx.mounted) return;
                      AppUtils.showSnackBar(
                        ctx,
                        sent
                            ? 'Verification email sent. Please check your inbox.'
                            : 'Could not send email. Check your credentials.',
                        isError: !sent,
                      );
                      Navigator.pop(ctx);
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
          padding: EdgeInsets.fromLTRB(
            24, 16, 24, 28 + MediaQuery.of(ctx).viewPadding.bottom),
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
                      color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.1),
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
                    if (result == null) {
                      AppUtils.showSnackBar(
                          ctx, 'No account found with that email.',
                          isError: true);
                    } else {
                      AppUtils.showSnackBar(
                          ctx,
                          'Password reset email sent to $email.',
                      );
                    }
                    Navigator.pop(ctx);
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
    final isWebLayout = MediaQuery.sizeOf(context).width >= 600;
    if (isWebLayout) return _buildWebLayout(context);
    return _buildMobileLayout(context);
  }

  Widget _buildWebLayout(BuildContext context) {
    return Scaffold(
      body: AuthWebLayout(
        child: _buildLoginForm(context),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Welcome back',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sign in to your Maintify account',
              style: AppTextStyles.bodyMedium(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            AppTextField(
              label: 'Email Address',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              label: 'Password',
              controller: _passCtrl,
              obscureText: _obscurePass,
              prefixIcon: const Icon(Icons.lock_outline, size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePass = !_obscurePass),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter password';
                if (v.length < 6) return 'Password must be 6+ characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
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
                  style: AppTextStyles.caption(color: cs.primary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Consumer<AuthProvider>(
              builder: (_, auth, __) => CommonButton(
                text: 'Sign In',
                gradient: const [Color(0xFF1E3A8A), Color(0xFF06B6D4)],
                isLoading: auth.isLoading,
                onPressed: _login,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account?",
                  style: AppTextStyles.caption(color: cs.onSurfaceVariant),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Sign Up',
                    style: AppTextStyles.caption(color: cs.primary)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.how_to_reg_outlined, size: 16),
                label: const Text('Activate existing apartment'),
                onPressed: () => Navigator.pushNamed(context, '/activate'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  textStyle: AppTextStyles.caption()
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // Dev quick-login section
            if (AppConfig.isDevelopment) ...[
              const SizedBox(height: 20),
              _WebQuickLoginPanel(
                onSelect: (email, password) {
                  setState(() {
                    _emailCtrl.text = email;
                    _passCtrl.text = password;
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Stack(
        children: [
          // Top portion: apartment image fading into dark scaffold background
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.50,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/background.png', fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.3, 1.0],
                      colors: [Colors.transparent, Color(0xFF0A0F1E)],
                    ),
                  ),
                ),
              ],
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
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1B3E),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Image.asset(
                                'assets/app_logo.png',
                                width: 58,
                                height: 58,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                AppConstants.appName,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                AppConstants.tagline,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.85),
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
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 32,
                              offset: const Offset(0, 14),
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

                      // Quick Login — dev flavor only
                      if (AppConfig.isDevelopment) ...[
                        _QuickLoginPanel(
                          onSelect: (email, password) {
                            setState(() {
                              _emailCtrl.text = email;
                              _passCtrl.text = password;
                            });
                          },
                        ),
                      ],

                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'New to Maintify?',
                            style: AppTextStyles.caption(
                                color: Colors.white70),
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
                                      color: const Color(0xFF60A5FA))
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
                            foregroundColor: Colors.white,
                            side: const BorderSide(
                                color: Colors.white38),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            textStyle: AppTextStyles.caption()
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          '© 2026 Maintify · All rights reserved',
                          style: AppTextStyles.caption(
                              color: Colors.white54),
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

// ── Web Dev Quick Login panel ─────────────────────────────────────────────────

class _WebQuickLoginPanel extends StatefulWidget {
  final void Function(String email, String password) onSelect;
  const _WebQuickLoginPanel({required this.onSelect});

  @override
  State<_WebQuickLoginPanel> createState() => _WebQuickLoginPanelState();
}

class _WebQuickLoginPanelState extends State<_WebQuickLoginPanel> {
  static const _roles = [
    (
      label: 'Admin',
      icon: Icons.admin_panel_settings_outlined,
      color: Color(0xFF8B5CF6),
      email: 'support.maintify@gmail.com',
      password: 'maintify@0606',
    ),
    (
      label: 'President',
      icon: Icons.manage_accounts_outlined,
      color: Color(0xFF3B82F6),
      email: 'president@maintify.demo',
      password: 'Maintify@123',
    ),
    (
      label: 'Resident',
      icon: Icons.person_outline_rounded,
      color: Color(0xFFC39A51),
      email: 'resident@maintify.demo',
      password: 'Maintify@123',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExpansionTile(
      leading: const Icon(Icons.build_outlined, size: 18),
      title: const Text(
        'Developer Quick Login',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant)),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _roles.map((role) {
              return OutlinedButton.icon(
                icon: Icon(role.icon, size: 16, color: role.color),
                label: Text(
                  role.label,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: role.color,
                  ),
                ),
                onPressed: () => widget.onSelect(role.email, role.password),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: role.color.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Dev Quick Login panel ─────────────────────────────────────────────────────

class _QuickLoginPanel extends StatefulWidget {
  final void Function(String email, String password) onSelect;
  const _QuickLoginPanel({required this.onSelect});

  @override
  State<_QuickLoginPanel> createState() => _QuickLoginPanelState();
}

class _QuickLoginPanelState extends State<_QuickLoginPanel> {
  int? _selected;

  static const _roles = [
    (
      label: 'Admin',
      icon: Icons.admin_panel_settings_outlined,
      color: Color(0xFF8B5CF6), // violet
      email: 'support.maintify@gmail.com',
      password: 'maintify@0606',
    ),
    (
      label: 'President',
      icon: Icons.manage_accounts_outlined,
      color: Color(0xFF3B82F6), // blue
      email: 'president@maintify.demo',
      password: 'Maintify@123',
    ),
    (
      label: 'Resident',
      icon: Icons.person_outline_rounded,
      color: Color(0xFFC39A51), // gold
      email: 'resident@maintify.demo',
      password: 'Maintify@123',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 5),
              Text(
                'Quick Login',
                style: AppTextStyles.caption(color: const Color(0xFF94A3B8))
                    .copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'DEV',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF8B5CF6),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(_roles.length, (i) {
              final role = _roles[i];
              final isSelected = _selected == i;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < _roles.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selected = i);
                      widget.onSelect(role.email, role.password);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? role.color.withValues(alpha: 0.15)
                            : const Color(0xFF263045),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? role.color.withValues(alpha: 0.6)
                              : const Color(0xFF334155),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(role.icon,
                              color: isSelected
                                  ? role.color
                                  : const Color(0xFF64748B),
                              size: 22),
                          const SizedBox(height: 6),
                          Text(
                            role.label,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? role.color
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
