<?php

namespace App\Services;

use App\Models\AdminAction;
use App\Models\CreditPackage;
use App\Models\CreditPayment;
use App\Models\SystemSetting;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/*
    Top-ups paid to KAYA's GCash QR (BILLING_MODE=gcash).

    The person scans the QR, pays the package's price in GCash, and sends the
    GCash reference number with a screenshot of the receipt. The Barya is
    added at once - nobody approves it - and the payment stays "unchecked"
    until an admin compares it with the GCash history:

      received      it stays, nothing else happens
      not received  the Barya is taken back, the top-up stops counting as
                    premium, and (unless the admin unticks it) a Scam or
                    fraud violation is given, which is a ban on the first

    What keeps a fake reference number from paying off: only verified
    accounts can top up, each reference number works once, and a person has
    one unchecked top-up at a time, so a fake gets one package at most before
    it is found.
*/
class GcashTopUp
{
    public const QR_SETTING = 'payments.gcash_qr';
    public const NAME_SETTING = 'payments.gcash_name';

    public function __construct(
        private CreditPurchase $purchase,
        private CreditLedger $ledger,
        private StrikeService $strikes,
        private NotificationService $notify,
    ) {}

    public static function enabled(): bool
    {
        return config('kaya.credits.billing') === 'gcash';
    }

    /** Open for top-ups: the mode is on and an admin has put up the QR. */
    public static function open(): bool
    {
        return self::enabled() && filled(SystemSetting::get(self::QR_SETTING));
    }

    public static function qrUrl(): ?string
    {
        $path = SystemSetting::get(self::QR_SETTING);

        return $path ? Storage::disk(config('filesystems.media'))->url($path) : null;
    }

    public static function receiverName(): string
    {
        return (string) (SystemSetting::get(self::NAME_SETTING) ?: 'KAYA');
    }

    /** The QR and the name on it, from the admin Payments page. */
    public static function saveSettings(?UploadedFile $qr, string $name): void
    {
        if ($qr) {
            $old = SystemSetting::get(self::QR_SETTING);
            $path = $qr->store('payments', config('filesystems.media'));
            SystemSetting::updateOrCreate(['key' => self::QR_SETTING], ['value' => $path, 'label' => 'GCash QR', 'group' => 'payments']);
            if ($old && $old !== $path) {
                Storage::disk(config('filesystems.media'))->delete($old);
            }
        }
        SystemSetting::updateOrCreate(['key' => self::NAME_SETTING], ['value' => trim($name), 'label' => 'GCash account name', 'group' => 'payments']);
    }

    public static function waiting(User $user): ?CreditPayment
    {
        return CreditPayment::where('user_id', $user->id)
            ->where('check_status', CreditPayment::CHECK_UNCHECKED)
            ->latest('id')
            ->first();
    }

    /** Digits only: people type the number with the spaces GCash shows. */
    public static function normaliseRef(string $ref): string
    {
        return preg_replace('/\D/', '', $ref) ?? '';
    }

    /**
     * The claim. Returns the paid payment, or a message saying why not.
     *
     * @return CreditPayment|string
     */
    public function claim(User $user, CreditPackage $package, string $ref, UploadedFile $proof): CreditPayment|string
    {
        if (self::waiting($user)) {
            return 'Your last top-up is still being checked. You can top up again once it is confirmed.';
        }

        $path = $proof->store("payment_proofs/{$user->id}", config('filesystems.documents'));

        try {
            $payment = DB::transaction(fn () => CreditPayment::create([
                'user_id' => $user->id,
                'reference' => (string) Str::ulid(),
                'credit_package_id' => $package->id,
                'credits' => $package->credits,
                'amount_centavos' => $package->amount_centavos,
                'status' => CreditPayment::STATUS_PENDING,
                'method' => CreditPayment::METHOD_GCASH,
                'gcash_ref' => $ref,
                'proof_path' => $path,
                'check_status' => CreditPayment::CHECK_UNCHECKED,
            ]));
        } catch (UniqueConstraintViolationException) {
            Storage::disk(config('filesystems.documents'))->delete($path);

            return 'This reference number has already been used.';
        }

        $this->purchase->markPaid($payment);

        return $payment->refresh();
    }

    /** The admin's check against the GCash history. */
    public function check(CreditPayment $payment, User $admin, bool $received, ?string $note, bool $violation = true): void
    {
        if ($payment->check_status !== CreditPayment::CHECK_UNCHECKED) {
            return;
        }

        $payment->update([
            'check_status' => $received ? CreditPayment::CHECK_RECEIVED : CreditPayment::CHECK_NOT_RECEIVED,
            'checked_by' => $admin->id,
            'checked_at' => now(),
            'check_note' => $note ?: null,
        ]);

        if ($received) {
            AdminAction::record('payment.received', 'credit_payment', $payment->id,
                "GCash top-up {$payment->receiptNo()} received (Ref No. {$payment->gcash_ref})");

            return;
        }

        $user = $payment->user;
        if ($payment->transaction) {
            $this->ledger->reverseTopup($payment->transaction, "GCash Ref No. {$payment->gcash_ref} not received", $admin->id);
        }

        AdminAction::record('payment.not_received', 'credit_payment', $payment->id,
            "GCash top-up {$payment->receiptNo()} not received (Ref No. {$payment->gcash_ref}); Barya taken back",
            ['violation' => $violation, 'note' => $note]);

        $this->notify->topUpNotReceived($user, $payment, $this->ledger->balance($user));

        if ($violation) {
            $this->strikes->issue($user, 'fraud', $admin);
        }
    }
}
