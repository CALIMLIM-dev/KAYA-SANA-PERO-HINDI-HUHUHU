<?php

namespace App\Support;

/*
    Distance, coarse on purpose.

    An exact figure is a home address with one step removed. The viewer sets
    their own pin freely, so three readings from three chosen positions are
    three circles on a map that meet at one point - the other person's door,
    to about a hundred metres. Bands answer the only question anyone has, is
    this near enough, and give away nothing more.

    One place for the rule, used for a worker seen by an employer and for a
    job seen by a worker. It was written once for workers and the job side
    kept sending the exact number, which undid the point of having it.
*/
final class DistanceBand
{
    public static function bucket(?float $km): ?float
    {
        if ($km === null) return null;

        if ($km < 1)  return 1;
        if ($km < 5)  return 5;
        if ($km < 15) return 15;
        if ($km < 30) return 30;
        if ($km < 50) return 50;

        return 100;
    }

    /** The band in words, so the app does not have to invent the phrasing. */
    public static function label(?float $km): ?string
    {
        if ($km === null) return null;

        if ($km < 1)  return 'Under 1 km away';
        if ($km < 5)  return 'Under 5 km away';
        if ($km < 15) return '5–15 km away';
        if ($km < 30) return '15–30 km away';
        if ($km < 50) return '30–50 km away';

        return 'Over 50 km away';
    }
}
