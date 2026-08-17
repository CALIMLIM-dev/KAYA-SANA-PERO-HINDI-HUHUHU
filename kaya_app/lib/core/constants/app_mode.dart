/// Which side of the marketplace the user is currently acting as.
///
/// KAYA is hybrid: one account can hold both a worker and an employer profile.
/// The active mode is a *view* over that account — it decides what the home feed
/// shows and which conversations appear in the inbox. It never grants or removes
/// any ability; that is governed server-side by profile existence.
enum AppMode {
  /// Looking for work. Home shows jobs.
  worker,

  /// Looking to hire. Home shows workers.
  employer;

  /// Stable key used for persistence. Do not rename — it is written to disk.
  String get storageValue => name;

  /// Label shown on the mode toggle.
  String get label => switch (this) {
        AppMode.worker => 'Find Work',
        AppMode.employer => 'Hire',
      };

  /// The other side of the toggle.
  AppMode get opposite =>
      this == AppMode.worker ? AppMode.employer : AppMode.worker;

  /// Parses a persisted value. Returns null for unknown/absent input so callers
  /// can fall back to reconciliation rather than guessing a mode.
  static AppMode? fromStorage(String? value) {
    if (value == null) return null;
    for (final mode in AppMode.values) {
      if (mode.storageValue == value) return mode;
    }
    return null;
  }
}
