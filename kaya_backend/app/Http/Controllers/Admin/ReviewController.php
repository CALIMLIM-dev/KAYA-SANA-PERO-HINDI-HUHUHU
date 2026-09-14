<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\Review;
use App\Services\RatingService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

/*
    Every review on the platform, and the power to take one down.

    A review is the one thing a user writes that stays on somebody else's
    profile. Until this page nobody could remove an abusive or fake one.
    Hidden, not deleted: the row stays, the average is recomputed without
    it, and the reviewer cannot write another for the same job.
*/
class ReviewController extends Controller
{
    public function index(Request $request)
    {
        $show = $request->get('show', 'visible');
        $search = trim((string) $request->get('search'));
        $rating = $request->integer('rating');

        $reviews = Review::withHidden()
            ->with(['reviewer:id,name', 'reviewee:id,name', 'job:id,title', 'hider:id,name'])
            ->when($show === 'visible', fn ($q) => $q->whereNull('hidden_at'))
            ->when($show === 'hidden', fn ($q) => $q->whereNotNull('hidden_at'))
            ->when($rating > 0, fn ($q) => $q->where('rating', $rating))
            ->when($search !== '', function ($q) use ($search) {
                $q->where(function ($q) use ($search) {
                    $q->where('comment', 'like', "%{$search}%")
                      ->orWhereHas('reviewer', fn ($u) => $u->where('name', 'like', "%{$search}%"))
                      ->orWhereHas('reviewee', fn ($u) => $u->where('name', 'like', "%{$search}%"));
                });
            })
            ->latest()
            ->paginate(20)
            ->withQueryString();

        $counts = [
            'visible' => Review::count(),
            'hidden'  => Review::withHidden()->whereNotNull('hidden_at')->count(),
        ];

        return view('admin.reviews.index', compact('reviews', 'show', 'search', 'rating', 'counts'));
    }

    public function hide(Request $request, int $id)
    {
        $data = $request->validate(['reason' => ['required', 'string', 'max:255']]);

        $review = Review::withHidden()->findOrFail($id);

        if ($review->isHidden()) {
            return back()->with('error', 'That review is already hidden.');
        }

        $review->forceFill([
            'hidden_at'     => now(),
            'hidden_reason' => $data['reason'],
            'hidden_by'     => Auth::id(),
        ])->save();

        RatingService::recompute($review->reviewee_id, $review->reviewee_role);

        AdminAction::record(
            'review.hidden', 'review', $review->id,
            'Hid ' . ($review->reviewer?->name ?? 'a deleted account') . "'s review of "
                . ($review->reviewee?->name ?? 'a deleted account') . ": {$data['reason']}",
            ['reviewer_id' => $review->reviewer_id, 'reviewee_id' => $review->reviewee_id, 'rating' => $review->rating, 'reason' => $data['reason']],
        );

        return back()->with('success', 'Review hidden. The rating has been recomputed without it.');
    }

    public function restore(int $id)
    {
        $review = Review::withHidden()->findOrFail($id);

        if (! $review->isHidden()) {
            return back()->with('error', 'That review is not hidden.');
        }

        $review->forceFill(['hidden_at' => null, 'hidden_reason' => null, 'hidden_by' => null])->save();

        RatingService::recompute($review->reviewee_id, $review->reviewee_role);

        AdminAction::record(
            'review.restored', 'review', $review->id,
            'Restored ' . ($review->reviewer?->name ?? 'a deleted account') . "'s review of "
                . ($review->reviewee?->name ?? 'a deleted account'),
        );

        return back()->with('success', 'Review restored and the rating recomputed.');
    }
}
