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

        $sort = in_array($request->get('sort'), ['oldest', 'discussed'], true)
            ? $request->get('sort')
            : 'recent';

        $posts = CommunityPost::query()
            ->live()
            ->with(['user:id,name,avatar,is_verified', 'user.workerProfile:id,user_id,profile_photo_path',
                    'user.employerProfile:id,user_id,image_path,company_name'])
            ->when(in_array($type, CommunityPost::types(), true),
                fn ($q) => $q->where('type', $type))
            // No category and no place to filter on - see the migration.
            ->when($search !== '', fn ($q) => $q->where(fn ($w) => $w
                ->where('title', 'like', "%{$search}%")
                ->orWhere('body', 'like', "%{$search}%")))
            // One query for every thread's size, not one per row.
            ->withCount(['comments as comments_count' => fn ($q) => $q->live()])
            /*
                Newest first, or oldest, or whatever has been talked about
                most. Three orderings is all a board of a few hundred
                notices needs, and "most discussed" is the one that finds
                the thread worth reading.
            */
            ->when($sort === 'oldest', fn ($q) => $q->oldest('id'))
            ->when($sort === 'discussed', fn ($q) => $q->orderByDesc('comments_count')->latest('id'))
            ->when($sort === 'recent', fn ($q) => $q->latest('id'))
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
                    'user.employerProfile:id,user_id,image_path,company_name'])
            ->withCount(['comments as comments_count' => fn ($q) => $q->live()])
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
            return $this->fail(
                $post->isPending() ? 'This post is not on the board yet.' : 'This post has ended.',
                404,
            );
        }

        $post->load(['user:id,name,avatar,is_verified', 'user.workerProfile:id,user_id,profile_photo_path',
                     'user.employerProfile:id,user_id,image_path,company_name']);

        return $this->ok($this->present($post, $user));
    }

    /*
        Everything said under a notice, oldest first.

        A thread reads top to bottom, so it is not paginated backwards the way
        a chat is. Removed comments are left out rather than shown as a
        tombstone: on a board of five answers, four gaps saying "removed" is
        more alarming than the thing that was removed.
    */
    public function comments(Request $request, CommunityPost $post)
    {
        $user = $request->user();

        if (! $post->isLive() && $post->user_id !== $user->id && ! $user->isAdmin()) {
            return $this->fail('This post is not on the board.', 404);
        }

        $comments = $post->comments()
            ->live()
            ->with(['user:id,name,avatar', 'user.workerProfile:id,user_id,profile_photo_path',
                    'user.employerProfile:id,user_id,image_path'])
            ->orderBy('id')
            ->get()
            ->map(fn ($c) => $this->presentComment($c, $user));

        return $this->ok($comments);
    }

    /*
        Answering in the open.

        Free, unlike the post. The notice is what was paid for; a question
        under it is what makes the notice worth paying for, and charging for
        "magkano po" would empty the thread.

        Read by the same filter chat is - swearing masked, a phone number or
        an app to move to refused. A board is a more public place to leave a
        number than a private thread, not a less public one.
    */
    public function comment(Request $request, CommunityPost $post)
    {
        $user = $request->user();

        if (! $post->isLive()) {
            return $this->fail('This post is not open for comments.', 422);
        }

        $data = $request->validate([
            'body' => ['required', 'string', 'max:500'],
        ]);

        $read = app(\App\Services\MessageFilter::class)->inspect(trim($data['body']));

        $comment = $post->comments()->create([
            'user_id' => $user->id,
            'body'    => $read['text'],
            'status'  => \App\Models\CommunityComment::STATUS_LIVE,
        ]);

        // The poster hears about it. Nobody else does - a thread is not a
        // conversation everybody who ever commented is subscribed to.
        if ($post->user_id !== $user->id) {
            app(\App\Services\NotificationService::class)->communityPostAnswered($post, $user);
        }

        $comment->load(['user:id,name,avatar', 'user.workerProfile:id,user_id,profile_photo_path',
                        'user.employerProfile:id,user_id,image_path']);

        return $this->ok($this->presentComment($comment, $user), 'Posted', 201);
    }

    /*
        Taking back what you said.

        The author of the comment, or the author of the post - somebody's
        notice is their space, and they should not have to report a comment
        to KAYA and wait to get something off it. Marked removed rather than
        deleted, so a report still has something to point at.
    */
    public function removeComment(Request $request, \App\Models\CommunityComment $comment)
    {
        $user = $request->user();
        $comment->loadMissing('post');

        $mine = $comment->user_id === $user->id;
        $myPost = $comment->post?->user_id === $user->id;

        if (! $mine && ! $myPost && ! $user->isAdmin()) {
            return $this->fail('Forbidden', 403);
        }

        if ($comment->isLive()) {
            $comment->update([
                'status'         => \App\Models\CommunityComment::STATUS_REMOVED,
                'removed_reason' => $mine ? 'Deleted by the author' : 'Removed by the poster',
                'removed_by'     => $user->id,
            ]);
        }

        return $this->ok(null, 'Comment removed');
    }

    private function presentComment(\App\Models\CommunityComment $comment, $viewer): array
    {
        return [
            'id'         => $comment->id,
            'body'       => $comment->body,
            'created_at' => $comment->created_at->toIso8601String(),
            'is_mine'    => $viewer !== null && $comment->user_id === $viewer->id,
            'author'     => [
                'id'     => $comment->user_id,
                'name'   => $comment->user?->name,
                'avatar' => $comment->user?->resolvedAvatarUrl(),
            ],
        ];
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
            'type'     => ['required', Rule::in(CommunityPost::types())],
            'title'    => ['required', 'string', 'max:80'],
            'body'     => ['required', 'string', 'max:500'],
            // Up to four. No category and no place: see the migration.
            'photos'   => ['nullable', 'array', 'max:' . CommunityPost::MAX_PHOTOS],
            'photos.*' => ['image', 'mimes:jpg,jpeg,png', 'max:5120'],
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
                return $this->fail(
                    $user->workerProfile?->incompleteMessage('post here') ?? 'Set up your worker profile first.',
                    422
                );
            }
        } elseif ($data['type'] === CommunityPost::TYPE_EMPLOYER) {
            /*
                An ordinary employer, which the board had no room for at
                all. Somebody hiring one person for one afternoon is
                neither a tradesperson advertising nor a company running a
                campaign, and they are most of the people here.
            */
            if (! $user->employerProfile?->setup_completed) {
                return $this->fail('Finish your employer profile before posting here.', 422);
            }
        } else {
            $profile = $user->employerProfile;

            if (! $profile || ! $user->isCompanyEmployer()) {
                return $this->fail('Business notices are for company accounts.', 422);
            }

            $status = $verification->getEmployerVerification($user, $profile);

            if (! ($status['business_verified'] ?? false)) {
                return $this->fail('Your business documents need to be approved before you can post here.', 422);
            }
        }

        /*
            A few posts at a time. The board is a notice board, not a feed one
            account can fill; three covers a worker with three trades.

            Waiting posts count against it. They are going up shortly and the
            cap is about how much of the board one account holds - leaving
            them out would let somebody queue thirty and have the cap apply to
            none of them.
        */
        $live = CommunityPost::where('user_id', $user->id)
            ->where(fn ($q) => $q->live()->orWhere('status', CommunityPost::STATUS_PENDING))
            ->count();

        /*
            One for a free account, three once it has topped up.

            Extra reach on the board is promotion, and promotion is what a
            top-up buys - see the Free vs Top-up checklist.
        */
        $toppedUp = $user->hasToppedUp();
        $cap = $toppedUp ? 3 : 1;

        if ($live >= $cap) {
            return $this->fail($toppedUp
                ? 'You already have three posts up or waiting. Take one down to post another.'
                : 'Free accounts can have one post up at a time. Top up any amount to have up to three.', 422);
        }

        /*
            A business notice costs more; a worker and an ordinary employer
            pay the same. A company advertising is a campaign, and the two
            people looking for one job are not.
        */
        $cost = (int) config($data['type'] === CommunityPost::TYPE_BUSINESS
            ? 'kaya.credits.thread_ad_business'
            : 'kaya.credits.thread_ad_worker');
        $days = (int) config('kaya.community.days');

        $photoPaths = [];

        foreach ($request->file('photos', []) as $file) {
            $photoPaths[] = $file->store('community_photos', config('filesystems.media'));
        }

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

        $attributes = [
            'user_id'     => $user->id,
            'type'        => $data['type'],
            'title'       => $title['text'],
            'body'        => $body['text'],
            'photo_paths' => $photoPaths ?: null,
            /*
                Waiting to be read, not up.

                The board publishes when somebody at KAYA has looked at the
                post. It used to publish on submit and rely on an
                administrator noticing afterwards, which makes the window
                between a bad notice going up and coming down however long
                nobody was watching.

                No end date yet either: the days are paid for and start when
                it goes up, so a post that waits overnight has not spent one
                of them. See the migration.
            */
            'status'      => CommunityPost::STATUS_PENDING,
            'expires_at'  => null,
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
            foreach ($photoPaths as $path) {
                Storage::disk(config('filesystems.media'))->delete($path);
            }
            throw $e;
        }

        $post->load(['user:id,name,avatar,is_verified']);

        return $this->ok(
            $this->present($post, $user),
            'Sent for review. It goes on the board once KAYA has read it — '
                . "usually within a day. Your " . $days . ' days start then.',
            201,
        );
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

        if (in_array($post->status, [CommunityPost::STATUS_LIVE, CommunityPost::STATUS_PENDING], true)) {
            $post->update(['status' => CommunityPost::STATUS_ENDED]);
        }

        return $this->ok(null, 'Post taken down');
    }

    /*
        There is no "message the poster".

        The board is a thread: a notice is answered under it, where
        everybody reading can see the answer. A private message button on
        a public notice is what sent the same question into twenty
        separate inboxes, and it is the shape this rework exists to undo.
    */

    private function present(CommunityPost $post, $viewer): array
    {
        $poster = $post->user;

        return [
            'id'          => $post->id,
            'type'        => $post->type,
            'title'       => $post->title,
            'body'        => $post->body,
            'photo_urls'  => $post->photo_urls,
            'status'      => $post->isLive() ? 'live' : $post->status,
            // Null while it waits to be read: the paid days have not started,
            // so there is no honest number to show yet.
            'expires_at'  => $post->expires_at?->toIso8601String(),
            // Calendar days, so a post made today for a week says 7, not 8.
            'days_left'   => $post->expires_at === null
                ? null
                : max(0, (int) now()->startOfDay()->diffInDays($post->expires_at->copy()->startOfDay(), false)),
            // Why it was refused or taken down, to its author only. Being
            // told no without being told why is the complaint that follows.
            'review_note' => $viewer !== null && $post->user_id === $viewer->id
                ? $post->removed_reason
                : null,
            'comment_count' => $post->comments_count ?? $post->comments()->live()->count(),
            'created_at'  => $post->created_at->toIso8601String(),
            'is_mine'     => $viewer !== null && $post->user_id === $viewer->id,
            'poster'      => [
                'id'           => $poster->id,
                'name'         => $post->type === CommunityPost::TYPE_BUSINESS
                    ? ($poster->employerProfile?->company_name ?: $poster->name)
                    : $poster->name,
                'avatar'       => $poster->resolvedAvatarUrl(),
                'is_verified'  => (bool) $poster->is_verified,
                'verification_state' => $poster->verification_state,
            ],
        ];
    }
}
