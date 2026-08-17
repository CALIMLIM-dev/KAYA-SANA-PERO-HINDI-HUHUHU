/// Safe numeric parsing for API payloads.
///
/// Laravel's `decimal:N` cast serializes to a JSON **string** ("0.00"), not a
/// number — `rating_avg`, `budget_min/max`, `latitude/longitude`,
/// `passing_score` and friends all arrive that way. A plain `as num?` cast on
/// those throws `type 'String' is not a subtype of type 'num?' in type cast`
/// and takes the whole screen down with it.
///
/// This has now bitten the worker public profile and the applicants list, so
/// every read of a possibly-decimal field should go through here rather than
/// casting inline.
library;

double? asDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

double asDouble(Object? v, {double fallback = 0}) =>
    asDoubleOrNull(v) ?? fallback;

int? asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  // "4.00" would fail int.tryParse, so go through double first.
  return int.tryParse(v.toString()) ?? double.tryParse(v.toString())?.toInt();
}

int asInt(Object? v, {int fallback = 0}) => asIntOrNull(v) ?? fallback;
