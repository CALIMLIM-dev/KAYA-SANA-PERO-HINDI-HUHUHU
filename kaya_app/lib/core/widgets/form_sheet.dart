import 'package:flutter/material.dart';

import 'kaya_popup.dart';

/*
    A full-height form, presented as a sheet instead of a page.

    Adding a certification, a license or a job is something you do *to* the
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
//
// Now a pop-up rather than a bottom sheet, like everything else that opens
// over a screen. The page behind still shows round its edges, and the form's
// back arrow closes it. See showKayaPopup.
Future<T?> showFormSheet<T>(BuildContext context, Widget form) {
  return showKayaPopup<T>(context, tall: true, builder: (_) => form);
}
