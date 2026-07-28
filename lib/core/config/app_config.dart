// Central environment configuration.
// Set once at app startup via AppConfig.init (called from main_dev / main_prod).
// All other code reads AppConfig.isDevelopment / AppConfig.isProduction.

enum AppEnvironment { dev, prod }

class AppConfig {
  AppConfig._();

  static AppEnvironment _env = AppEnvironment.prod;

  static void init(AppEnvironment env) => _env = env;

  static AppEnvironment get environment => _env;
  static bool get isDevelopment => _env == AppEnvironment.dev;
  static bool get isProduction  => _env == AppEnvironment.prod;

  /// Human-readable name — used as the Material app title.
  static String get appName => isDevelopment ? 'Maintify Dev' : 'Maintify';
}
