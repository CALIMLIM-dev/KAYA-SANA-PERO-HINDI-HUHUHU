<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    The credit economy, which is the only revenue this product has.

    KAYA takes no cut of a job. Money moves one way — user buys credits from
    KAYA — and the job itself is settled directly between the two people, off
    platform. That is a deliberate choice, not a gap: holding other people's
    money is BSP-regulated territory in the Philippines and needs KYC on every
    payee and dispute machinery to match. Credits keep the flow one directional
    and ordinary checkout sufficient.

    Which makes these tables the whole business, so a few decisions are worth
    stating where they cannot be missed.

    CREDITS ARE INTEGERS. A credit is a unit of entitlement, not currency; you
    can never spend half of one. This also avoids the decimal-as-string trap
    that has already taken this app down once, where a decimal cast arrives at
    the client as "5.00" and the parse throws.

    PESOS ARE INTEGER CENTAVOS, departing from the house decimal(10,2) on
    purpose. PayMongo denominates in centavos, and storing decimal then
    multiplying by 100 puts a float conversion exactly where a rounding error
    becomes a financial discrepancy.

    THE LEDGER IS APPEND ONLY. Nothing here is ever edited. A refund is a new
    row pointing at the one it reverses, so the history stays readable and the
    balance can always be rebuilt by summing it.

    NO lifetime_spent OR lifetime_purchased COLUMNS. They are sums of the
    ledger and would be a second source of truth that drifts. Compute them.

    Three unique indexes carry the real guarantees, because a constraint the
    database enforces beats a check in PHP that two requests can both pass:
    refunds_transaction_id makes a double refund impossible, (user_id,
    grant_period) makes a double monthly grant impossible, and the unlock
    triple makes paying twice for the same person impossible.

    Status columns are string, never enum. This codebase has an entire
    migration written to undo an enum that drifted between MySQL and the
    SQLite the tests run on.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('credit_wallets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->unique()->constrained()->cascadeOnDelete();
            // Unsigned, so a bug that tries to push it below zero fails loudly
            // at the database rather than quietly granting free credit.
            $table->unsignedInteger('balance')->default(0);
            // 'YYYY-MM' of the last free monthly grant. A string because it
            // compares lexicographically, so `<` is the correct monotonic test.
            $table->char('last_grant_period', 7)->nullable();
            $table->timestamps();
        });

        Schema::create('credit_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            // Signed: negative spends, positive tops up, grants and refunds.
            $table->integer('delta');
            // The wallet balance immediately after this row, read back inside
            // the same transaction. Makes the ledger auditable on its own.
            $table->unsignedInteger('balance_after');
            $table->string('reason', 40);

            /*
                What the row is about — an application, an invitation, a
                payment. Deliberately NOT a foreign key: the ledger outlives
                what it refers to, and a job deleted three years from now must
                not take the record of a charge with it.
            */
            $table->string('reference_type', 40)->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();

            // Set on a refund, pointing at the row it reverses. Unique, so a
            // second refund of the same charge cannot be written at all.
            $table->foreignId('refunds_transaction_id')->nullable()->unique()
                ->constrained('credit_transactions')->nullOnDelete();

            // Set only on the free monthly grant.
            $table->char('grant_period', 7)->nullable();

            $table->string('note', 255)->nullable();
            // Which admin, when a human moved the balance by hand.
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['user_id', 'created_at'], 'credit_transactions_user_time_index');
            $table->index(['reference_type', 'reference_id'], 'credit_transactions_reference_index');
            // One grant per account per month, enforced rather than checked.
            $table->unique(['user_id', 'grant_period'], 'credit_transactions_grant_unique');
        });

        Schema::create('credit_packages', function (Blueprint $table) {
            $table->id();
            $table->string('name', 60);
            $table->unsignedInteger('credits');
            $table->unsignedInteger('amount_centavos');
            $table->boolean('is_active')->default(true);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::create('credit_payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            // Our own reference, generated before the provider is called.
            $table->string('reference', 40)->unique();
            $table->foreignId('credit_package_id')->nullable()
                ->constrained('credit_packages')->nullOnDelete();

            /*
                Snapshotted at checkout, not read from the package later.

                A package's price can change, and a payment must always say what
                was actually charged and what was actually owed — including for
                a package that has since been edited or deactivated.
            */
            $table->unsignedInteger('credits');
            $table->unsignedInteger('amount_centavos');

            $table->string('status', 12)->default('pending');
            $table->string('provider_session_id')->nullable()->unique();
            $table->timestamp('paid_at')->nullable();
            // The ledger row that granted the credits, once it exists.
            $table->foreignId('credit_transaction_id')->nullable()
                ->constrained('credit_transactions')->nullOnDelete();
            $table->timestamps();

            $table->index(['status', 'created_at'], 'credit_payments_status_time_index');
        });

        Schema::create('credit_webhook_events', function (Blueprint $table) {
            $table->id();
            $table->string('provider', 20);
            $table->string('provider_event_id');
            $table->string('event_type', 60);
            $table->json('payload');
            $table->timestamp('received_at');
            $table->timestamps();

            // The same event delivered twice is recorded once.
            $table->unique(['provider', 'provider_event_id'], 'credit_webhook_events_unique');
        });

        Schema::create('credit_unlocks', function (Blueprint $table) {
            $table->id();
            $table->foreignId('unlocker_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('unlocked_id')->constrained('users')->cascadeOnDelete();
            // Which side of them was unlocked, since a hybrid account has two.
            $table->string('unlocked_as', 10);
            $table->foreignId('credit_transaction_id')->nullable()
                ->constrained('credit_transactions')->nullOnDelete();
            $table->timestamps();

            /*
                Paying twice for the same person is structurally impossible, and
                an unlock never expires. "I paid for this number and now it is
                gone" is the worst support ticket available.
            */
            $table->unique(['unlocker_id', 'unlocked_id', 'unlocked_as'], 'credit_unlocks_unique');
        });
    }

    public function down(): void
    {
        // Dropped in reverse dependency order. credit_transactions references
        // itself and is referenced by payments and unlocks, so it goes late.
        Schema::dropIfExists('credit_unlocks');
        Schema::dropIfExists('credit_webhook_events');
        Schema::dropIfExists('credit_payments');
        Schema::dropIfExists('credit_transactions');
        Schema::dropIfExists('credit_packages');
        Schema::dropIfExists('credit_wallets');
    }
};
