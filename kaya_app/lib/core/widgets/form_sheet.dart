import 'package:flutter/material.dart';

/*
    A full-height form, presented as a sheet instead of a page.

    Adding a certification, a licence or a job is something you do *to* the
    profile you are looking at, and pushing a whole page for it threw the
    profile away and brought it back a moment later — the list you were adding
    to disappeared, so nothing on screen connected the form to the thing it was
    filling in. A sheet keeps the profile behind it, which is what makes it
    read as "adding a row here" rather than "you are somewhere else now".

    The forms stay Scaffolds. They were written as pages, they carry their own
    app bar and their own scrolling, and a Scaffold laid into a scroll-
    controlled sheet keeps all of it — including resizeToAvoidBottomInset,
    which is the part that matters: these forms are mostly text fields, and a
    sheet that does not lift for the keyboard hides the field being typed into.
    That is why the height comes from a top inset rather than a height factor —
    the Scaffold has to own the remaining space for its own inset handling to
    work.
*/
Future<T?> showFormSheet<T>(BuildContext context, Widget form) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    // Enough of the page left visible to show what is being added to, and to
    // give a tap-to-dismiss target that is not the small drag handle.
    builder: (_) => Padding(
      padding: const EdgeInsets.only(top: 28),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: form,
      ),
    ),
  );
}
