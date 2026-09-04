import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../../providers/auth_provider.dart';

/*
    Asks for verification before a gated action, not after it.

    Verification gates posting, applying, inviting, boosting, accepting an
    invitation and topping up. The server refuses all of them with a 403
    carrying `needs_verification`, and the app produced that code and then did
    nothing with it - no screen read it. So an unverified employer filled in a
    job title, description, category, budget, location and schedule, pressed
    Post, and got a toast saying "Verify your account to do that" over a form
    they now had to abandon and a verification screen they had to go and find.

    That is the same failure the name field in employer setup already avoids by
    locking rather than letting a long form end in a rejection. This is the
    general version: check first, and offer the one action that unblocks it.

    Returns true when the caller may proceed.
*/
Future<bool> ensureVerified(
  BuildContext context, {
  required String action,
}) async {
  final auth = context.read<AuthProvider>();

  /*
      Blocks only when the account is known to be unverified.

      A null user means the profile has not loaded yet, not that it failed
      verification, and stopping there would put this dialog in front of
      somebody who is verified purely because a request was slow. The server
      refuses either way, so being permissive on "don't know" costs nothing
      and being strict on it costs a verified user their action.
  */
  if (auth.user == null || auth.user!['is_verified'] == true) {
    return true;
  }

  /*
      Cached "unverified" is not good enough to refuse on.

      is_verified is a snapshot from the last /me. An admin approving an
      account changes it on the server and nothing tells the running app, so a
      user who was verified minutes ago was still being turned away here -
      by a check that did not exist before this gate was added, on a screen
      that used to simply work. Refusing on stale data is worse than the
      problem the gate was written to solve.

      One request, and only on the path that is about to refuse anyway.
  */
  await auth.fetchMe();
  if (!context.mounted) return false;

  if (auth.user == null || auth.user!['is_verified'] == true) {
    return true;
  }

  final goNow = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Verify your account'),
      content: Text(
        'You need a verified account to $action. '
        'Upload a government ID and we will review it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Not now'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Verify'),
        ),
      ],
    ),
  );

  if (goNow == true && context.mounted) {
    await Navigator.pushNamed(context, '/verification');
  }

  return false;
}

/*
    The backstop, for when the server refuses anyway.

    The check above reads is_verified, which is all the app knows. A COMPANY
    employer additionally needs approved business documents, and that status
    lives on the server - so a company can pass the client check and still be
    refused. Rather than teach the app a second rule it would then have to keep
    in step, the refusal itself is handled: if the message came back from the
    verification gate, offer the same way out instead of a dead toast.
*/
bool looksLikeVerificationRefusal(String? message) {
  if (message == null) return false;

  final m = message.toLowerCase();

  return m.contains('verify') || m.contains('verification');
}
