import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:kaya_app/data/models/location_model.dart';
import 'package:kaya_app/providers/location_provider.dart';
import 'package:kaya_app/shared/widgets/location_picker_field.dart';

/// Pins the behaviour of externally-applied selections.
///
/// The bug this guards against shipped twice in different disguises: a parent
/// setting a location (profile prefill, or reconciling a dropped pin) also set
/// `controller.text`, which fired the field's listener synchronously — before
/// any rebuild, so `widget.selection` was still the previous value. The write
/// looked like the user typing over their own choice, `onCleared` fired, the
/// location was wiped, and the form then rejected a place it had just been
/// handed with "Pick a location from the list".
void main() {
  const urdaneta = LocationModel(
    id: 221,
    parentId: 21,
    name: 'City of Urdaneta',
    displayName: 'Urdaneta City, Pangasinan',
    type: 'city',
  );

  const binalonan = LocationModel(
    id: 187,
    parentId: 21,
    name: 'Binalonan',
    displayName: 'Binalonan, Pangasinan',
    type: 'municipality',
  );

  /// Mirrors a screen that owns the selection and passes it down.
  Widget harness({
    required TextEditingController controller,
    required GlobalKey<FormState> formKey,
    required ValueNotifier<LocationModel?> selection,
    VoidCallback? onCleared,
  }) {
    return MaterialApp(
      home: ChangeNotifierProvider(
        create: (_) => LocationProvider(),
        child: Scaffold(
          body: Form(
            key: formKey,
            child: ValueListenableBuilder<LocationModel?>(
              valueListenable: selection,
              builder: (_, value, _) => LocationPickerField(
                controller: controller,
                selection: value,
                onCleared: onCleared,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a selection applied by the parent validates and shows its label',
      (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selection = ValueNotifier<LocationModel?>(null);
    var clearedCount = 0;

    await tester.pumpWidget(harness(
      controller: controller,
      formKey: formKey,
      selection: selection,
      onCleared: () => clearedCount++,
    ));

    // The parent applies a location — and deliberately does NOT touch the
    // controller, which is the contract that fixes the race.
    selection.value = urdaneta;
    await tester.pumpAndSettle();

    expect(controller.text, urdaneta.displayName,
        reason: 'the field should write its own label from the selection');
    expect(formKey.currentState!.validate(), isTrue,
        reason: 'a parent-applied selection must satisfy the picker');
    expect(clearedCount, 0,
        reason: 'applying a selection must not report it as cleared');
  });

  testWidgets('replacing the selection (pin reconciliation) keeps it valid',
      (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selection = ValueNotifier<LocationModel?>(urdaneta);

    await tester.pumpWidget(harness(
      controller: controller,
      formKey: formKey,
      selection: selection,
    ));
    await tester.pumpAndSettle();

    // The user pinned in Binalonan and chose "Use pinned".
    selection.value = binalonan;
    await tester.pumpAndSettle();

    expect(controller.text, binalonan.displayName);
    expect(formKey.currentState!.validate(), isTrue,
        reason: 'swapping the selection must not fail validation');
    expect(find.text('Pick a location from the list'), findsNothing);
  });

  testWidgets('free text with no selection is still rejected', (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selection = ValueNotifier<LocationModel?>(null);

    await tester.pumpWidget(harness(
      controller: controller,
      formKey: formKey,
      selection: selection,
    ));

    await tester.enterText(find.byType(TextFormField), 'asdfgh');
    await tester.pump();

    expect(formKey.currentState!.validate(), isFalse,
        reason: 'typed text that was never picked has no coordinates');
  });

  testWidgets('typing over a selection clears it and tells the parent',
      (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final selection = ValueNotifier<LocationModel?>(urdaneta);
    var clearedCount = 0;

    await tester.pumpWidget(harness(
      controller: controller,
      formKey: formKey,
      selection: selection,
      onCleared: () {
        clearedCount++;
        selection.value = null;
      },
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'somewhere else');
    await tester.pump();

    expect(clearedCount, greaterThan(0),
        reason: 'the parent must learn its stored id no longer matches');
    expect(formKey.currentState!.validate(), isFalse);
  });
}
