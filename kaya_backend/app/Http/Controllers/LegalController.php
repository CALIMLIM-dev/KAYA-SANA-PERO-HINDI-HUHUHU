<?php

namespace App\Http\Controllers;

/**
 * The public Terms and Privacy pages.
 *
 * These exist so the Google sign-in consent screen has real URLs to link to -
 * Google shows "KAYA's privacy policy and terms of service" only if those
 * pages actually resolve. They are public (no auth), because the consent
 * screen is shown before anyone has signed in.
 *
 * The text is the same wording the app shows in its consent sheet. It is
 * extracted from the app's legal_documents.dart into resources/legal_content.json
 * so the two cannot say different things - regenerate that file if the app's
 * text changes.
 */
class LegalController extends Controller
{
    public function terms()
    {
        return $this->render('terms', 'Terms and Conditions');
    }

    public function privacy()
    {
        return $this->render('privacy', 'Privacy Policy');
    }

    private function render(string $which, string $title)
    {
        $data = json_decode(
            file_get_contents(resource_path('legal_content.json')),
            true,
        );

        return response()->view('legal', [
            'which' => $which,
            'title' => $title,
            'sections' => $data[$which] ?? [],
            'updated' => $data['updated'] ?? '',
        ]);
    }
}
