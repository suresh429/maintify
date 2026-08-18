import 'package:web/web.dart' as web;

/// Hard browser navigation to the static landing page at /.
/// On web, / is served as index.html (static site), NOT the Flutter app.
/// This breaks out of the Flutter SPA and loads the static page.
void navigateToStaticLanding() {
  web.window.location.replace('/');
}
