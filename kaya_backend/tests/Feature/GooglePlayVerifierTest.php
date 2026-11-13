<?php

namespace Tests\Feature;

use App\Services\GooglePlayVerifier;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The real Google Play check, against a faked Google: it signs in as the
    service account with a signed JWT, reads the purchase from the right
    address, and reads purchaseState 0 as bought and anything else as not.
*/
class GooglePlayVerifierTest extends TestCase
{
    private string $keyFile;

    protected function setUp(): void
    {
        parent::setUp();
        Cache::flush();
        // Windows PHP (XAMPP) needs its OpenSSL config named; Linux finds its own.
        $opts = ['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA];
        foreach ([getenv('OPENSSL_CONF') ?: null, 'C:/xampp/php/extras/openssl/openssl.cnf'] as $conf) {
            if ($conf && is_file($conf)) {
                $opts['config'] = $conf;
                break;
            }
        }
        $key = openssl_pkey_new($opts);
        openssl_pkey_export($key, $pem, null, $opts);
        $this->keyFile = tempnam(sys_get_temp_dir(), 'play') . '.json';
        file_put_contents($this->keyFile, json_encode([
            'client_email' => 'kaya-billing@kaya.iam.gserviceaccount.com',
            'private_key'  => $pem,
            'token_uri'    => 'https://oauth2.googleapis.com/token',
        ]));
        config(['kaya.credits.play.service_account' => $this->keyFile, 'kaya.credits.play.package_name' => 'com.alphatech.kaya_app']);
    }

    protected function tearDown(): void
    {
        @unlink($this->keyFile);
        parent::tearDown();
    }

    #[Test]
    public function a_bought_purchase_is_read_from_google(): void
    {
        Http::fake([
            'oauth2.googleapis.com/token' => Http::response(['access_token' => 'ya29.test', 'expires_in' => 3600]),
            'androidpublisher.googleapis.com/*' => Http::response([
                'purchaseState' => 0, 'orderId' => 'GPA.3311-2222', 'obfuscatedExternalAccountId' => 'u7',
            ]),
        ]);

        $result = app(GooglePlayVerifier::class)->verify('barya_60', 'tok/with+chars');

        $this->assertSame(['product_id' => 'barya_60', 'purchased' => true, 'account' => 'u7', 'order_id' => 'GPA.3311-2222'], $result);
        Http::assertSent(fn (Request $r) => str_contains($r->url(), 'oauth2.googleapis.com/token')
            && $r['grant_type'] === 'urn:ietf:params:oauth:grant-type:jwt-bearer'
            && substr_count($r['assertion'], '.') === 2);
        Http::assertSent(fn (Request $r) => $r->url() === 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.alphatech.kaya_app/purchases/products/barya_60/tokens/tok%2Fwith%2Bchars'
            && $r->hasHeader('Authorization', 'Bearer ya29.test'));
    }

    #[Test]
    public function a_cancelled_purchase_is_not_bought_and_no_key_means_no_answer(): void
    {
        Http::fake([
            'oauth2.googleapis.com/token' => Http::response(['access_token' => 'ya29.test']),
            'androidpublisher.googleapis.com/*' => Http::response(['purchaseState' => 1]),
        ]);
        $this->assertFalse(app(GooglePlayVerifier::class)->verify('barya_60', 'tok')['purchased']);

        Cache::flush();
        config(['kaya.credits.play.service_account' => null]);
        $this->assertNull(app(GooglePlayVerifier::class)->verify('barya_60', 'tok'));
    }
}
