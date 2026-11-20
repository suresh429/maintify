enum AppUpdateStatus { upToDate, optionalUpdate, forceUpdate, unknown }

enum AppUpdateMode { none, flexible, immediate }

class AppUpdateInfo {
  final AppUpdateStatus status;
  final AppUpdateMode mode;
  final int? priority; // 0–5 from Play Console
  final int? stalenessDays;
  final int? availableVersionCode;

  const AppUpdateInfo({
    required this.status,
    required this.mode,
    this.priority,
    this.stalenessDays,
    this.availableVersionCode,
  });

  static const AppUpdateInfo upToDate = AppUpdateInfo(
    status: AppUpdateStatus.upToDate,
    mode: AppUpdateMode.none,
  );
}
