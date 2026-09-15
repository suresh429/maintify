import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

// ── JS interop extensions ─────────────────────────────────────────────────────

/// iOS Safari non-standard property — true when launched as installed PWA.
extension _NavigatorStandalone on web.Navigator {
  external bool? get standalone;
}

/// Touch-point count — used to detect iPadOS 13+ on a "desktop" UA.
extension _NavigatorTouchPoints on web.Navigator {
  external int get maxTouchPoints;
}

/// Captured beforeinstallprompt event stored by index.html / app.html.
extension _WindowInstallPrompt on web.Window {
  // ignore: non_constant_identifier_names
  external JSObject? get __pwaInstallPrompt;
  // ignore: non_constant_identifier_names
  external set __pwaInstallPrompt(JSObject? value);
}

/// Trigger the browser-native Android install sheet.
extension _BeforeInstallPromptEvent on JSObject {
  external JSPromise<JSAny?> prompt();
}

// ── Constants ─────────────────────────────────────────────────────────────────

// Bump the version suffix whenever the banner copy or logic changes so that
// users who dismissed the old version see the new one.
const _kDismissKey = 'maintify_pwa_banner_v2';

// Only show the install helper on these public Flutter entry routes.
const _kInstallRoutes = {'/login', '/signup'};

// ── Banner widget ─────────────────────────────────────────────────────────────

/// Web-only — overlays an "Add to Home Screen" guide on iOS Safari, or an
/// Android install button, when:
///   • The browser is iOS Safari (not Chrome/Firefox/embedded)
///   • The app is NOT already running in standalone (installed) mode
///   • The current route is /login or /signup
///   • The user has not already dismissed the banner
class PwaInstallBanner extends StatefulWidget {
  final Widget child;
  const PwaInstallBanner({super.key, required this.child});

  @override
  State<PwaInstallBanner> createState() => _PwaInstallBannerState();
}

class _PwaInstallBannerState extends State<PwaInstallBanner>
    with WidgetsBindingObserver {
  bool _visible = false;
  bool _isIOS = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Defer so Flutter's first frame completes before we read JS state.
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Re-evaluate whenever Flutter pushes a new route (e.g. WebAuthGate → /login).
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    if (!_visible) _evaluate();
    return false; // false = not handled, let Flutter router process it normally
  }

  void _evaluate() {
    // Never show inside the installed PWA.
    if (_isStandalone) return;
    // Only show on public Flutter entry routes.
    if (!_isInstallRoute) return;
    // User already dismissed.
    if (_wasDismissed) return;

    final isiOS = _isIOS_device;
    final isAndroid = _isAndroid_device;

    if (isiOS && _isSafari) {
      setState(() {
        _visible = true;
        _isIOS = true;
      });
    } else if (isAndroid && web.window.__pwaInstallPrompt != null) {
      setState(() {
        _visible = true;
        _isIOS = false;
      });
    }
  }

  // ── Detection helpers ───────────────────────────────────────────────────────

  bool get _isStandalone {
    // iOS Safari standalone flag.
    if (web.window.navigator.standalone == true) return true;
    // Standard CSS media query (Chrome, Firefox, Edge, Samsung, Android PWA).
    try {
      return web.window.matchMedia('(display-mode: standalone)').matches;
    } catch (_) {
      return false;
    }
  }

  bool get _isInstallRoute {
    try {
      return _kInstallRoutes.contains(web.window.location.pathname);
    } catch (_) {
      return false;
    }
  }

  bool get _isIOS_device {
    final ua = web.window.navigator.userAgent.toLowerCase();
    if (ua.contains('iphone') || ua.contains('ipod') || ua.contains('ipad')) {
      return true;
    }
    // iPadOS 13+ may report as macOS but has multi-touch.
    if (ua.contains('macintosh') &&
        web.window.navigator.maxTouchPoints > 1) {
      return true;
    }
    return false;
  }

  bool get _isAndroid_device {
    return web.window.navigator.userAgent.toLowerCase().contains('android');
  }

  /// True only for stock Mobile Safari — not Chrome, Firefox, Opera, or any
  /// embedded in-app browser that cannot trigger Add to Home Screen.
  bool get _isSafari {
    final ua = web.window.navigator.userAgent.toLowerCase();
    // All iOS browsers are WebKit, but only Safari lacks these markers:
    const excluded = [
      'crios',       // Chrome for iOS
      'fxios',       // Firefox for iOS
      'opios',       // Opera for iOS
      'gsa',         // Google Search App
      'fbav',        // Facebook (legacy)
      'fban',        // Facebook (newer)
      'instagram',   // Instagram
      'linkedinapp', // LinkedIn
      'snapchat',    // Snapchat
      'twitter',     // Twitter/X
      'tiktok',      // TikTok
      'line/',       // LINE messenger
      'wv)',         // Generic Android/iOS WebView flag
    ];
    return !excluded.any(ua.contains);
  }

  bool get _wasDismissed {
    try {
      return web.window.localStorage.getItem(_kDismissKey) == '1';
    } catch (_) {
      return false;
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _dismiss() {
    try {
      web.window.localStorage.setItem(_kDismissKey, '1');
    } catch (_) {}
    setState(() => _visible = false);
  }

  Future<void> _triggerAndroidInstall() async {
    final p = web.window.__pwaInstallPrompt;
    if (p == null) return;
    try {
      await p.prompt().toDart;
      web.window.__pwaInstallPrompt = null;
    } catch (_) {}
    _dismiss();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _Banner(
            isIOS: _isIOS,
            onDismiss: _dismiss,
            onAndroidInstall: _isIOS ? null : _triggerAndroidInstall,
          ),
        ),
      ],
    );
  }
}

// ── Banner container ──────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final bool isIOS;
  final VoidCallback onDismiss;
  final Future<void> Function()? onAndroidInstall;

  const _Banner({
    required this.isIOS,
    required this.onDismiss,
    this.onAndroidInstall,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(top: BorderSide(color: Color(0xFF334155))),
          boxShadow: [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: isIOS
                ? _IOSContent(onDismiss: onDismiss)
                : _AndroidContent(
                    onInstall: onAndroidInstall!,
                    onDismiss: onDismiss,
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Shared logo mark ──────────────────────────────────────────────────────────

class _LogoMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFC39A51),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: const Text(
        'M',
        style: TextStyle(
          color: Colors.white,
          fontSize: 23,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

// ── iOS banner ────────────────────────────────────────────────────────────────

/// Shows step-by-step iOS Safari "Add to Home Screen" instructions.
/// iOS Safari does NOT support the beforeinstallprompt API — a native install
/// button cannot trigger the Add to Home Screen sheet programmatically.
class _IOSContent extends StatelessWidget {
  final VoidCallback onDismiss;
  const _IOSContent({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            _LogoMark(),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Install Maintify',
                    style: TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Add to your Home Screen for quick access',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close, color: Color(0xFF64748B), size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Instructions
        Row(
          children: [
            const Icon(Icons.ios_share, color: Color(0xFFC39A51), size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  children: const [
                    TextSpan(text: 'Tap '),
                    TextSpan(
                      text: 'Share',
                      style: TextStyle(
                        color: Color(0xFFF1F5F9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(text: '  →  tap '),
                    TextSpan(
                      text: '"Add to Home Screen"',
                      style: TextStyle(
                        color: Color(0xFFF1F5F9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(text: '  →  tap '),
                    TextSpan(
                      text: '"Add"',
                      style: TextStyle(
                        color: Color(0xFFF1F5F9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Android banner ────────────────────────────────────────────────────────────

class _AndroidContent extends StatefulWidget {
  final Future<void> Function() onInstall;
  final VoidCallback onDismiss;

  const _AndroidContent({
    required this.onInstall,
    required this.onDismiss,
  });

  @override
  State<_AndroidContent> createState() => _AndroidContentState();
}

class _AndroidContentState extends State<_AndroidContent> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LogoMark(),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Install Maintify',
                style: TextStyle(
                  color: Color(0xFFF1F5F9),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Add to your home screen for quick access',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _loading
              ? null
              : () async {
                  setState(() => _loading = true);
                  await widget.onInstall();
                  if (mounted) setState(() => _loading = false);
                },
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFC39A51),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Install',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
        GestureDetector(
          onTap: widget.onDismiss,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(Icons.close, color: Color(0xFF64748B), size: 18),
          ),
        ),
      ],
    );
  }
}
