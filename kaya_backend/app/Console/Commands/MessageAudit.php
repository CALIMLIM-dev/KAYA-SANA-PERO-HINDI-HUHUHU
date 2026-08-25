<?php

namespace App\Console\Commands;

use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\Message;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\WorkerProfile;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;

/*
    Attacks the messaging endpoints.

    Chat is the most sensitive surface in the product. It is where phone
    numbers, addresses and prices get typed, it is the one place two strangers
    talk, and unlike a profile it has no "public" version to fall back on — if
    the wrong person can read a thread, there is no lesser harm to land on.

    So this plays the attacker rather than the user: a third account with a
    valid token tries to read, write into, and mark other people's threads;
    a participant tries to forge who a message came from and where it lands;
    and the payloads are checked for details they were never asked to carry.

    A PASS here means the attempt was refused or neutralised. A HOLE means it
    worked.

        php artisan kaya:message-audit
*/
class MessageAudit extends Command
{
    protected $signature = 'kaya:message-audit {--base=http://127.0.0.1:8000}';

    protected $description = 'Try to read, forge and break into other people conversations';

    private const TAG = '@kaya-message-audit.invalid';

    private string $base;
    private int $passed = 0;
    private array $failures = [];
    private array $notes = [];

    public function handle(): int
    {
        $this->base = rtrim((string) $this->option('base'), '/');

        try {
            [$alice, $aliceToken] = $this->makeUser('Alice Audit');
            [$bob, $bobToken] = $this->makeUser('Bob Audit');
            [$mallory, $malloryToken] = $this->makeUser('Mallory Audit');

            $thread = $this->threadBetween($alice, $bob, 'unlocked');
            $this->seedMessage($thread, $alice, 'Meet me at 14 Rizal Street, 0917 555 0000.');

            $this->section('An outsider with a valid token');
            $this->outsiderIsLockedOut($malloryToken, $thread, $mallory);

            $this->section('Forging a message');
            $this->cannotForgeSender($bobToken, $thread, $alice, $bob);
            $this->cannotRedirectToAnotherThread($bobToken, $thread, $alice, $bob, $mallory);
            $this->cannotPreMarkRead($bobToken, $thread, $bob);

            $this->section('What the payloads give away');
            $this->payloadsCarryNoContactDetails($aliceToken, $thread);

            $this->section('What you are allowed to send');
            $this->inputIsBounded($bobToken, $thread);

            $this->section('Threads that are not open yet');
            $this->lockedThreadRefusesMessages($alice, $mallory, $aliceToken);

            $this->section('Suspended accounts');
            $this->suspendedCannotMessage($bob, $bobToken, $thread);

            $this->section('The socket, which skips all of the above');
            $this->cannotSubscribeToSomeoneElsesChannel(
                $malloryToken, $aliceToken, $thread, $alice, $mallory
            );

            $this->section('Probing for threads that exist');
            $this->enumeration($malloryToken, $thread);
        } catch (\Throwable $e) {
            $this->failures[] = 'aborted: ' . $e->getMessage() . ' @ ' . basename($e->getFile()) . ':' . $e->getLine();
        } finally {
            $this->teardown();
        }

        $this->newLine();
        foreach ($this->notes as $n) {
            $this->line('  <fg=yellow>NOTE</>  ' . $n);
        }
        foreach ($this->failures as $f) {
            $this->line('  <fg=red>HOLE</>  ' . $f);
        }
        $this->line(sprintf('  %d attacks repelled, %d holes', $this->passed, count($this->failures)));

        return $this->failures ? self::FAILURE : self::SUCCESS;
    }

    // ---------------------------------------------------------------- checks

    /**
     * The core case: a signed-in stranger pointed at someone else's thread.
     *
     * Every one of these is a valid, authenticated request. Nothing about the
     * token is wrong — only the conversation id is somebody else's.
     */
    private function outsiderIsLockedOut(string $token, Conversation $thread, User $mallory): void
    {
        $read = $this->api($token)->get("{$this->base}/api/v1/conversations/{$thread->id}/messages");
        $this->ok('cannot read the thread', $read->status() === 403, 'status ' . $read->status());
        $this->ok('and the refusal leaks no message text',
            ! str_contains(strtolower((string) $read->body()), 'rizal'));

        // The polling path is a second entrance to the same room.
        $poll = $this->api($token)
            ->get("{$this->base}/api/v1/conversations/{$thread->id}/messages", ['after_id' => 0]);
        $this->ok('cannot read it through the polling parameter either',
            $poll->status() === 403, 'status ' . $poll->status());
        $this->ok('and that refusal leaks nothing either',
            ! str_contains(strtolower((string) $poll->body()), 'rizal'));

        $send = $this->api($token)
            ->post("{$this->base}/api/v1/conversations/{$thread->id}/messages", [
                'message_text' => 'Pay me here instead.',
            ]);
        $this->ok('cannot post into the thread', $send->status() === 403, 'status ' . $send->status());
        $this->ok('and no message was written',
            Message::where('conversation_id', $thread->id)
                ->where('sender_id', $mallory->id)->doesntExist());

        $read2 = $this->api($token)->patch("{$this->base}/api/v1/conversations/{$thread->id}/read");
        $this->ok('cannot mark the thread read', $read2->status() === 403, 'status ' . $read2->status());

        $this->ok('and the thread is not in their own conversation list',
            ! str_contains(
                (string) $this->api($token)->get("{$this->base}/api/v1/conversations")->body(),
                '"id":' . $thread->id . ','
            ));
    }

    /**
     * sender_id is set from the token, never from the body.
     *
     * If it were fillable from the request, anyone in a thread could put words
     * in the other person's mouth — inside a real conversation, which is far
     * more convincing than any external fake.
     */
    private function cannotForgeSender(string $bobToken, Conversation $thread, User $alice, User $bob): void
    {
        $res = $this->api($bobToken)
            ->post("{$this->base}/api/v1/conversations/{$thread->id}/messages", [
                'message_text' => 'I agree to work for free.',
                'sender_id' => $alice->id,
            ]);

        $written = Message::where('conversation_id', $thread->id)
            ->where('message_text', 'I agree to work for free.')
            ->first();

        $this->ok('a message cannot be attributed to the other person',
            $res->status() === 201 && $written?->sender_id === $bob->id,
            'stored sender_id=' . ($written?->sender_id ?? 'none') . ' expected ' . $bob->id);
    }

    private function cannotRedirectToAnotherThread(
        string $bobToken, Conversation $thread, User $alice, User $bob, User $mallory,
    ): void {
        $other = $this->threadBetween($alice, $mallory, 'unlocked');

        $this->api($bobToken)
            ->post("{$this->base}/api/v1/conversations/{$thread->id}/messages", [
                'message_text' => 'Planted in the wrong thread.',
                'conversation_id' => $other->id,
            ]);

        $this->ok('a message cannot be redirected into a thread you are not in',
            Message::where('conversation_id', $other->id)->doesntExist());
    }

    /**
     * A message that arrives pre-read would never raise the unread badge, so
     * the recipient could be talked to without ever being told.
     */
    private function cannotPreMarkRead(string $bobToken, Conversation $thread, User $bob): void
    {
        $this->api($bobToken)
            ->post("{$this->base}/api/v1/conversations/{$thread->id}/messages", [
                'message_text' => 'Silent delivery.',
                'is_read' => true,
                'read_at' => now()->toDateTimeString(),
            ]);

        $message = Message::where('message_text', 'Silent delivery.')->first();

        $this->ok('a message cannot be sent already marked read',
            $message !== null && ! $message->is_read,
            'is_read=' . var_export($message?->is_read, true));
    }

    private function payloadsCarryNoContactDetails(string $token, Conversation $thread): void
    {
        $forbidden = ['"email"', '"phone"', '"google_id"', 'suspension_note', '"password"'];

        $list = (string) $this->api($token)->get("{$this->base}/api/v1/conversations")->body();
        $found = array_values(array_filter($forbidden, fn ($f) => str_contains($list, $f)));
        $this->ok('the conversation list carries no contact details',
            $found === [], implode(', ', $found));

        $messages = (string) $this->api($token)
            ->get("{$this->base}/api/v1/conversations/{$thread->id}/messages")->body();
        $found = array_values(array_filter($forbidden, fn ($f) => str_contains($messages, $f)));
        $this->ok('the message list carries no contact details',
            $found === [], implode(', ', $found));
    }

    private function inputIsBounded(string $token, Conversation $thread): void
    {
        $send = fn (array $body) => $this->api($token)
            ->post("{$this->base}/api/v1/conversations/{$thread->id}/messages", $body);

        $this->ok('an over-long message is refused',
            $send(['message_text' => str_repeat('a', 2001)])->status() === 422);

        $this->ok('an empty message is refused',
            $send(['message_text' => ''])->status() === 422);

        $this->ok('a missing message is refused',
            $send([])->status() === 422);

        /*
            Whitespace passes `required` and then trims to nothing, so the row
            is stored empty. Not a security issue, but it is a thread anyone can
            fill with blank bubbles, and every one of them pushes a
            notification.
        */
        $blank = $send(['message_text' => "   \n\t  "]);
        if ($blank->status() === 201) {
            $stored = Message::latest('id')->first();
            if (trim((string) $stored?->message_text) === '') {
                $this->note('a whitespace-only message is accepted and stored blank -- it '
                    . 'notifies the other person with an empty body');
            }
        } else {
            $this->ok('a whitespace-only message is refused', true);
        }

        /*
            Message text is data, not markup. The app renders it into a Text
            widget so there is no script engine to reach, but it must still come
            back byte-for-byte rather than half-stripped -- silently mangling
            what someone typed is its own bug.
        */
        $payload = '<script>alert(1)</script> & "quotes" <b>bold</b>';
        $send(['message_text' => $payload]);
        $stored = Message::where('sender_id', '!=', 0)->latest('id')->first();
        $this->ok('markup in a message is stored verbatim, not executed or mangled',
            $stored?->message_text === $payload,
            'stored: ' . substr((string) $stored?->message_text, 0, 60));

        // after_id is cast to int before it reaches the query.
        $injection = $this->api($token)->get(
            "{$this->base}/api/v1/conversations/{$thread->id}/messages",
            ['after_id' => "0 OR 1=1; DROP TABLE messages;--"]
        );
        $this->ok('a hostile after_id does not break the query',
            $injection->status() === 200, 'status ' . $injection->status());
        $this->ok('and the messages table is still there',
            DB::getSchemaBuilder()->hasTable('messages'));
    }

    private function lockedThreadRefusesMessages(User $alice, User $mallory, string $aliceToken): void
    {
        $locked = Conversation::where('pair_low', min($alice->id, $mallory->id))
            ->where('pair_high', max($alice->id, $mallory->id))
            ->first();

        if ($locked === null) {
            $this->note('no thread available to lock -- skipped');

            return;
        }

        $locked->update(['status' => 'locked']);

        $res = $this->api($aliceToken)
            ->post("{$this->base}/api/v1/conversations/{$locked->id}/messages", [
                'message_text' => 'Before the hire.',
            ]);

        $this->ok('a locked thread refuses messages even from a participant',
            $res->status() === 403, 'status ' . $res->status());

        $list = (string) $this->api($aliceToken)->get("{$this->base}/api/v1/conversations")->body();
        $this->ok('and a locked thread is not listed',
            ! str_contains($list, '"id":' . $locked->id . ','));
    }

    private function suspendedCannotMessage(User $bob, string $bobToken, Conversation $thread): void
    {
        $bob->forceFill(['is_suspended' => true])->save();

        $res = $this->api($bobToken)
            ->post("{$this->base}/api/v1/conversations/{$thread->id}/messages", [
                'message_text' => 'Still here.',
            ]);

        $this->ok('a suspended account cannot send, even with a live token',
            $res->status() >= 400, 'status ' . $res->status());

        $this->ok('and a suspended account cannot read the thread',
            $this->api($bobToken)
                ->get("{$this->base}/api/v1/conversations/{$thread->id}/messages")
                ->status() >= 400);

        $bob->forceFill(['is_suspended' => false])->save();
    }

    /**
     * Whether a stranger can tell a conversation exists at all.
     *
     * Route-model binding answers 404 for an id that does not exist and 403 for
     * one that does, which turns the endpoint into a counter of how many
     * conversations the platform holds. It reveals no content and no names, so
     * it is recorded rather than failed -- but it is the kind of thing a panel
     * asks about, and worth knowing the answer to before they do.
     */
    private function enumeration(string $token, Conversation $thread): void
    {
        $existing = $this->api($token)
            ->get("{$this->base}/api/v1/conversations/{$thread->id}/messages")->status();

        $absent = $this->api($token)
            ->get("{$this->base}/api/v1/conversations/999999999/messages")->status();

        if ($existing === $absent) {
            $this->ok('an existing thread is indistinguishable from one that does not exist', true);

            return;
        }

        $this->note("a thread that exists answers {$existing} and one that does not answers "
            . "{$absent}, so a stranger can tell which conversation ids are real. No names "
            . 'or content are exposed, only the count.');
    }

    /*
        Everything above tests the REST endpoints. The socket is a second door
        into the same room, and it does not pass through any of those checks.

        Channel names are guessable -- 'conversation.41' is one integer -- so
        the subscription callback in routes/channels.php is the entire boundary.
        Get it wrong and a stranger receives every message in a thread live,
        while the REST endpoints keep returning a tidy 403 and nothing looks
        wrong at all.

        POST /api/broadcasting/auth is what the client calls before subscribing.
        A signed response means the subscription is permitted, so that is what
        gets attacked here rather than the socket itself.
    */
    private function cannotSubscribeToSomeoneElsesChannel(
        string $malloryToken,
        string $aliceToken,
        Conversation $thread,
        User $alice,
        User $mallory,
    ): void {
        /*
            The null broadcaster answers /broadcasting/auth with a bare 200 and
            never calls the channel callbacks, so every check below would pass
            for the wrong reason -- including one for a conversation that does
            not exist. Refusing to run is the only honest option.

            Nothing broadcasts under this driver either, so the socket is not a
            live attack surface right now. The moment Reverb is switched back on
            it becomes one, and routes/channels.php becomes the entire boundary.
        */
        if (config('broadcasting.default') === 'null') {
            $this->note('the realtime layer is switched off (BROADCAST_CONNECTION=null), so the '
                . 'channel rules cannot be tested and nothing is broadcasting. Re-run this '
                . 'section once Reverb is back on -- it is the only thing standing between a '
                . 'stranger and a live message feed.');

            return;
        }

        $auth = fn (string $token, string $channel) => $this->api($token)
            ->post("{$this->base}/api/broadcasting/auth", [
                'channel_name' => $channel,
                'socket_id' => '1234.5678',
            ]);

        // The control: a real participant must be allowed in, or a channel that
        // refuses everybody would pass every check below for the wrong reason.
        $allowed = $auth($aliceToken, 'private-conversation.' . $thread->id);
        $this->ok('a participant IS allowed to subscribe to their own thread',
            $allowed->status() === 200, 'status ' . $allowed->status());

        $refused = $auth($malloryToken, 'private-conversation.' . $thread->id);
        $this->ok('an outsider cannot subscribe to the thread channel',
            $refused->status() === 403, 'status ' . $refused->status());
        $this->ok('and gets no subscription signature',
            ! str_contains((string) $refused->body(), '"auth"'));

        $feed = $auth($malloryToken, 'private-user.' . $alice->id);
        $this->ok('an outsider cannot subscribe to another person notification feed',
            $feed->status() === 403, 'status ' . $feed->status());

        $own = $auth($malloryToken, 'private-user.' . $mallory->id);
        $this->ok('but they can subscribe to their own feed',
            $own->status() === 200, 'status ' . $own->status());

        // A worker's live GPS trail is the strictest channel in the app.
        $tracking = $auth($malloryToken, 'private-application.1.tracking');
        $this->ok('an outsider cannot subscribe to a live location feed',
            $tracking->status() === 403, 'status ' . $tracking->status());

        $missing = $auth($malloryToken, 'private-conversation.999999999');
        $this->ok('a channel for a thread that does not exist is refused',
            $missing->status() === 403, 'status ' . $missing->status());
    }

    // -------------------------------------------------------------- plumbing

    private function threadBetween(User $a, User $b, string $status): Conversation
    {
        $existing = Conversation::where('pair_low', min($a->id, $b->id))
            ->where('pair_high', max($a->id, $b->id))
            ->first();

        if ($existing !== null) {
            return $existing;
        }

        // conversations.job_id is NOT NULL -- a thread always came from a hire.
        $job = \App\Models\JobPost::create([
            'employer_id' => $a->id,
            'title' => 'Message audit job',
            'description' => 'Created by kaya:message-audit.',
            'budget_min' => 1000,
            'location' => 'Audit',
            'status' => 'open',
        ]);

        return Conversation::create([
            'pair_low' => min($a->id, $b->id),
            'pair_high' => max($a->id, $b->id),
            'employer_id' => $a->id,
            'worker_id' => $b->id,
            'status' => $status,
            'job_id' => $job->id,
        ]);
    }

    private function seedMessage(Conversation $thread, User $sender, string $text): void
    {
        Message::create([
            'conversation_id' => $thread->id,
            'sender_id' => $sender->id,
            'message_text' => $text,
            'is_read' => false,
        ]);
    }

    /** @return array{0: User, 1: string} */
    private function makeUser(string $name): array
    {
        $user = new User();
        $user->forceFill([
            'name' => $name,
            'email' => 'msg-' . uniqid() . self::TAG,
            'password' => Hash::make('audit-only'),
            'user_type' => 'worker',
            'email_verified_at' => now(),
            'terms_accepted' => true,
        ])->save();

        WorkerProfile::create(['user_id' => $user->id]);
        EmployerProfile::create(['user_id' => $user->id]);

        return [$user, $user->createToken('kaya-message-audit')->plainTextToken];
    }

    private function api(string $token)
    {
        return Http::acceptJson()->withToken($token)->timeout(20);
    }

    private function section(string $name): void
    {
        $this->newLine();
        $this->line('  <options=bold>' . $name . '</>');
    }

    private function ok(string $label, bool $passed, string $detail = ''): void
    {
        if ($passed) {
            $this->passed++;
            $this->line('    <fg=green>ok</>   ' . $label);

            return;
        }
        $this->failures[] = $label . ($detail ? ' -- ' . $detail : '');
        $this->line('    <fg=red>NO</>   ' . $label . ($detail ? '  <fg=gray>(' . $detail . ')</>' : ''));
    }

    private function note(string $text): void
    {
        $this->notes[] = $text;
        $this->line('    <fg=yellow>--</>   ' . $text);
    }

    private function teardown(): void
    {
        $this->section('Cleaning up');

        try {
            $ids = User::where('email', 'like', '%' . self::TAG)->pluck('id');
            if ($ids->isEmpty()) {
                $this->ok('nothing to remove', true);

                return;
            }

            $convIds = Conversation::whereIn('pair_low', $ids)
                ->orWhereIn('pair_high', $ids)->pluck('id');
            $jobIds = \App\Models\JobPost::whereIn('employer_id', $ids)->pluck('id');

            DB::transaction(function () use ($ids, $convIds, $jobIds) {
                Message::whereIn('conversation_id', $convIds)->forceDelete();
                Conversation::whereIn('id', $convIds)->forceDelete();
                \App\Models\Application::whereIn('job_id', $jobIds)->forceDelete();
                DB::table('job_skills')->whereIn('job_id', $jobIds)->delete();
                \App\Models\JobPost::whereIn('id', $jobIds)->forceDelete();
                UserNotification::whereIn('user_id', $ids)->forceDelete();
                DB::table('personal_access_tokens')->whereIn('tokenable_id', $ids)->delete();
                WorkerProfile::whereIn('user_id', $ids)->forceDelete();
                EmployerProfile::whereIn('user_id', $ids)->forceDelete();
                User::whereIn('id', $ids)->forceDelete();
            });

            $this->ok('audit accounts, threads and messages removed',
                User::where('email', 'like', '%' . self::TAG)->doesntExist());
        } catch (\Throwable $e) {
            $this->ok('cleanup completed', false, $e->getMessage());
        }
    }
}
