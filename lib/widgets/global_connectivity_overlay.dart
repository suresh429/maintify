import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';

/// Wraps the entire widget tree and overlays a floating connectivity card
/// that slides in from the top of the screen.
///
/// **Injection** — [MaterialApp.builder]:
/// ```dart
/// builder: (context, child) =>
///     GlobalConnectivityOverlay(child: child ?? const SizedBox()),
/// ```
///
/// Every route, dialog, and bottom sheet inherits the banner automatically.
class GlobalConnectivityOverlay extends StatefulWidget {
  final Widget child;
  const GlobalConnectivityOverlay({super.key, required this.child});

  @override
  State<GlobalConnectivityOverlay> createState() =>
      _GlobalConnectivityOverlayState();
}

class _GlobalConnectivityOverlayState extends State<GlobalConnectivityOverlay>
    with SingleTickerProviderStateMixin {
  // ── Animation ─────────────────────────────────────────────────────────────

  late final AnimationController _ctrl;

  /// Slides the card in from above the screen (Offset(0,-1) → Offset(0,0)).
  /// The Stack's default Clip.hardEdge hides the card while it is above y=0.
  late final Animation<Offset> _slide;

  /// Fades the card in/out alongside the slide.
  late final Animation<double> _fade;

  // ── State ─────────────────────────────────────────────────────────────────

  bool _showOnline = false; // false = offline card, true = "back online" card
  Timer? _dismissTimer;
  bool? _prevStatus;
  ConnectivityProvider? _prov;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prov = Provider.of<ConnectivityProvider>(context, listen: false);
    if (_prov != prov) {
      _prov?.removeListener(_onChange);
      _prov = prov;
      _prov!.addListener(_onChange);
    }
  }

  void _onChange() {
    final prov = _prov;
    if (prov == null) return;

    final isConnected = prov.isConnected;
    if (_prevStatus == isConnected) return;

    final wasOffline = _prevStatus == false;
    _prevStatus = isConnected;

    if (!isConnected) {
      _dismissTimer?.cancel();
      setState(() => _showOnline = false);
      _ctrl.forward();
    } else if (wasOffline) {
      setState(() => _showOnline = true);
      _ctrl.forward();
      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(milliseconds: 2200), () {
        if (mounted) _ctrl.reverse();
      });
    }
  }

  @override
  void dispose() {
    _prov?.removeListener(_onChange);
    _dismissTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      // Clip.hardEdge (default) hides the card while it is above y = 0,
      // so only the SlideTransition translation is needed — no extra ClipRect.
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: _ConnectivityCard(isOnline: _showOnline),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating connectivity card
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectivityCard extends StatelessWidget {
  final bool isOnline;
  const _ConnectivityCard({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;

    // ── Design tokens ─────────────────────────────────────────────────────
    //
    // Offline  dark  : deep warm-dark card, amber accent
    // Offline  light : white card with amber accent
    // Online   dark  : deep green card, emerald accent
    // Online   light : white card with green accent

    final Color cardBg;
    final Color accentBar;       // 4 dp left accent stripe
    final Color iconBg;          // icon container fill
    final Color iconFg;          // icon colour
    final Color title;
    final Color subtitle;
    final Color cardBorder;
    final Color shadowColor;
    final IconData iconData;
    final String titleText;
    final String? subtitleText;

    if (isOnline) {
      cardBg      = isDark ? const Color(0xFF051F12) : Colors.white;
      accentBar   = isDark ? const Color(0xFF22C55E) : const Color(0xFF16A34A);
      iconBg      = isDark ? const Color(0xFF052E16) : const Color(0xFFDCFCE7);
      iconFg      = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      title       = isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
      subtitle    = title.withValues(alpha: 0.75);
      cardBorder  = isDark
          ? const Color(0xFF166534).withValues(alpha: 0.5)
          : const Color(0xFFBBF7D0);
      shadowColor = isDark
          ? const Color(0xFF000000).withValues(alpha: 0.45)
          : const Color(0xFF16A34A).withValues(alpha: 0.12);
      iconData    = Icons.wifi_rounded;
      titleText   = "You're back online";
      subtitleText = null;
    } else {
      cardBg      = isDark ? const Color(0xFF1A1200) : Colors.white;
      accentBar   = isDark ? const Color(0xFFF59E0B) : const Color(0xFFF59E0B);
      iconBg      = isDark ? const Color(0xFF2D1F00) : const Color(0xFFFFF7ED);
      iconFg      = isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);
      title       = isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);
      subtitle    = isDark
          ? const Color(0xFFFBBF24).withValues(alpha: 0.70)
          : const Color(0xFFB45309);
      cardBorder  = isDark
          ? const Color(0xFF78350F).withValues(alpha: 0.45)
          : const Color(0xFFFED7AA);
      shadowColor = isDark
          ? const Color(0xFF000000).withValues(alpha: 0.50)
          : const Color(0xFFF59E0B).withValues(alpha: 0.14);
      iconData    = Icons.wifi_off_rounded;
      titleText   = 'No Internet Connection';
      subtitleText = 'Please check your internet connection.';
    }

    return Semantics(
      liveRegion: true,
      label: isOnline
          ? 'Internet connection restored'
          : 'No internet connection. Please check your network.',
      child: Padding(
        // topPad: keeps card below the status bar / notch.
        // horizontal 14: the card "floats" away from screen edges.
        // bottom 6: leaves breathing room before app content.
        padding: EdgeInsets.only(
          top: topPad + 6,
          left: 14,
          right: 14,
          bottom: 6,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Left accent stripe ─────────────────────────────
                    Container(width: 4, color: accentBar),

                    // ── Card body ──────────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ── Icon pill ────────────────────────────
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: iconBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(iconData, color: iconFg, size: 18),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // ── Text column ──────────────────────────
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    titleText,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: title,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (subtitleText != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitleText,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: subtitle,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // ── Status dot (offline only) ────────────
                            if (!isOnline) ...[
                              const SizedBox(width: 10),
                              _PulseDot(color: accentBar),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated pulse dot shown in the offline card trailing area
// ─────────────────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: _pulse.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
