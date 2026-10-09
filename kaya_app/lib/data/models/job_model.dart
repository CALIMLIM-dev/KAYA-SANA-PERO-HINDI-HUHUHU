import '../../core/utils/json_parse.dart';
import '../../core/widgets/verification_badge_widget.dart';

/// Job Model for KAYA app
class Job {
  final int id;
  final String title;
  final String company;
  final String? description;
  final String? location;
  final double? salaryMin;
  final double? salaryMax;
  final String salaryPeriod; // 'hour', 'day', 'month'
  final bool isUrgent;
  /// Whether the hirer is verified. Misnamed long ago; it says nothing about
  /// what the job requires.
  final bool requiresVerification;

  /// The hirer's verification_state: verified, verified_business, pending,
  /// unverified. See [employerVerification].
  final String? employerVerificationState;
  final double? distance; // in kilometers

  /// The distance in words, as the server phrased it.
  ///
  /// Sent whenever [distance] is a band rather than a measurement, so
  /// the app does not have to guess which it is holding. See
  /// distanceText in core/utils/format.dart.
  final String? distanceLabel;
  final DateTime? postedAt;
  final bool isActive;

  /// The raw server status: open | in_progress | completed | closed.
  ///
  /// [isActive] only tells you whether it is `open`, which collapses the other
  /// three into one indistinguishable "not active". Screens that need to know
  /// *why* a job is inactive — offering a review only after completion, for
  /// instance — had no way to ask.
  final String status;

  /*
      When the post comes off the feed.

      Null on a post made before job posts had a life at all. The sweep
      that writes the status runs daily and this date is exact, so a
      post can be past due while still saying 'open' - anything deciding
      whether a job is live should read this too.
  */
  final DateTime? expiresAt;

  /// Paid placement, live right now. The feed already orders these
  /// first; this is what lets a card say so.
  final bool isBoosted;

  /*
      Days until it comes down, negative once it is past.

      Rounded up, not truncated: a post with twenty-three hours left has
      a day left, and saying "0 days" about something still on the feed
      reads as a bug. Truncation also made "nine days from now" answer
      eight, because a few microseconds pass between the two clocks.
  */
  int? get daysUntilExpiry {
    if (expiresAt == null) return null;

    return (expiresAt!.difference(DateTime.now()).inHours / 24).ceil();
  }

  final ApplicationStatus? applicationStatus;
  final String? category;
  final List<String> requiredSkills;
  final int applicantCount;

  /// How many people the job is for, and how many are hired so far. The
  /// second is null where the server did not count it (the public feed).
  final int workersNeeded;
  final int? workersFilled;
  bool get isCrew => workersNeeded > 1;

  /// Server-computed match (0-100) for the signed-in worker, from
  /// JobMatchService — same scoring an employer sees on their applicant list.
  /// Null when the account has no worker profile to score against.
  final int? matchScore;
  final List<String> matchedSkills;

  /// Where this job sits for the signed-in worker: 2 holds a required skill
  /// (or, for a job naming none, works in its trade), 1 the trade only, 0
  /// neither. Null without a worker profile. Orders the feed; never shown.
  final int? matchTier;

  /// How many skills the job asks for, and how many of them this worker has.
  final int requiredCount;
  final int matchedCount;

  /*
      What the card says about fit, as a fact rather than a score.

      "72% match" was a number nobody could check, and it could disagree
      with the order the list was in. "You have 1 of 2 required skills" is
      checkable and cannot. Null when there is nothing true to say.
  */
  String? get fitLine {
    if (matchTier == null) return null;
    if (requiredCount > 0) {
      return 'You have $matchedCount of $requiredCount required skill${requiredCount == 1 ? '' : 's'}';
    }
    return matchTier == 2 ? 'Matches your trade' : null;
  }

  final int? jobId;
  final int? categoryId;
  final int? locationId;

  // Populated by GET /jobs/{id} only — the list endpoints don't compute these
  // per-row to keep the query cheap.
  final int? employerId;
  final String? employerAvatar;
  final bool hasApplied;

  /// A pending invitation from this employer for this job.
  ///
  /// The employer already paid to invite, so taking the job costs the worker
  /// nothing - the server refuses to charge for it either way, and this is
  /// what stops the button asking for barya it will not take.
  final bool isInvited;
  final bool isSaved;
  final bool isOwnJob;
  final List<String> photoUrls;

  /// When the work happens.
  ///
  /// [endDate] null means a single day — the common case, and left null rather
  /// than copied from [startDate] so "one day" and "a range one day long" stay
  /// distinguishable. [startTime] null means the hour is still to be agreed in
  /// chat, which is how most of this work is actually arranged.
  final DateTime? startDate;
  final DateTime? endDate;
  final String? startTime;

  /*
      The day the work is due, as the server settled it.

      Not the same as endDate. The post's dates are the employer's plan,
      made before anybody was hired; an accepted schedule proposal in
      the chat is the two of them arranging it afterwards, and that
      wins. JobPost::deadline resolves the two, so the app reads its
      answer rather than picking a date itself and disagreeing with the
      completion gate.

      Null for a post with no dates at all, which predates scheduling.
  */
  final DateTime? deadline;

  /// The schedule as one short line, or null when the job predates scheduling.
  ///
  /// Defined here rather than in each screen so the job card, the details page
  /// and the applications list cannot drift into describing the same dates
  /// differently. Null is returned rather than "Not specified" — a chip that
  /// says nothing is worse than no chip.
  String? get scheduleLabel {
    final start = startDate;
    if (start == null) return null;

    /*
        The deadline closes the range when there is one.

        This read endDate alone, so a card showed the start date and
        nothing else on every post where the end was not filled in - and
        it kept showing the employer's original plan after a pair had
        agreed a different day in the chat. The deadline is the day that
        actually governs the work, and it is the one the completion
        button answers to.
    */
    final end = deadline ?? endDate;
    if (end != null && !_sameDay(end, start)) {
      // Same month reads better collapsed: "Aug 20 – 27", not "Aug 20 – Aug 27".
      return end.year == start.year && end.month == start.month
          ? '${_short(start)} – ${end.day}'
          : '${_short(start)} – ${_short(end)}';
    }

    final time = startTime;
    return time == null ? _short(start) : '${_short(start)}, $time';
  }

  /// The last day of the work: end_date, or start_date for a single-day job.
  DateTime? get lastDay => endDate ?? startDate;

  /*
      Where today falls against the work's own dates.

      Nothing read the dates after posting, so a job for last Saturday looked
      the same as one for next Saturday - open, applicable, "Application
      Pending". The server closes it the morning after; this is the app
      reading the same clock, so the day itself is not a gap.

      Where the status says the job is over, this says nothing - the status
      already says it, and it says it better.
  */
  bool get hasEnded {
    final last = lastDay;
    if (last == null) return false;
    final today = DateTime.now();
    return DateTime(last.year, last.month, last.day)
        .isBefore(DateTime(today.year, today.month, today.day));
  }

  bool get hasStarted {
    final start = startDate;
    if (start == null) return false;
    final today = DateTime.now();
    return !DateTime(start.year, start.month, start.day)
        .isAfter(DateTime(today.year, today.month, today.day));
  }

  /*
      Whether the work was due to be finished by now.

      Mark as complete does not exist before this is true, so finishing a job
      means the work was due to be done rather than somebody tapping a button
      on the afternoon they were hired. The last day itself counts - work
      finishes during the day, and neither side should wait for midnight to
      say so.

      A job with no dates predates scheduling and is not held to a deadline.
      The server applies the same rule in JobPost::deadlineHasArrived.
  */
  bool get completionHasOpened {
    final last = lastDay;
    if (last == null) return true;

    final today = DateTime.now();

    return !DateTime(last.year, last.month, last.day)
        .isAfter(DateTime(today.year, today.month, today.day));
  }

  /// The line a card carries while Mark as complete is still to come.
  String? get deadlineNote {
    final last = lastDay;

    return last == null || completionHasOpened
        ? null
        : 'Due ${_short(last)} · mark complete opens that day';
  }

  /// "Starts Aug 20" / "Ends Aug 27" / "Ended Aug 27", or null with no dates.
  String? get phaseLabel {
    final start = startDate, last = lastDay;
    if (start == null || last == null) return null;
    if (hasEnded) return 'Ended ${_short(last)}';
    if (!hasStarted) return 'Starts ${_short(start)}';
    return _sameDay(start, last) ? 'Today' : 'Ends ${_short(last)}';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _short(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }

  const Job({
    required this.id,
    required this.title,
    required this.company,
    this.description,
    this.location,
    this.salaryMin,
    this.salaryMax,
    this.salaryPeriod = 'project',
    this.isUrgent = false,
    this.requiresVerification = false,
    this.employerVerificationState,
    this.distance,
    this.distanceLabel,
    this.postedAt,
    this.isActive = true,
    this.status = '',
    this.expiresAt,
    this.isBoosted = false,
    this.applicationStatus,
    this.category,
    this.requiredSkills = const [],
    this.applicantCount = 0,
    this.workersNeeded = 1,
    this.workersFilled,
    this.matchScore,
    this.matchedSkills = const [],
    this.matchTier,
    this.requiredCount = 0,
    this.matchedCount = 0,
    this.jobId,
    this.categoryId,
    this.locationId,
    this.employerId,
    this.employerAvatar,
    this.hasApplied = false,
    this.isInvited = false,
    this.isSaved = false,
    this.isOwnJob = false,
    this.photoUrls = const [],
    this.startDate,
    this.endDate,
    this.startTime,
    this.deadline,
  });

  /// Maps a raw `jobs_posts` row from the Laravel API (GET /jobs, /jobs/my,
  /// /jobs/{id}) to this model. The mock `fromJson` above expects different
  /// field names ('company', 'salary_min', 'posted_at') that the real API
  /// never sends, so it silently produced blank cards if pointed at live data.
  factory Job.fromApi(Map<String, dynamic> json) {
    double? asDouble(Object? v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

    final category = json['category'] as Map<String, dynamic>?;
    final employer = json['employer'] as Map<String, dynamic>?;
    // GET /jobs/{id} nests the same info under employer_information instead.
    final employerInfo = json['employer_information'] as Map<String, dynamic>?;
    final skills = json['skills'] as List?;

    final status = (json['application_status'] as String?);

    return Job(
      id: json['id'] as int,
      title: (json['title'] ?? '').toString(),
      company: (employer?['name'] ?? employerInfo?['name'] ?? '').toString(),
      description: json['description'] as String?,
      location: (json['city'] ?? json['location']) as String?,
      salaryMin: asDouble(json['budget_min']),
      salaryMax: asDouble(json['budget_max']),
      salaryPeriod: (json['budget_period'] as String?) ?? 'project',
      isUrgent: json['is_urgent'] as bool? ?? false,
      requiresVerification: (employer?['is_verified'] as bool?) ??
          (employerInfo?['verification_status'] as bool?) ??
          false,
      employerVerificationState: (employer?['verification_state'] ??
          employerInfo?['verification_state']) as String?,
      postedAt:
          json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      // Sent as plain Y-m-d — the server casts these as dates, not datetimes,
      // so there is no midnight here to be mistaken for a start time. Jobs
      // posted before scheduling existed have null and render without a date
      // rather than with a made-up one.
      startDate: DateTime.tryParse((json['start_date'] ?? '').toString()),
      endDate: DateTime.tryParse((json['end_date'] ?? '').toString()),
      deadline: DateTime.tryParse((json['deadline'] ?? '').toString()),
      // MySQL TIME arrives as "08:30:00"; the seconds are never meaningful
      // here. Trimmed by splitting rather than by substring, which would throw
      // on anything shorter than five characters.
      startTime: () {
        final raw = json['start_time'] as String?;
        if (raw == null || raw.isEmpty) return null;
        final parts = raw.split(':');
        return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : raw;
      }(),
      isActive: json['status'] == 'open',
      status: (json['status'] ?? '').toString(),
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.tryParse(json['expires_at'].toString())?.toLocal(),
      // The subquery answers 1 or null, not a boolean.
      isBoosted: json['is_boosted'] == true || json['is_boosted'] == 1,
      category: category?['name'] as String?,
      categoryId: category?['id'] as int? ?? json['category_id'] as int?,
      locationId: json['location_id'] as int?,
      // Straight-line km from the signed-in worker, computed server-side by
      // JobMatchService. Null when either side has no coordinates.
      distance: asDoubleOrNull(json['distance_km']),
      distanceLabel: json['distance_label'] as String?,
      requiredSkills: skills == null
          ? const []
          : skills
              .map((s) => (s as Map<String, dynamic>)['name']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList(),
      applicantCount: (json['application_count'] as num?)?.toInt() ?? 0,
      workersNeeded: (json['workers_needed'] as num?)?.toInt() ?? 1,
      workersFilled: (json['workers_filled'] as num?)?.toInt(),
      matchScore: (json['match_score'] as num?)?.toInt(),
      matchTier: (json['match_tier'] as num?)?.toInt(),
      requiredCount: (json['required_count'] as num?)?.toInt() ?? 0,
      matchedCount: (json['matched_count'] as num?)?.toInt() ?? 0,
      matchedSkills: (json['matched_skills'] as List?)
              ?.map((s) => s.toString())
              .toList() ??
          const [],
      employerId: (employerInfo?['employer_id'] ?? json['employer_id']) as int?,
      /*
          Three shapes, one field.

          The detail endpoint nests it under employer_information as
          profile_photo_path, the feed sends employer_avatar alongside the
          job, and the embedded employer relation carries a plain avatar.
          Reading only the first meant every card in the feed was faceless.
      */
      employerAvatar: (employerInfo?['profile_photo_path'] ??
          json['employer_avatar'] ??
          employer?['avatar']) as String?,
      hasApplied: json['has_applied'] as bool? ?? (status != null),
      isInvited: json['is_invited'] as bool? ?? false,
      applicationStatus: status == null
          ? null
          : ApplicationStatus.values.firstWhere(
              (e) => e.name == status,
              orElse: () => ApplicationStatus.pending,
            ),
      isSaved: json['is_saved'] as bool? ?? false,
      isOwnJob: json['is_own_job'] as bool? ?? false,
      photoUrls: (json['photo_urls'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      title: json['title'],
      company: json['company'],
      description: json['description'],
      location: json['location'],
      salaryMin: json['salary_min']?.toDouble(),
      salaryMax: json['salary_max']?.toDouble(),
      salaryPeriod: json['salary_period'] ?? 'day',
      isUrgent: json['is_urgent'] ?? false,
      requiresVerification: json['requires_verification'] ?? false,
      employerVerificationState: json['employer_verification_state'] as String?,
      distance: json['distance_km']?.toDouble(),
      distanceLabel: json['distance_label'] as String?,
      postedAt: json['posted_at'] != null ? DateTime.parse(json['posted_at']) : null,
      isActive: json['is_active'] ?? true,
      applicationStatus: json['application_status'] != null
          ? ApplicationStatus.values.firstWhere(
              (e) => e.name == json['application_status'],
              orElse: () => ApplicationStatus.pending,
            )
          : null,
      category: json['category'],
      requiredSkills: List<String>.from(json['required_skills'] ?? []),
      applicantCount: json['applicant_count'] ?? 0,
    );
  }

  VerificationState get employerVerification => VerificationState.of({
        'verification_state': employerVerificationState,
        'is_verified': requiresVerification,
      });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'company': company,
      'description': description,
      'location': location,
      'salary_min': salaryMin,
      'salary_max': salaryMax,
      'salary_period': salaryPeriod,
      'is_urgent': isUrgent,
      'requires_verification': requiresVerification,
      'employer_verification_state': employerVerificationState,
      'distance_km': distance,
      'distance_label': distanceLabel,
      'posted_at': postedAt?.toIso8601String(),
      'is_active': isActive,
      'application_status': applicationStatus?.name,
      'category': category,
      'required_skills': requiredSkills,
      'applicant_count': applicantCount,
    };
  }

  Job copyWith({
    int? id,
    String? title,
    String? company,
    String? description,
    String? location,
    double? salaryMin,
    double? salaryMax,
    String? salaryPeriod,
    bool? isUrgent,
    bool? requiresVerification,
    double? distance,
    String? distanceLabel,
    DateTime? postedAt,
    bool? isActive,
    bool? isSaved,
    ApplicationStatus? applicationStatus,
    String? category,
    List<String>? requiredSkills,
    int? applicantCount,
    int? workersNeeded,
    int? workersFilled,
  }) {
    return Job(
      id: id ?? this.id,
      title: title ?? this.title,
      company: company ?? this.company,
      description: description ?? this.description,
      location: location ?? this.location,
      salaryMin: salaryMin ?? this.salaryMin,
      salaryMax: salaryMax ?? this.salaryMax,
      salaryPeriod: salaryPeriod ?? this.salaryPeriod,
      isUrgent: isUrgent ?? this.isUrgent,
      requiresVerification: requiresVerification ?? this.requiresVerification,
      employerVerificationState: employerVerificationState,
      distance: distance ?? this.distance,
      distanceLabel: distanceLabel ?? this.distanceLabel,
      postedAt: postedAt ?? this.postedAt,
      isActive: isActive ?? this.isActive,
      isSaved: isSaved ?? this.isSaved,
      applicationStatus: applicationStatus ?? this.applicationStatus,
      category: category ?? this.category,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      applicantCount: applicantCount ?? this.applicantCount,
      workersNeeded: workersNeeded ?? this.workersNeeded,
      workersFilled: workersFilled ?? this.workersFilled,
    );
  }
}

enum ApplicationStatus {
  pending,
  accepted,
  rejected,
  withdrawn,
  // The server has sent this since completion became two-sided, and the
  // parser's fallback for an unknown value is `pending` - so every finished
  // job in History opened to a button saying "Application Pending".
  completed,
  // Set by the server when a post ends or is closed with the application
  // still open, and when a hire elsewhere clashes. Missing here, so it
  // fell back to pending and read as "Application Pending" on a job that
  // was over.
  cancelled,
}