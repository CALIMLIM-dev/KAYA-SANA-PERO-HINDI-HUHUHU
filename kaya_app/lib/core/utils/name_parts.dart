/*
    The account name, split into the parts a form asks for.

    The server sends `first_name` and the rest on /me and is the authority on
    them. This is the fallback for the two cases where they are not there: an
    account that registered before the name was split into columns, and an app
    talking to a server that has not been updated yet. Without it the setup
    screens show four empty boxes for a name the account already has.

    Display only. Nothing here is written back — the fields it fills are
    read-only, because a name that already exists is not set again during
    setup.
*/
class NameParts {
  const NameParts({this.first, this.middle, this.last, this.suffix});

  final String? first;
  final String? middle;
  final String? last;
  final String? suffix;

  /// Jr., Sr., III — their own field, not stuck on the end of a surname.
  static const _suffixes = {'jr', 'jr.', 'sr', 'sr.', 'ii', 'iii', 'iv', 'v'};

  /// Dela Cruz is one surname. Taking the last word alone leaves "Juan Dela"
  /// standing in the first name box, which is not a name anybody has.
  static const _particles = {
    'de', 'del', 'dela', 'delas', 'delos', 'la', 'las', 'los',
    'san', 'santa', 'santo', 'sta', 'sta.', 'sto', 'sto.', 'y',
  };

  factory NameParts.of(String? name) {
    final tokens =
        (name ?? '').trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    if (tokens.isEmpty) return const NameParts();

    String? suffix;
    if (tokens.length > 2 && _suffixes.contains(tokens.last.toLowerCase())) {
      suffix = tokens.removeLast();
    }

    String? last;
    if (tokens.length > 1) {
      last = tokens.removeLast();

      while (tokens.length > 1 && _particles.contains(tokens.last.toLowerCase())) {
        last = '${tokens.removeLast()} $last';
      }
    }

    return NameParts(
      first: tokens.join(' '),
      // Never guessed: the composed name carries the middle name as an
      // initial, so there is nothing here to recover it from.
      middle: null,
      last: last,
      suffix: suffix,
    );
  }
}
