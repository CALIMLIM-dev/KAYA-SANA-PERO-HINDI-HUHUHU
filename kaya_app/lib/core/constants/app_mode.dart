/// Which side of the marketplace the user is currently acting as.
///
/// KAYA is hybrid: one account can hold both a worker and an employer profile.
/// The active mode is a *view* over that account — it decides what the home feed
/// shows and which conversations appear in the inbox. It never grants or removes
/// any ability; that is governed server-side by profile existence.
enum AppMode {
  /// Looking for work. Home shows jobs, activity shows your applications.
  worker,

  /// Looking to hire. Home shows workers, activity shows your job posts.
  employer,

  /*
      Both at once.

      Only reachable by an account that holds both profiles, and only there
      does it mean anything. The point is that a hybrid account is not really
      two accounts taking turns - somebody who lays tiles during the week and
      hires a helper for a big job on Saturday is doing both, and making them
      flip a switch to see the other half of their own week is busywork.

      Worker and employer stay as deliberate narrowings: when you are looking
      for work, a feed full of other workers is noise.
  */
  all;

  /// Stable key used for persistence. Do not rename — it is written to disk.
  String get storageValue => name;

  /// Label shown on the mode toggle.
  String get label => switch (this) {
        AppMode.worker => 'Work',
        AppMode.employer => 'Hire',
        AppMode.all => 'All',
      };

  /// Whether this mode shows the jobs feed and worker-side activity.
  bool get showsWorkerSide => this == AppMode.worker || this == AppMode.all;

  /// Whether this mode shows the workers feed and employer-side activity.
  bool get showsEmployerSide => this == AppMode.employer || this == AppMode.all;

  /// The modes offered to an account, given which profiles it holds.
  ///
  /// One profile means no choice to make, so the toggle has nothing to show
  /// and callers hide it. `all` appears only for an account that genuinely has
  /// both sides — offering it to a worker would be offering a view of nothing.
  static List<AppMode> availableTo({
    required bool hasWorker,
    required bool hasEmployer,
  }) {
    if (hasWorker && hasEmployer) {
      return const [AppMode.worker, AppMode.employer, AppMode.all];
    }
    if (hasWorker) return const [AppMode.worker];
    if (hasEmployer) return const [AppMode.employer];
    return const [];
  }

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
