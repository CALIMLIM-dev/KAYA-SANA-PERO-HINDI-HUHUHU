import 'package:flutter_test/flutter_test.dart';
import 'package:kaya_app/features/profile/widgets/experience_section.dart';

/*
    The overall years on the profile's Experience section: months worked,
    overlapping jobs counted once - the rule the server ranks by.
*/
void main() {
  final today = DateTime(2026, 10, 1);

  test('two jobs in a row add up', () {
    final months = ExperienceSpan.totalMonths([
      {'start_date': '2020-01-01', 'end_date': '2022-01-01'},
      {'start_date': '2022-01-01', 'end_date': '2023-04-01'},
    ], today: today);
    expect(months, 39);
    expect(ExperienceSpan.label(months), '3 years, 3 months');
  });

  test('two jobs held at once are counted once', () {
    final months = ExperienceSpan.totalMonths([
      {'start_date': '2021-01-01', 'end_date': '2022-01-01'},
      {'start_date': '2021-06-01', 'end_date': '2021-12-01'},
    ], today: today);
    expect(months, 12);
    expect(ExperienceSpan.label(months), '1 year');
  });

  test('a job still held runs to today', () {
    expect(
      ExperienceSpan.totalMonths([
        {'start_date': '2026-02-01', 'end_date': ''},
      ], today: today),
      8,
    );
  });

  test('under a month says so', () {
    expect(ExperienceSpan.label(0), 'Under a month');
  });
}
