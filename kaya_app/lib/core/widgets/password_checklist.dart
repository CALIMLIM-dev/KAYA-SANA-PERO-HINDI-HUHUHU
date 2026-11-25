import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/password_check.dart';

/*
    Under a new password: a letter, a number, a symbol, and Weak or Strong.

    Strong is exactly what the server accepts. With all three ticked and the
    password still weak (too short, a common one, the person's own name), it
    says why, unless the field above is already saying it.
*/
class PasswordChecklist extends StatelessWidget {
  const PasswordChecklist({super.key, required this.controller, this.email, this.fieldShowsError = false});

  final TextEditingController controller;
  final TextEditingController? email;
  final bool fieldShowsError;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([controller, email]),
        builder: (context, _) {
          final password = controller.text;
          final problem = PasswordCheck.problem(password, email: email?.text.trim());
          final letter = PasswordCheck.hasLetter(password);
          final number = PasswordCheck.hasNumber(password);
          final symbol = PasswordCheck.hasSymbol(password);

          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          _item('Letter', letter),
                          _item('Number', number),
                          _item('Symbol', symbol),
                        ],
                      ),
                    ),
                    if (password.isNotEmpty)
                      Text(
                        problem == null ? 'Strong' : 'Weak',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: problem == null ? AppColors.success : AppColors.neutral700,
                        ),
                      ),
                  ],
                ),
                if (letter && number && symbol && problem != null && !fieldShowsError)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(problem, style: const TextStyle(fontSize: 13, color: AppColors.neutral600)),
                  ),
              ],
            ),
          );
        },
      );

  Widget _item(String label, bool met) => Semantics(
        checked: met,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              met ? Icons.check : Icons.remove,
              size: 15,
              color: met ? AppColors.success : AppColors.neutral400,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 13, color: met ? AppColors.neutral900 : AppColors.neutral600),
            ),
          ],
        ),
      );
}
