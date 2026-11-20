enum DownloadStatus {
  idle,
  downloading,
  downloaded,
  installing,
  installed,
  failed,
  canceled,
}

class AppUpdateProgress {
  final DownloadStatus status;
  final double progress; // 0.0–1.0

  const AppUpdateProgress({required this.status, required this.progress});

  static const AppUpdateProgress idle = AppUpdateProgress(
    status: DownloadStatus.idle,
    progress: 0.0,
  );
}
