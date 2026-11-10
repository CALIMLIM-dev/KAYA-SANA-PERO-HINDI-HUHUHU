<?php

namespace App\Services;

use App\Models\Application;
use App\Models\CreditTransaction;
use App\Models\Strike;
use App\Models\SupportMessage;
use App\Models\SupportThread;
use App\Models\User;
use App\Models\Verification;
use Illuminate\Support\Carbon;

/*
    KAYA Assistant's guided menu, the way a shop's help chat works: pick a
    topic, pick the issue, get an answer that already knows your own records,
    with buttons that open the screen to fix it. Then: That Helped, Talk to an
    Agent, or back to the menu.

    No model is asked for any of it. The menu is resources/assistant/flow.php;
    what it reads is the person's own account, never anyone else's.
*/
class SupportFlow
{
    /** Screens an answer can open, by key: [button, app route]. */
    public const ACTIONS = [
        'account_status' => ['Open Account Status', '/account-status'],
        'wallet'         => ['Open My Wallet', '/wallet'],
        'wallet_history' => ['Open Wallet History', '/wallet/history'],
        'applications'   => ['Open My Applications', '/applications'],
        'active'         => ['Open My Active Jobs', '/active'],
        'profile'        => ['Open Profile', '/profile'],
    ];

    public static function greeting(): string
    {
        return (string) config('kaya.assistant.greeting');
    }

    public function __construct(private KayaAssistant $assistant)
    {
    }

    /** The menu as edited on the admin's KAYA Assistant page, else the file. */
    public static function menu(): array
    {
        $edited = config('kaya.assistant.menu');

        return is_array($edited) && $edited !== [] ? $edited : require resource_path('assistant/flow.php');
    }

    /** The topics, as buttons. */
    public static function topicOptions(): array
    {
        return collect(self::menu())
            ->map(fn ($topic, $key) => ['key' => "topic:{$key}", 'label' => $topic['label']])
            ->values()
            ->push(['key' => 'other', 'label' => 'Something Else'])
            ->all();
    }

    /*
        Whether a tap is on the buttons showing now.

        Only the newest line carries buttons, but a slow phone, a double tap
        or the Menu button pressed again sent the same choice over and over,
        and every one wrote another pair of lines. A tap counts when its key
        is on the newest assistant line; Main Menu counts unless the menu is
        already the newest thing. An empty chat takes any first tap.
    */
    public function current(SupportThread $thread, string $key): bool
    {
        $latest = $thread->messages()->where(fn ($q) => $q->whereNull('kind')->orWhere('kind', '!=', 'event'))
            ->latest('id')->first();
        $options = $latest && $latest->from_admin ? array_column((array) ($latest->payload['options'] ?? []), 'key') : [];

        if ($key === 'menu') {
            return $options !== array_column(self::topicOptions(), 'key');
        }

        return $latest === null || in_array($key, $options, true);
    }

    /*
        One tap in the menu. Answers with [what they picked, what the
        assistant said], both saved in the thread. Null for a key that is
        not on the menu.
    */
    public function choose(SupportThread $thread, User $user, string $key): ?array
    {
        $menu = self::menu();

        if ($key === 'menu') {
            return [null, $this->reply($thread, 'What do you need help with?', options: self::topicOptions())];
        }

        if ($key === 'other') {
            return [
                $this->asked($thread, $user, 'Something else'),
                $this->reply($thread, 'Tell me in your own words and I will help. You can also talk to an agent.',
                    options: [['key' => 'agent', 'label' => 'Talk to an Agent']]),
            ];
        }

        if ($key === 'helped') {
            return [
                $this->asked($thread, $user, 'Yes, solved'),
                $this->reply($thread, 'Glad it is sorted. Anything else?', options: [['key' => 'menu', 'label' => 'Main Menu']]),
            ];
        }

        if (str_starts_with($key, 'topic:')) {
            $topic = substr($key, 6);
            if (! isset($menu[$topic]) || $topic === 'bug') {
                return null;
            }

            $options = collect($menu[$topic]['issues'])
                ->map(fn ($issue, $k) => ['key' => "issue:{$topic}.{$k}", 'label' => $issue['label']])
                ->values()
                ->push(['key' => 'menu', 'label' => 'Back'])
                ->all();

            $notice = \App\Models\KnownIssue::forTopic($topic);

            return [
                $this->asked($thread, $user, $menu[$topic]['label']),
                $this->reply($thread, ($notice ? "Known issue: {$notice}\n\n" : '') . 'Which one is it?', options: $options),
            ];
        }

        if (str_starts_with($key, 'issue:') && str_contains($key, '.')) {
            [$topic, $issueKey] = explode('.', substr($key, 6), 2);
            $issue = $menu[$topic]['issues'][$issueKey] ?? null;
            if (! $issue) {
                return null;
            }

            // Remembered for the agent, should they need one.
            $thread->forceFill([
                'topic' => array_key_exists($topic, SupportThread::TOPICS) ? $topic : 'other',
                'issue' => $issue['label'],
            ])->save();

            // Counted by the hour: many people with the same issue at once is a known issue.
            KayaAssistant::bump('issue:' . $topic . '.' . $issueKey . ':' . now('Asia/Manila')->format('H'));

            $read = isset($issue['read']) ? $this->read($user, $issue['read']) : null;
            $body = trim(($read ? $read . "\n\n" : '') . $issue['answer']) . "\n\nDid this solve it?";

            return [
                $this->asked($thread, $user, $issue['label']),
                $this->reply($thread, $body,
                    options: [
                        ['key' => 'helped', 'label' => 'Yes, Solved'],
                        ['key' => 'agent', 'label' => 'No, Talk to an Agent'],
                        ['key' => 'menu', 'label' => 'Ask Something Else'],
                    ],
                    actions: $issue['actions'] ?? [],
                ),
            ];
        }

        return null;
    }

    // ── What the assistant reads: this person's own records only ─────────

    public function read(User $user, string $what): ?string
    {
        $tz = 'Asia/Manila';
        $day = fn ($at) => Carbon::parse($at)->timezone($tz)->format('M j, Y');

        return match ($what) {
            'standing'     => $this->standing($user, $day),
            'wallet'       => $this->wallet($user, $day),
            'verification' => $this->verification($user, $day),
            'hires'        => $this->hires($user),
            'applications' => $this->applications($user),
            default        => null,
        };
    }

    private function standing(User $user, callable $day): string
    {
        $active = Strike::where('user_id', $user->id)->active()->latest('id')->get();

        if ($ban = $active->firstWhere('action', 'ban')) {
            return "Your account is banned for: {$ban->ruleLabel()}." . ($ban->canAppeal() ? ' You can appeal until ' . $day($ban->appealDeadline()) . '.' : '');
        }

        if ($user->is_suspended) {
            $strike = $active->firstWhere('action', 'suspension');

            return 'Your account is suspended'
                . ($user->suspended_until ? ' until ' . Carbon::parse($user->suspended_until)->timezone('Asia/Manila')->format('M j, g:i A') : '')
                . ($strike ? " for: {$strike->ruleLabel()}." : '.')
                . ($strike && $strike->canAppeal() ? ' You can appeal until ' . $day($strike->appealDeadline()) . '.' : '');
        }

        if ($active->isEmpty()) {
            return 'Your account is in good standing. No violations are counting.';
        }

        return 'Violations counting on your account: '
            . $active->map(fn ($s) => "{$s->ruleLabel()} ({$s->actionLabel()})")->implode(', ') . '.';
    }

    private function wallet(User $user, callable $day): string
    {
        $balance = app(CreditLedger::class)->balance($user);
        $lines = ["Your balance is {$balance} Barya."];

        $topup = CreditTransaction::where('user_id', $user->id)->where('reason', CreditTransaction::REASON_TOPUP)->latest('id')->first();
        $lines[] = $topup ? "Your last top-up: {$topup->delta} Barya on {$day($topup->created_at)}." : 'No top-ups yet.';

        $refund = CreditTransaction::where('user_id', $user->id)->where('reason', CreditTransaction::REASON_REFUND)->latest('id')->first();
        if ($refund) {
            $lines[] = "Your last refund: {$refund->delta} Barya on {$day($refund->created_at)}.";
        }

        return implode(' ', $lines);
    }

    private function verification(User $user, callable $day): string
    {
        if ($user->is_verified) {
            return 'Your account is verified.';
        }

        $latest = Verification::where('user_id', $user->id)->latest('id')->first();

        return match ($latest?->status) {
            'pending'  => "Your documents were sent on {$day($latest->created_at)} and are waiting for an admin.",
            'rejected' => "Your documents were refused on {$day($latest->reviewed_at ?? $latest->updated_at)}"
                . ($latest->rejection_reason ? ": {$latest->rejection_reason}." : '.') . ' You can upload again.',
            default    => 'No documents have been sent yet.',
        };
    }

    private function hires(User $user): string
    {
        $hires = Application::with(['job:id,title,employer_id', 'job.employer:id,name', 'worker:id,name'])
            ->where('status', 'accepted')
            ->where(fn ($q) => $q->where('worker_id', $user->id)
                ->orWhereHas('job', fn ($j) => $j->where('employer_id', $user->id)))
            ->latest('id')->take(3)->get();

        if ($hires->isEmpty()) {
            return 'You have no live hires right now.';
        }

        return 'Your live hires: ' . $hires->map(function (Application $a) use ($user) {
            $amWorker = (int) $a->worker_id === (int) $user->id;
            $other = explode(' ', trim((string) ($amWorker ? $a->job?->employer?->name : $a->worker?->name)))[0] ?: 'them';
            $mine = $amWorker ? $a->worker_completed_at : $a->employer_completed_at;
            $theirs = $amWorker ? $a->employer_completed_at : $a->worker_completed_at;

            $state = match (true) {
                (bool) $mine && ! $theirs => "you marked it complete, waiting for {$other}",
                ! $mine && (bool) $theirs => "{$other} marked it complete, tap Mark as Complete if the work is done",
                default                   => 'not marked complete yet',
            };

            return '"' . ($a->job?->title ?? 'a job') . "\" with {$other} ({$state})";
        })->implode('; ') . '.';
    }

    private function applications(User $user): string
    {
        $waiting = Application::where('worker_id', $user->id)->where('status', 'pending')->count();

        return $waiting === 0
            ? 'You have no applications waiting for an answer.'
            : "You have {$waiting} " . ($waiting === 1 ? 'application' : 'applications') . ' waiting for an answer.';
    }

    // ── Lines in the thread ──────────────────────────────────────────────

    private function asked(SupportThread $thread, User $user, string $text): SupportMessage
    {
        return $thread->messages()->create([
            'sender_id' => $user->id, 'from_admin' => false, 'body' => $text,
        ]);
    }

    private function reply(SupportThread $thread, string $body, array $options = [], array $actions = []): SupportMessage
    {
        $message = $thread->messages()->create([
            'sender_id' => null, 'from_admin' => true, 'is_assistant' => true,
            'assistant_model' => 'menu', 'body' => $body,
            'payload' => array_filter([
                'options' => $options,
                'actions' => collect($actions)
                    ->filter(fn ($k) => isset(self::ACTIONS[$k]))
                    ->map(fn ($k) => ['key' => $k, 'label' => self::ACTIONS[$k][0], 'route' => self::ACTIONS[$k][1]])
                    ->values()->all(),
            ]),
        ]);

        $thread->forceFill(['last_message_at' => now()])->save();

        return $message;
    }
}
