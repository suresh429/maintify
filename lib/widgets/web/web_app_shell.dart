import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/role_theme.dart';
import '../../core/responsive/responsive.dart';
import '../../core/utils/web_title.dart';
import '../../providers/auth_provider.dart';
import '../logout_sheet.dart';
import 'web_sidebar.dart';
import 'web_top_bar.dart';

export 'web_sidebar.dart' show WebNavItem;

/// The full desktop application shell: sidebar + top bar + scrollable content.
class WebAppShell extends StatefulWidget {
  final UserRole role;
  final List<WebNavItem> navItems;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  /// The current page body — swapped by the parent on index change.
  final Widget child;

  const WebAppShell({
    super.key,
    required this.role,
    required this.navItems,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.child,
  });

  @override
  State<WebAppShell> createState() => _WebAppShellState();
}

class _WebAppShellState extends State<WebAppShell> {
  late bool _sidebarExpanded;

  // Workaround: properly initialise on first didChangeDependencies call.
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _sidebarExpanded = true; // will be corrected on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setDocumentTitle(_currentTitle);
    });
  }

  String get _currentTitle {
    if (widget.currentIndex < widget.navItems.length) {
      return widget.navItems[widget.currentIndex].label;
    }
    return '';
  }

  @override
  void didUpdateWidget(covariant WebAppShell old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      setDocumentTitle(_currentTitle);
    }
  }

  Future<void> _handleLogout() async {
    final nav = Navigator.of(context);
    final auth = context.read<AuthProvider>();
    final confirm = await showLogoutSheet(context, widget.role);
    if (confirm == true && mounted) {
      auth.logout();
      nav.pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      _initialized = true;
      _sidebarExpanded = Breakpoints.isDesktop(context);
    }

    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar ───────────────────────────────────────────────────────
          WebSidebar(
            role: widget.role,
            navItems: widget.navItems,
            currentIndex: widget.currentIndex,
            onIndexChanged: widget.onIndexChanged,
            expanded: _sidebarExpanded,
            onToggle: () =>
                setState(() => _sidebarExpanded = !_sidebarExpanded),
            onLogout: _handleLogout,
          ),

          // ── Main content area ─────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                // Top bar
                WebTopBar(
                  title: _currentTitle,
                  role: widget.role,
                  onToggleSidebar: () =>
                      setState(() => _sidebarExpanded = !_sidebarExpanded),
                ),

                // Page content — use LayoutBuilder to pass TIGHT constraints
                // (bounded width + height) to the child. This ensures screens
                // using Column+Expanded+ListView work correctly on web without
                // the "Expanded in unbounded height" error. Each screen handles
                // its own scrolling. Max-width is capped at 1440 px.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth.clamp(0.0, 1440.0);
                      return Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: w,
                          height: constraints.maxHeight,
                          child: widget.child,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
