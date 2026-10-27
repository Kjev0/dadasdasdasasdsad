/// Platform mechanism behind `StartupManager` (XDG autostart file, HKCU Run
/// registry value).
abstract class AutostartBackend {
  Future<bool> isEnabled();

  /// Creates/overwrites the entry. [startMinimized] appends `--minimized`.
  Future<void> enable({required bool startMinimized});

  /// Removes the entry; no-op when absent.
  Future<void> disable();
}
