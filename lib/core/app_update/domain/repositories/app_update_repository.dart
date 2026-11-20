import '../entities/app_update_info.dart';
import '../entities/app_update_progress.dart';

abstract class AppUpdateRepository {
  Future<AppUpdateInfo> checkForUpdate();
  Future<void> startFlexibleUpdate();
  Future<void> completeFlexibleUpdate();
  Future<void> performImmediateUpdate();
  Stream<AppUpdateProgress> get progressStream;
}
