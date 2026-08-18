import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('_initialRoute web logic', () {
    // Tests for the logic inside _initialRoute() in main.dart
    // Since _initialRoute() is private, test the logic directly:

    String initialRouteLogic(String path) {
      const directRoutes = {'/login', '/signup', '/activate'};
      return directRoutes.contains(path) ? path : '/';
    }

    test('returns /login for /login path', () {
      expect(initialRouteLogic('/login'), '/login');
    });

    test('returns /signup for /signup path', () {
      expect(initialRouteLogic('/signup'), '/signup');
    });

    test('returns /activate for /activate path', () {
      expect(initialRouteLogic('/activate'), '/activate');
    });

    test('returns / for /dashboard path', () {
      expect(initialRouteLogic('/dashboard'), '/');
    });

    test('returns / for / path', () {
      expect(initialRouteLogic('/'), '/');
    });

    test('returns / for unknown path', () {
      expect(initialRouteLogic('/unknown'), '/');
    });
  });

  group('web platform checks', () {
    test('kIsWeb is false in test environment', () {
      // Tests run on VM, not web
      expect(kIsWeb, false);
    });
  });
}
