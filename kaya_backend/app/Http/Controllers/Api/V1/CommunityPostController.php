<?php

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\InsufficientCreditsException;
use App\Http\Controllers\Controller;
use App\Models\CommunityPost;
use App\Models\Conversation;
use App\Models\CreditTransaction;
use App\Services\CreditLedger;
use App\Services\EmployerVerificationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

/*
    The community board.

    A worker posts that they are available; a business posts that it is
    hiring. Both pay for a fixed number of days up front, which is the
    whole moderation policy for volume: a notice costs something, so nobody
    posts forty. Reading is free and open to every signed-in account.

    A post is answered by messaging its poster. That opens an ordinary
    conversation with no job behind it, unlocked from the start: the poster
    paid to be contacted, so the rule that a thread needs a hire first does
    not apply here.
*/
class CommunityPostController extends Controller
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
        $type = $request->get('type');
        $search = trim((string) $request->get('search'));

        $posts = CommunityPost::query()
            ->live()
            ->with(['user:id,name,avatar,is_verified', 'user.workerProfile:id,user_id,profile_photo_path',
                    'user.employerProfile:id,user_id,image_path,company_name', 'category:id,name'])
            ->when(in_array($type, [CommunityPost::TYPE_WORKER, CommunityPost::TYPE_BUSINESS], true),
                fn ($q) => $q->where('type', $type))
            ->when($request->filled('category_id'), fn ($q) => $q->where('category_id', $request->integer('category_id')))
            ->when($request->filled('location_id'), function ($q) use ($request) {
                $place = \App\Models\Location::find($request->integer('location_id'));
                $q->whereIn('location_id', $place ? $place->subtreeIds() : [$request->integer('location_id')]);
            })
            ->when($search !== '', fn ($q) => $q->where(fn ($w) => $w
                ->where('title', 'like', "%{$search}%")
                ->orWhere('body', 'like', "%{$search}%")))
            ->latest('id')
            ->paginate(20);

        $posts->getCollection()->transform(fn ($post) => $this->present($post, $request->user()));

        return $this->ok($posts);
    }

    /** What the caller has posted, live or not, newest first. */
    public function mine(Request $request)
    {
        $posts = CommunityPost::query()
            ->where('user_id', $request->user()->id)
            ->with(['user:id,name,avatar,is_verified', 'user.workerProfile:id,user_id,profile_photo_path',
                    'user.employerProfile:id,user_id,image_path,company_name', 'category:id,name'])
            ->latest('id')
            ->take(50)
            ->get()
            ->map(fn ($post) => $this->present($post, $request->user()));

        return $this->ok($posts);
    }

    public function show(Request $request, CommunityPost $post)
    {
        $user = $request->user();

        // A post that is over is still readable by its owner and an admin;
        // to everyone else it is gone.
        if (! $post->isLive() && $post->user_id !== $user->id && ! $user->isAdmin()) {
            return $this->fail('This post has ended.', 404);
        }

        $post->load(['user:id,name,avatar,is_verified', 'user.workerProfile:id,user_id,profile_photo_path',
                     'user.employerProfile:id,user_id,image_path,company_name', 'category:id,name']);

        return $this->ok($this->present($post, $user));
    }

    /** What a post costs before it is written, so the price is on screen first. */
    public function costs()
    {
        return $this->ok([
            'worker'   => (int) config('kaya.credits.thread_ad_worker'),
            'business' => (int) config('kaya.credits.thread_ad_business'),
            'days'     => (int) config('kaya.community.days'),
        ]);
    }

    public function store(Request $request, CreditLedger $ledger, EmployerVerificationService $verification)
    {
        $user = $request->user();

        $data = $request->validate([
            'type'        => ['required', Rule::in([CommunityPost::TYPE_WORKER, CommunityPost::TYPE_BUSINESS])],
            'title'       => ['required', 'string', 'max:80'],
            'body'        => ['required', 'string', 'max:500'],
            'category_id' => ['nullable', 'integer', 'exists:categories,id'],
            'location'    => ['nullable', 'string', 'max:255'],
            'location_id' => ['nullable', 'integer', 'exists:locations,id'],
            'photo'       => ['nullable', 'image', 'mimes:jpg,jpeg,png', 'max:5120'],
        ]);

        /*
            Who may post which kind.

            A worker post needs a worker profile that is set up, because the
            post is an invitation to open that profile. A business post is
            for a verified company only: an individual employer looking for
            somebody posts a job, which is what jobs are for, and a company
            whose documents are not approved yet cannot advertise under a
            name nobody has checked.
        */
        if ($data['type'] === CommunityPost::TYPE_WORKER) {
            if (! $user->workerProfile?->isSetupCompleted()) {
                return $this->fail('Finish your worker profile before posting here.', 422);
            }
        } else {
            $profile = $user->employerProfile;

            if (! $profile || ! $user->isCompanyEmployer()) {
                return $this->fail('Business posts are for company accounts. To find a worker, post a job.', 422);
            }

            $status = $verification->getEmployerVerification($user, $profile);

            if (! ($status['business_verified'] ?? false)) {
                return $this->fail('Your business documents need to be approved before you can post here.', 422);
            }
        }

        // A few live posts at a time. The board is a notice board, not a feed
        // one account can fill; three covers a worker with three trades.
        $live = CommunityPost::where('user_id', $user->id)->live()->count();
        if ($live >= 3) {
            return $this->fail('You already have three live posts. Take one down to post another.', 422);
        }

        $cost = (int) config($data['type'] === CommunityPost::TYPE_WORKER
            ? 'kaya.credits.thread_ad_worker'
            : 'kaya.credits.thread_ad_business');
        $days = (int) config('kaya.community.days');

        $photoPath = $request->hasFile('photo')
            ? $request->file('photo')->store('community_photos', config('filesystems.media'))
            : null;

        /*
            A notice on the board is read by everybody, so it is read by the
            filter twice - once for the headline, once for the body. Same
            rule as chat: swearing masked, contact details refused. A post
            saying "text me on 0917" is the whole board turned into a way
            around the app. See MessageFilter.
        */
        $filter = app(\App\Services\MessageFilter::class);
        $title = $filter->inspect(trim($data['title']));
        $body = $filter->inspect(trim($data['body']));

        foreach ([$title, $body] as $read) {
            if ($read['refusal'] !== null) {
                if ($photoPath) {
                    Storage::disk(config('filesystems.media'))->delete($photoPath);
                }

                return $this->fail($read['refusal'], 422);
            }
        }

        $attributes = [
            'user_id'     => $user->id,
            'type'        => $data['type'],
            'category_id' => $data['category_id'] ?? null,
            'title'       => $title['text'],
            'body'        => $body['text'],
            'photo_path'  => $photoPath,
            'location'    => $data['location'] ?? null,
            'location_id' => $data['location_id'] ?? null,
            'status'      => CommunityPost::STATUS_LIVE,
            'expires_at'  => now()->addDays($days)->endOfDay(),
        ];

        try {
            // The charge and the post are one transaction: the closure runs
            // inside it, and a failure rolls the Barya back with the post.
            $post = $cost > 0
                ? $ledger->charge(
                    $user,
                    $cost,
                    CreditTransaction::REASON_THREAD_AD,
                    function (CreditTransaction $line) use ($attributes) {
                        $post = CommunityPost::create($attributes + ['credit_transaction_id' => $line->id]);
                        $line->update(['reference_type' => 'community_post', 'reference_id' => $post->id]);

                        return $post;
                    },
                )
                : CommunityPost::create($attributes);
        } catch (InsufficientCreditsException $e) {
            if ($photoPath) {
                Storage::disk(config('filesystems.media'))->delete($photoPath);
            }
            throw $e;
        }

        $post->load(['user:id,name,avatar,is_verified', 'category:id,name']);

        return $this->ok($this->present($post, $user), 'Posted', 201);
    }

    /*
        The poster takes it down. No refund: the days already on the board
        were delivered, and a post pulled the same hour it went up is the
        poster's choice, the same rule a boost follows.
    */
    public function destroy(Request $request, CommunityPost $post)
    {
        if ($post->user_id !== $request->user()->id) {
            return $this->fail('Forbidden', 403);
        }

        if ($post->status === CommunityPost::STATUS_LIVE) {
            $post->update(['status' => CommunityPost::STATUS_ENDED]);
        }

        return $this->ok(null, 'Post taken down');
    }

    /*
        Message the poster.

        Finds or opens the pair's one conversation and unlocks it. A worker
        post is answered by somebody hiring, so they take the employer seat;
        a business post is answered by somebody looking for work. The seats
        are rewritten each time, the same way a hire rewrites them, so the
        inbox files the thread under the right mode for both people.
    */
    public function contact(Request $request, CommunityPost $post)
    {
        $user = $request->user();

        if ($post->user_id === $user->id) {
            return $this->fail('This is your own post.', 422);
        }

        if (! $post->isLive()) {
            return $this->fail('This post has ended.', 422);
        }

        [$employerId, $workerId] = $post->type === CommunityPost::TYPE_WORKER
            ? [$user->id, $post->user_id]
            : [$post->user_id, $user->id];

        $conversation = Conversation::firstOrCreate(
            ['pair_low' => min($user->id, $post->user_id), 'pair_high' => max($user->id, $post->user_id)],
            [
                'job_id'            => null,
                'community_post_id' => $post->id,
                'employer_id'       => $employerId,
                'worker_id'         => $workerId,
                'status'            => 'unlocked',
            ],
        );

        // An existing thread keeps its job; only the seats and the lock move.
        $conversation->update([
            'status'            => 'unlocked',
            'community_post_id' => $post->id,
            'employer_id'       => $employerId,
            'worker_id'         => $workerId,
            // The post is live, so the thread is too - including one hidden
            // when an older job between these two finished.
            'archived_at'       => null,
        ]);

        return $this->ok([
            'conversation_id' => $conversation->id,
            'job_id'          => $conversation->job_id,
            'other'           => [
                'id'          => $post->user_id,
                'name'        => $post->user->name,
                'avatar'      => $post->user->resolvedAvatarUrl(),
                'is_verified' => (bool) $post->user->is_verified,
            ],
            'my_role' => $employerId === $user->id ? 'employer' : 'worker',
        ]);
    }

    private function present(CommunityPost $post, $viewer): array
    {
        $poster = $post->user;

        return [
            'id'          => $post->id,
            'type'        => $post->type,
            'title'       => $post->title,
            'body'        => $post->body,
            'photo_url'   => $post->photo_url,
            'category'    => $post->category?->name,
            'category_id' => $post->category_id,
            'location'    => $post->location,
            'location_id' => $post->location_id,
            'status'      => $post->isLive() ? 'live' : $post->status,
            'expires_at'  => $post->expires_at->toIso8601String(),
            // Calendar days, so a post made today for a week says 7, not 8.
            'days_left'   => max(0, (int) now()->startOfDay()->diffInDays($post->expires_at->copy()->startOfDay(), false)),
            'created_at'  => $post->created_at->toIso8601String(),
            'is_mine'     => $viewer !== null && $post->user_id === $viewer->id,
            'poster'      => [
                'id'           => $poster->id,
                'name'         => $post->type === CommunityPost::TYPE_BUSINESS
                    ? ($poster->employerProfile?->company_name ?: $poster->name)
                    : $poster->name,
                'avatar'       => $poster->resolvedAvatarUrl(),
                'is_verified'  => (bool) $poster->is_verified,
            ],
        ];
    }
}
