<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\JobCompleted;
use App\Events\Realtime\JobPublished;
use App\Http\Controllers\Controller;
use App\Models\Application;
use App\Models\JobPost;
use App\Services\NotificationService;
use App\Services\RealtimeBroadcaster;
use Illuminate\Http\Request;

class JobController extends Controller
{
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    public function index(Request $request)
    {
        // `location` is loaded for JobMatchService's proximity scoring — it
        // falls back to the town centroid when a row has no precise pin, and
        // deliberately won't lazy-load (that would be a query per job).
        $query = JobPost::with(['employer:id,name,avatar,is_verified', 'category', 'skills', 'psgcLocation'])
            ->where('status', 'open');

        /*
            Your own jobs are not work you can take.

            Only a hybrid account ever hits this -- someone who posts jobs and
            also works. Applying to your own job is refused at
            ApplicationController@apply, so leaving it in the feed meant showing
            an Apply button that could only ever fail. The employer already has
            their own posts on /jobs/my, so nothing is lost by keeping this list
            to jobs the viewer could actually do.

            Matches the exclusion the matches endpoint already applies in the
            other direction, where a hybrid is not offered as a match for their
            own job.
        */
        if ($viewer = $request->user()) {
            $query->where('employer_id', '!=', $viewer->id);
        }

        if ($search = $request->get('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('title', 'like', "%{$search}%")
                  ->orWhere('description', 'like', "%{$search}%");
            });
        }

        if ($categoryId = $request->get('category_id')) {
            $query->where('category_id', $categoryId);
        }

        if ($location = $request->get('location')) {
            $query->where('location', 'like', "%{$location}%");
        }

        if ($skillIds = $request->get('skill_ids')) {
            $query->whereHas('skills', fn ($q) => $q->whereIn('skills.id', (array)$skillIds));
        }

        $radius = $request->get('radius_km');
        $nearestFirst = $request->get('sort') === 'nearest';

        /*
            "Jobs near you" was not near you.

            The home screen headed this list with "Open jobs in {city}" while
            the endpoint returned every open job in the country — distance_km
            was computed per job and then never used to filter or order
            anything. Passing radius_km, or sort=nearest, now does what the
            heading claims.

            When either is asked for, the whole result set is scored before
            paging, because a radius applied after paginate(20) would filter
            one arbitrary page rather than the search. Without them the
            original cheap paginate is kept.
        */
        $needsDistancePass = $radius !== null || $nearestFirst;

        $profile = $request->user()?->workerProfile;
        $profile?->load(['skills', 'psgcLocation']);

        $decorate = function (JobPost $job) use ($profile) {
            if (!$profile) return $job;

            $match = \App\Services\JobMatchService::score($job, $profile);
            $job->match_score = $match['score'];
            $job->matched_skills = $match['matched_skills'];
            $job->match_reasons = $match['reasons'];
            // Rounded here so every surface shows the same figure rather
            // than each client picking its own precision.
            $job->distance_km = $match['distance_km'] === null
                ? null
                : round($match['distance_km'], 1);
            return $job;
        };

        if (!$needsDistancePass) {
            $jobs = $query->latest()->paginate(20);
            $jobs->getCollection()->transform($decorate);
            return $this->ok($jobs);
        }

        /*
            No location yet is not an error.

            Somebody who signed up thirty seconds ago has no worker profile,
            and the home feed asks for nearest-first on every load. That used
            to refuse the whole request, so the first thing a new account saw
            was an error telling them to set up something they were on their
            way to set up - with no jobs behind it.

            A sort is a preference. Without somewhere to measure from there is
            nothing to sort by, so the feed comes back in its normal order and
            the app carries on.

            A radius is different and still refuses: "within 10 km" of nowhere
            has no honest answer, and quietly returning the whole country
            would be a worse lie than saying so.
        */
        if (!$profile) {
            if ($radius !== null) {
                return $this->fail(
                    'Set up your worker profile location before filtering jobs by distance.',
                    422
                );
            }

            $jobs = $query->latest()->paginate(20);
            $jobs->getCollection()->transform($decorate);
            return $this->ok($jobs);
        }

        $scored = $query->latest()->get()->map($decorate);

        if ($radius !== null) {
            // A job with no computable position is dropped: "within 10 km"
            // cannot honestly include somewhere unknown.
            $scored = $scored->filter(
                fn (JobPost $j) => $j->distance_km !== null && $j->distance_km <= (float) $radius
            );
        }

        if ($nearestFirst) {
            $scored = $scored->sortBy(fn (JobPost $j) => $j->distance_km ?? PHP_FLOAT_MAX);
        }

        $scored = $scored->values();
        $perPage = 20;
        $page = max(1, (int) $request->input('page', 1));

        return $this->ok([
            'data'         => $scored->forPage($page, $perPage)->values(),
            'current_page' => $page,
            'per_page'     => $perPage,
            'total'        => $scored->count(),
        ]);
    }

    public function store(Request $request)
    {
        $user = $request->user();
        if (!$user->isEmployer()) return $this->fail('Forbidden', 403);

        $data = $request->validate([
            'title'              => ['required', 'string', 'max:255'],
            'description'        => ['required', 'string'],
            'category_id'        => ['required', 'exists:categories,id'],
            'required_skill_ids' => ['nullable', 'array'],
            'required_skill_ids.*' => ['exists:skills,id'],
            'budget_min'         => ['nullable', 'numeric', 'min:0'],
            // gte:budget_min rejects an inverted range, which would otherwise be
            // stored happily and then break every salary filter.
            'budget_max'         => ['nullable', 'numeric', 'min:0', 'gte:budget_min'],
            'budget_period'      => ['required', 'in:daily,hourly,project'],
            'location'           => ['required', 'string', 'max:255'],
            'city'               => ['nullable', 'string', 'max:255'],
            // Required, not nullable: a job without it has no coordinates, so
            // it never appears in "jobs near you", shows no distance, and
            // scores zero for location. It used to save silently that way.
            'location_id'        => ['required', 'exists:locations,id'],
            'latitude'           => ['nullable', 'numeric', 'between:-90,90'],
            'longitude'          => ['nullable', 'numeric', 'between:-180,180'],
            'is_urgent'          => ['nullable', 'boolean'],
            'is_negotiable'      => ['nullable', 'boolean'],
            // At least one job photo, up to 4 — matches the picker's own cap.
            'photos'             => ['required', 'array', 'min:1', 'max:4'],
            'photos.*'           => ['image', 'mimes:jpg,jpeg,png', 'max:5120'],
            /*
                Required on new posts, though the column is nullable for the jobs
                that predate it. A job with no date cannot be checked against a
                worker's other commitments, so an optional date would mean
                auto-withdraw silently does nothing on exactly the jobs that
                skipped it.

                end_date null means a single day — that is the common case and
                should not need filling in. start_time stays optional because
                the hour is usually settled in chat, and requiring it would
                mostly collect a fictional one.
            */
            'start_date'         => ['required', 'date', 'after_or_equal:today'],
            'end_date'           => ['nullable', 'date', 'after_or_equal:start_date'],
            'start_time'         => ['nullable', 'date_format:H:i'],
        ], [
            'budget_max.gte' => 'The maximum budget must be greater than or equal to the minimum budget.',
            'photos.required' => 'Please add at least one photo of the job.',
            'location_id.required' => 'Please pick the job location from the suggestions.',
            'start_date.required' => 'Please choose when the work starts.',
            'start_date.after_or_equal' => 'The start date cannot be in the past.',
            'end_date.after_or_equal' => 'The job cannot end before it starts.',
        ]);

        /*
            The same post arriving twice.

            Reported as jobs appearing in duplicate. The cause is not a double
            tap - the button disables itself - it is the upload taking longer
            than the client waits. Photos are megabytes and mobile data here is
            slow, so the app hits its receive timeout, reports a failure, and
            the employer taps Post again. The first request was never
            cancelled: it finished on the server and wrote a job nobody was
            told about.

            No amount of client-side care fixes that, because from the app's
            side a slow success and a real failure look identical. The server
            is the only side that knows, so the check belongs here.

            Matched on the employer, the title and the start date within five
            minutes. Two genuinely different jobs sharing all three that close
            together does not happen; the same job posted twice by a retry
            always does. The existing job is returned rather than an error, so
            the app shows success and the employer sees exactly one post -
            which is what they intended both times.
        */
        $duplicate = $user->postedJobs()
            ->where('title', $data['title'])
            ->where('start_date', $data['start_date'])
            ->where('created_at', '>=', now()->subMinutes(5))
            ->latest('id')
            ->first();

        if ($duplicate) {
            return $this->ok($duplicate->load(['category', 'skills']), 'Job created', 201);
        }

        $skillIds = $data['required_skill_ids'] ?? [];
        unset($data['required_skill_ids']);

        $photoPaths = array_map(
            fn ($photo) => $photo->store('job_photos', config('filesystems.media')),
            $request->file('photos')
        );
        $data['photos'] = $photoPaths;

        $job = $user->postedJobs()->create(array_merge($data, ['status' => 'open']));

        if ($skillIds) $job->skills()->sync($skillIds);

        app(RealtimeBroadcaster::class)->push(new JobPublished($job));

        /*
            Tell the workers this job actually suits.

            JobPublished is a broadcast to a general channel that refreshes any
            open feed — useful, but it reaches only people already looking at
            the app, and it says nothing about whether the job is relevant to
            them. This is the per-worker half: a real notification, to the
            people it fits, which is what makes a posted job find someone.

            Run inline rather than queued. The events here are all
            ShouldBroadcastNow for the same reason — QUEUE_CONNECTION is
            `database` and no queue worker runs in this deployment, so anything
            pushed onto a queue would simply never be delivered. The cost is
            bounded by the candidate pre-filter and the recipient cap inside
            jobMatched().
        */
        app(NotificationService::class)->jobMatched($job);

        return $this->ok($job->load(['category', 'skills']), 'Job created', 201);
    }

    /**
     * GET /jobs/{job}/matches
     *
     * Workers suited to this job, ranked. Shown to the employer right after
     * posting so they can invite people instead of waiting for applications.
     *
     * Scored by JobMatchService — the same weighting a worker sees when
     * browsing jobs, so the percentage never disagrees between the two views.
     * A worker in the same category is always included even with no exact skill
     * overlap, because they can still do the work.
     */
    public function matches(Request $request, JobPost $job)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);

        $job->load(['skills', 'psgcLocation']);

        $candidates = \App\Models\WorkerProfile::query()
            ->with(['user:id,name,avatar,is_verified,city', 'skills', 'category:id,name', 'psgcLocation'])
            // Never suggest the employer their own worker profile.
            ->where('user_id', '!=', $user->id)
            ->get()
            // Only workers who finished setup are contactable.
            ->filter(fn ($p) => $p->isSetupCompleted());

        $scored = $candidates->map(function ($profile) use ($job) {
            $match = \App\Services\JobMatchService::score($job, $profile);

            return [
                'user_id'        => $profile->user_id,
                'name'           => $profile->user?->name,
                'avatar'         => $profile->user?->avatar,
                'is_verified'    => (bool) $profile->user?->is_verified,
                'location'       => $profile->location,
                'category'       => $profile->category?->name,
                'rating_avg'     => $profile->rating_avg,
                'rating_count'   => $profile->rating_count,
                'skills'         => $profile->skills->pluck('skill_name')->values(),
                'matched_skills' => $match['matched_skills'],
                'match_reasons'  => $match['reasons'],
                'match_score'    => $match['score'],
                'distance_km'    => $match['distance_km'] === null
                    ? null
                    : round($match['distance_km'], 1),
            ];
        })
        // A same-category worker always clears this, even with no exact skill
        // overlap — they can still do the job.
        ->filter(fn ($m) => $m['match_score'] >= \App\Services\JobMatchService::MIN_VISIBLE_SCORE)
        ->sortByDesc('match_score')
        ->take((int) $request->input('limit', 20))
        ->values();

        return $this->ok($scored);
    }

    public function myJobs(Request $request)
    {
        $user = $request->user();
        if (!$user->isEmployer()) return $this->fail('Forbidden', 403);

        /*
            Count the applications, do not trust the counter.

            `jobs_posts.application_count` is a stored tally kept in step by
            hand — incremented on apply, decremented on withdraw, and
            decremented again when a hire cancels a clashing application. Every
            one of those is a chance to drift, and it did: a job whose applicant
            was cancelled by a clash showed "0 applicants" on the card while the
            applicants screen still listed that person, because the list is a
            real query and the card was reading the tally.

            withCount runs the same query the list does, so the two cannot
            disagree. The column stays for now — other screens still read it —
            but this response no longer depends on it being right.
        */
        /*
            Two counts, because the card and the shortcut ask different
            questions.

            `application_count` is everyone who ever applied, in any state, and
            that is the right number on a job card - "this post drew 12 people"
            is true whatever became of them.

            My Activity's Applicants shortcut means something narrower: people
            waiting on a decision from this employer. A job whose three
            applicants were all declined still has an application_count of 3,
            so using it there would badge the shortcut with a 3 and then open
            onto an empty list. Counted separately rather than derived on the
            client, which cannot see the statuses at all - myJobs returns the
            job, never its applications.
        */
        $jobs = $user->postedJobs()
            ->with(['category', 'skills'])
            ->withCount([
                'applications',
                'applications as pending_application_count' => fn ($q) => $q->where('status', 'pending'),
            ])
            ->latest()
            ->get()
            ->map(function ($job) {
                // Overwrite the stored tally with the true figure, under the
                // name the app already reads, so no client change is needed.
                $job->application_count = $job->applications_count;
                return $job;
            });

        /*
            The hire attached to each job, so the card itself can act.

            Reviewing used to live three taps in — My Jobs, Manage, Applicants,
            and only then a Review button — which is why nobody found it. The
            card is where an employer looks when they think "that job is done",
            so the card is where the button belongs. It needs to know who was
            hired and where completion and review stand.

            One query for the whole list, not one per job.
        */
        $hires = Application::whereIn('job_id', $jobs->pluck('id'))
            ->whereIn('status', ['accepted', 'completed'])
            ->with('worker:id,name')
            ->get();

        // So a job card can open the thread directly instead of the whole inbox.
        $threads = \App\Models\Conversation::whereIn('job_id', $jobs->pluck('id'))
            ->where('employer_id', $user->id)
            ->pluck('id', 'worker_id');

        $reviewsGiven = \App\Models\Review::whereIn('job_id', $jobs->pluck('id'))
            ->where('reviewer_id', $user->id)
            ->pluck('reviewee_id', 'job_id');

        $jobs->each(function ($job) use ($hires, $reviewsGiven, $threads) {
            // Only the single-hire case gets a card button. With two people on
            // one job the card cannot say who you mean, so those keep going
            // through the applicants list.
            $forJob = $hires->where('job_id', $job->id);

            $job->hire = $forJob->count() === 1
                ? (function ($hire) use ($reviewsGiven, $job, $threads) {
                    return [
                        'application_id'        => $hire->id,
                        'worker_id'             => $hire->worker_id,
                        'worker_name'           => $hire->worker?->name,
                        'conversation_id'       => $threads[$hire->worker_id] ?? null,
                        'status'                => $hire->status,
                        'employer_completed_at' => $hire->employer_completed_at,
                        'worker_completed_at'   => $hire->worker_completed_at,
                        'i_reviewed_them'       => isset($reviewsGiven[$job->id]),
                    ];
                })($forJob->first())
                : null;

            $job->hire_count = $forJob->count();
        });

        return $this->ok($jobs);
    }

    public function show(Request $request, JobPost $job)
    {
        /*
            index() scopes to open jobs; this did not.

            Route-model binding on {job} meant walking /jobs/1..N returned every
            job ever created — closed, completed, flagged, anyone's — along with
            its address line and coordinates. The owner still needs to open
            their own closed jobs from Manage Jobs, and anyone party to the work
            needs the details after it is filled, so the rule is: open to all,
            otherwise only the employer, the applicants, and the hired worker.
        */
        if ($job->status !== 'open') {
            $user = $request->user();

            $isParty = $user && (
                $job->employer_id === $user->id
                || $job->applications()->where('worker_id', $user->id)->exists()
            );

            if (! $isParty) {
                return $this->fail('Job not found.', 404);
            }
        }

        $job->load(['employer:id,name,avatar,is_verified', 'category', 'skills', 'psgcLocation']);
        $job->employer_information = [
            'employer_id'         => $job->employer_id,
            'name'                => $job->employer->name,
            'verification_status' => $job->employer->is_verified,
            'profile_photo_path'  => $job->employer->avatar,
        ];

        $user = $request->user();

        // Everything the details screen needs to render its Apply/Save state
        // without a second round trip: has this worker already applied, have
        // they saved it, and how well does it match their profile.
        if ($user->workerProfile) {
            $profile = $user->workerProfile;
            $profile->load(['skills', 'psgcLocation']);
            $match = \App\Services\JobMatchService::score($job, $profile);
            $job->match_score = $match['score'];
            $job->matched_skills = $match['matched_skills'];
            $job->match_reasons = $match['reasons'];
            $job->distance_km = $match['distance_km'] === null
                ? null
                : round($match['distance_km'], 1);
        }

        $job->has_applied = $job->applications()->where('worker_id', $user->id)->exists();
        $job->application_status = $job->applications()
            ->where('worker_id', $user->id)
            ->latest()
            ->value('status');
        $job->is_saved = $user->savedJobs()->where('job_id', $job->id)->exists();
        $job->is_own_job = $job->employer_id === $user->id;

        return $this->ok($job);
    }

    public function update(Request $request, JobPost $job)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);
        if ($job->status !== 'open') return $this->fail('Cannot edit job that is not open', 403);

        $data = $request->validate([
            'title'              => ['required', 'string', 'max:255'],
            'description'        => ['required', 'string'],
            'category_id'        => ['required', 'exists:categories,id'],
            'required_skill_ids' => ['nullable', 'array'],
            'required_skill_ids.*' => ['exists:skills,id'],
            'budget_min'         => ['nullable', 'numeric', 'min:0'],
            // gte:budget_min rejects an inverted range, which would otherwise be
            // stored happily and then break every salary filter.
            'budget_max'         => ['nullable', 'numeric', 'min:0', 'gte:budget_min'],
            'budget_period'      => ['nullable', 'in:daily,hourly,project'],
            'location'           => ['required', 'string', 'max:255'],
            'city'               => ['nullable', 'string', 'max:255'],
            'location_id'        => ['nullable', 'exists:locations,id'],
            'latitude'           => ['nullable', 'numeric', 'between:-90,90'],
            'longitude'          => ['nullable', 'numeric', 'between:-180,180'],
            'is_urgent'          => ['nullable', 'boolean'],
            'is_negotiable'      => ['nullable', 'boolean'],
            // Optional here — editing a job doesn't force re-uploading photos.
            'photos'             => ['nullable', 'array', 'max:4'],
            'photos.*'           => ['image', 'mimes:jpg,jpeg,png', 'max:5120'],
            /*
                No after_or_equal:today on edit, unlike store.

                A job posted for today is still editable today, and a job posted
                last week for tomorrow must stay editable without its own start
                date being rejected as "in the past". Blocking that would leave
                the employer unable to fix a typo in the title.

                Nullable rather than required so a job created before this
                feature existed can still be edited without being forced to
                invent a date first.
            */
            'start_date'         => ['nullable', 'date'],
            'end_date'           => ['nullable', 'date', 'after_or_equal:start_date'],
            'start_time'         => ['nullable', 'date_format:H:i'],
        ], [
            'budget_max.gte' => 'The maximum budget must be greater than or equal to the minimum budget.',
            'end_date.after_or_equal' => 'The job cannot end before it starts.',
        ]);

        $skillIds = $data['required_skill_ids'] ?? null;
        unset($data['required_skill_ids']);

        if ($request->hasFile('photos')) {
            $data['photos'] = array_map(
                fn ($photo) => $photo->store('job_photos', config('filesystems.media')),
                $request->file('photos')
            );
        } else {
            unset($data['photos']);
        }

        $job->update($data);
        if ($skillIds !== null) $job->skills()->sync($skillIds);

        return $this->ok($job->load(['category', 'skills']), 'Job updated');
    }

    public function changeStatus(Request $request, JobPost $job)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);

        $request->validate(['status' => ['required', 'in:open,in_progress,completed,closed']]);

        $wasCompleted = $job->status === 'completed';

        /*
            Completion is no longer the employer's alone.

            Marking a job complete used to flip every accepted application to
            'completed' underneath the workers, with no say from them. A review
            is a claim about how the work went, so one party declaring the work
            over and immediately rating the other is a one-sided account of a
            two-sided event.

            So this records the EMPLOYER'S confirmation on each hire and stops
            there. The job reaches 'completed' only once every worker has
            confirmed too — JobCompletionService::settleJob does that, and
            dispatches JobCompleted when it happens, so the notification still
            fires exactly once.
        */
        if (! $wasCompleted && $request->status === 'completed') {
            $service = app(\App\Services\JobCompletionService::class);

            $hires = Application::where('job_id', $job->id)
                ->where('status', 'accepted')
                ->with('job')
                ->get();

            if ($hires->isEmpty()) {
                return $this->fail('There is nobody hired on this job to complete', 422);
            }

            foreach ($hires as $hire) {
                $service->confirm($hire, \App\Services\JobCompletionService::SIDE_EMPLOYER);
            }

            $job->refresh();

            return $this->ok($job, $job->status === 'completed'
                ? 'Both sides confirmed — this job is complete'
                : 'Marked complete. Waiting for the worker to confirm.');
        }

        \Illuminate\Support\Facades\DB::transaction(function () use ($job, $request) {
            $job->update(['status' => $request->status]);

            // Starting the work: the tracking view needs a real timestamp to
            // show a timeline rather than just a badge.
            if ($job->status === 'in_progress') {
                Application::where('job_id', $job->id)
                    ->where('status', 'accepted')
                    ->whereNull('started_at')
                    ->update(['started_at' => now()]);
            }
        });

        return $this->ok($job, 'Status updated');
    }

    public function destroy(Request $request, JobPost $job)
    {
        $user = $request->user();
        if ($job->employer_id !== $user->id) return $this->fail('Forbidden', 403);

        /*
            Give the applicants their credits back first.

            They paid to apply to a job that is now being taken away by the
            person who posted it. Nobody chose that on their side, and keeping
            the money would mean charging people for an opportunity that was
            withdrawn — the most obviously unfair non-refund available and the
            first support message anybody would send.

            Only pending ones. An accepted application has already produced
            what it was bought for.
        */
        $refunded = $this->refundPendingApplicants($job);

        $job->delete();

        return $this->ok(
            ['refunded_applications' => $refunded],
            $refunded > 0
                ? 'Job deleted and ' . $refunded . ' applicant'
                    . ($refunded === 1 ? '' : 's') . ' refunded'
                : 'Job deleted',
        );
    }

    /**
     * Returns the credits of everyone still waiting on this job.
     *
     * Returns how many were actually refunded, so the employer's screen can
     * say what happened rather than quietly moving other people's balances.
     */
    private function refundPendingApplicants(JobPost $job): int
    {
        $charges = \App\Models\CreditTransaction::whereIn(
            'id',
            Application::where('job_id', $job->id)
                ->where('status', 'pending')
                ->pluck('credit_transaction_id')
                ->filter()
                ->all(),
        )->get();

        $ledger = app(\App\Services\CreditLedger::class);
        $refunded = 0;

        foreach ($charges as $charge) {
            // Null means it was already refunded, which is a normal outcome
            // rather than a failure worth reporting.
            if ($ledger->refund($charge, 'the job was removed') !== null) {
                $refunded++;
            }
        }

        return $refunded;
    }

    public function save(Request $request, JobPost $job)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        if ($user->savedJobs()->where('job_id', $job->id)->exists()) {
            return $this->ok(null, 'Job already saved');
        }

        $user->savedJobs()->attach($job->id);
        return $this->ok(null, 'Job saved successfully', 201);
    }

    public function unsave(Request $request, JobPost $job)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        $user->savedJobs()->detach($job->id);
        return $this->ok(null, 'Job unsaved successfully');
    }

    public function savedJobs(Request $request)
    {
        $user = $request->user();
        if (!$user->isWorker()) return $this->fail('Forbidden', 403);

        $jobs = $user->savedJobs()->with(['employer:id,name,avatar,is_verified', 'category', 'skills'])->latest()->get();
        return $this->ok($jobs);
    }
}
