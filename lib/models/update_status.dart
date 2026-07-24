/// Outcome of the version check performed at app startup.
enum UpdateStatus {
  /// Installed version is current — continue normally.
  upToDate,

  /// A newer version exists and [force_update] is false — user may skip.
  optionalUpdate,

  /// A newer version exists and [force_update] is true — user must update.
  forceUpdate,
}
