// Stub for non-web platforms. On web, overridden by web_navigator_web.dart.
// Import pattern:
//   import '...web_navigator.dart'
//       if (dart.library.html) '...web_navigator_web.dart';

/// No-op on non-web platforms.
/// Mobile logout navigates within Flutter (see each logout handler).
void navigateToStaticLanding() {
  // No-op on Android / iOS / desktop.
}
