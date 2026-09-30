/*
    The server's password rules, said before the form is sent.

    Four screens each had their own check and every one of them was "at least
    eight characters" - the same rule the server had, and the server's has
    since grown: a letter, a digit, and a refusal of the passwords people
    actually choose. Without this the form would accept something and the
    server would refuse it, which reads as the app being broken rather than
    the password being weak.

    Deliberately a copy of a rule that lives on the server, which is a thing
    worth being uneasy about - so it is one copy in one file, checked against
    App\Support\PasswordRules, rather than four. The server remains the
    authority; this only saves a round trip and says the same words.
*/
class PasswordCheck {
  const PasswordCheck._();

  /// The ones that get tried first. Mirrors PasswordRules::COMMON.
  static const _common = {
    'password', 'password1', 'password123', '12345678', '123456789',
    '1234567890', 'qwerty123', 'qwertyuiop', 'iloveyou', 'sunshine',
    'princess', 'football', 'baseball', 'welcome1', 'abc12345',
    'letmein1', 'admin123', 'kayakaya', 'kaya1234', 'kayaapp1',
    'philippines', 'pilipinas',
  };

  /*
      What is wrong with this password, or null when nothing is.

      [email] and [name] are refused as the basis of it, the same as the
      server does: the most common real password on a small platform is the
      account holder's own name with a year after it.
  */
  static String? problem(String password, {String? email, String? name}) {
    if (password.isEmpty) return 'Please enter a password';
    if (password.length < 8) return 'Password must be at least 8 characters';

    final hasLetter = password.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));

    if (!hasLetter || !hasDigit) {
      return 'Use at least one letter and one number';
    }

    final lower = password.toLowerCase().trim();

    if (_common.contains(lower)) {
      return 'That password is one of the most commonly used. Pick another.';
    }

    for (final word in _personalWords(email, name)) {
      if (word.length >= 4 && lower.contains(word)) {
        return 'Do not use your name or email address in your password';
      }
    }

    return null;
  }

  /// The email's local part and the name, split the way the server splits them.
  static Iterable<String> _personalWords(String? email, String? name) {
    final words = <String>[];

    if (email != null && email.contains('@')) {
      final local = email.split('@').first.toLowerCase();
      words.addAll(local.split(RegExp(r'[._\-+0-9]+')));
    }

    if (name != null && name.trim().isNotEmpty) {
      words.addAll(name.toLowerCase().trim().split(RegExp(r'\s+')));
    }

    return words.where((w) => w.isNotEmpty);
  }
}
