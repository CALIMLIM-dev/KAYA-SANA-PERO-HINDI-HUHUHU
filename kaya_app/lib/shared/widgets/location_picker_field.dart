import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/location_model.dart';
import '../../providers/location_provider.dart';

/// Type-ahead location field.
///
/// The user types straight into the field — "urdan" — and matching Philippine
/// cities and municipalities appear in a dropdown directly beneath it, updating
/// as they type. Nothing is suggested until they start typing.
///
/// Writes the chosen place into [controller] (so existing validators and save
/// code keep working) and reports the structured record — id and coordinates —
/// through [onSelected].
///
/// The field insists on a *selection*, not just text. Before, the validator
/// only ever saw the controller's string, so typing "asdfgh" passed and the
/// record saved with no location_id and no coordinates — invisible to
/// proximity search, no distance, zero location match points, and no error
/// anywhere. Editing the text after choosing had the same effect: the label
/// and the stored id silently disagreed.
class LocationPickerField extends StatefulWidget {
  const LocationPickerField({
    super.key,
    required this.controller,
    this.onSelected,
    this.onCleared,
    this.selection,
    this.labelText = 'Location',
    this.hintText = 'Type a city or municipality',
    this.validator,
    this.enabled = true,
    this.prefixIcon = Icons.location_on_outlined,
    this.fillColor,
    this.borderColor,
    this.autofocus = false,
    this.requireSelection = true,
  });

  final TextEditingController controller;
  final ValueChanged<LocationModel>? onSelected;

  /// A selection made outside the dropdown — prefilled from a saved profile,
  /// or reconciled from a dropped pin.
  ///
  /// Without this the field only ever trusts its own dropdown, so writing the
  /// controller text externally looked like the user typing over their choice:
  /// it fired [onCleared], wiped the parent's location, and then failed
  /// validation with "Pick a location from the list" for a place that had in
  /// fact been picked.
  final LocationModel? selection;

  /// Fired when a previously chosen place stops being valid — the user edited
  /// the text, or cleared the field. Parents should null their stored
  /// LocationModel here so a stale id can't be saved against a new label.
  final VoidCallback? onCleared;

  final String labelText;
  final String hintText;
  final String? Function(String?)? validator;
  final bool enabled;
  final IconData prefixIcon;
  final Color? fillColor;

  /// Outline colour. Null keeps the borderless default; forms whose other
  /// fields are outlined pass one so this does not read as a different kind of
  /// control sitting among them.
  final Color? borderColor;
  final bool autofocus;

  /// Reject free text that wasn't picked from the dropdown. Off only for
  /// fields where a loose place name is genuinely acceptable.
  final bool requireSelection;

  @override
  State<LocationPickerField> createState() => _LocationPickerFieldState();
}

class _LocationPickerFieldState extends State<LocationPickerField> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();

  OverlayEntry? _overlay;
  Timer? _debounce;

  List<LocationModel> _matches = [];
  bool _isLoading = false;

  /// Set while we programmatically write the chosen name into the controller,
  /// so the resulting change event doesn't immediately re-open the dropdown.
  bool _suppressSearch = false;

  /// The place actually chosen from the dropdown, or null if the current text
  /// is just something the user typed.
  LocationModel? _selected;

  /// Whatever the field was seeded with — an edit form pre-filling a saved
  /// location. Left untouched that stays valid; blocking someone from editing
  /// an unrelated field because of a value already in the database would be
  /// worse than the loose data itself.
  late final String _pristineText;

  @override
  void initState() {
    super.initState();
    _pristineText = widget.controller.text.trim();
    _selected = widget.selection;
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(LocationPickerField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // The parent applied a location itself (profile prefill, pin
    // reconciliation). Adopt it — and write the label here rather than making
    // the parent do it.
    //
    // A parent that sets `controller.text` fires this listener synchronously,
    // before any rebuild, so `widget.selection` is still the *previous* value:
    // the new text looks like the user typing over their choice, onCleared
    // fires, and the location the parent just set is wiped. Owning the write
    // here — behind _suppressSearch — removes that race entirely.
    if (widget.selection?.id != oldWidget.selection?.id) {
      _selected = widget.selection;

      final label = widget.selection?.displayName;
      if (label != null && widget.controller.text.trim() != label) {
        // Deferred on purpose: TextFormField listens to the controller and
        // rebuilds itself on change, and didUpdateWidget runs *during* build —
        // writing here directly throws "setState() called during build".
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (widget.controller.text.trim() == label) return;

          _suppressSearch = true;
          widget.controller.text = label;
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: label.length),
          );
          _suppressSearch = false;

          // Refresh the tick and hint, which read the text.
          setState(() {});
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    widget.controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Let a tap on a suggestion land before tearing the overlay down.
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !_focusNode.hasFocus) _removeOverlay();
      });
    }
  }

  void _onTextChanged() {
    if (_suppressSearch) return;

    final term = widget.controller.text.trim();

    // A controller write that matches the parent's own selection is that
    // selection being applied, not the user typing over it. Ordering between
    // this listener and didUpdateWidget isn't guaranteed, so recognise it here
    // too — otherwise the parent sets a location and this immediately wipes it.
    if (widget.selection != null && term == widget.selection!.displayName) {
      _selected = widget.selection;
    } else if (_selected != null && term != _selected!.displayName) {
      // Typing after choosing invalidates the choice — otherwise the label and
      // the stored location_id drift apart without anything noticing.
      _selected = null;
      widget.onCleared?.call();
    }

    // The tick, the hint and the clear button all read _selected/text.
    if (mounted) setState(() {});

    _debounce?.cancel();

    // One character matches nearly everything; wait for a real prefix.
    if (term.length < 2) {
      _matches = [];
      _removeOverlay();
      return;
    }

    // Debounce so a fast typist fires one request, not one per keystroke.
    _debounce = Timer(const Duration(milliseconds: 220), () => _search(term));
  }

  Future<void> _search(String term) async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    _showOverlay();

    final provider = context.read<LocationProvider>();
    await provider.search(term);

    if (!mounted) return;

    // Ignore a response that arrived after the user typed something else.
    if (widget.controller.text.trim() != term) return;

    setState(() {
      _matches = provider.results;
      _isLoading = false;
    });

    if (_matches.isEmpty && !_isLoading) {
      _overlay?.markNeedsBuild();
    } else {
      _showOverlay();
    }
  }

  void _select(LocationModel location) {
    _suppressSearch = true;
    widget.controller.text = location.displayName;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
    _suppressSearch = false;

    _selected = location;
    _matches = [];
    _removeOverlay();
    _focusNode.unfocus();

    widget.onSelected?.call(location);
    // Repaint so the "picked from list" tick replaces the warning state.
    if (mounted) setState(() {});
  }

  /// Wraps the caller's validator with the selection requirement.
  String? _validate(String? value) {
    final external = widget.validator?.call(value);
    if (external != null) return external;

    if (!widget.requireSelection) return null;

    final text = (value ?? '').trim();

    // Empty is the caller's business — their validator decides whether the
    // field is required at all.
    if (text.isEmpty) return null;

    if (_hasSelectionFor(text)) return null;

    // An untouched pre-filled value from an edit form stays acceptable.
    if (_pristineText.isNotEmpty && text == _pristineText) return null;

    return 'Pick a location from the list';
  }

  /// Whether [text] is backed by a real place — either picked from the
  /// dropdown here, or supplied by the parent via [widget.selection].
  bool _hasSelectionFor(String text) {
    if (_selected != null && text == _selected!.displayName) return true;
    if (widget.selection != null && text == widget.selection!.displayName) {
      return true;
    }
    return false;
  }

  /// True when the text is free-form rather than a real place — used to hint
  /// before the user ever hits submit.
  bool get _needsSelection {
    if (!widget.requireSelection) return false;
    final text = widget.controller.text.trim();
    if (text.isEmpty || _hasSelectionFor(text)) return false;
    if (_pristineText.isNotEmpty && text == _pristineText) return false;
    return true;
  }

  void _showOverlay() {
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }

    _overlay = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildOverlay(BuildContext context) {
    final box = this.context.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? MediaQuery.of(context).size.width;

    return Positioned(
      width: width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        // Sits just under the field so it reads as part of it.
        offset: Offset(0, (box?.size.height ?? 56) + 4),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: _overlayContent(),
          ),
        ),
      ),
    );
  }

  Widget _overlayContent() {
    if (_isLoading && _matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Searching…', style: TextStyle(color: AppColors.neutral600)),
          ],
        ),
      );
    }

    if (_matches.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No match. Try a different spelling.',
          style: TextStyle(color: AppColors.neutral600),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _matches.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 48),
      itemBuilder: (_, i) {
        final location = _matches[i];
        return ListTile(
          dense: true,
          leading: Icon(
            location.type == 'city' ? Icons.location_city : Icons.place_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          title: Text(
            location.displayName,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: location.regionName != null
              ? Text(location.regionName!,
                  style: const TextStyle(fontSize: 11))
              : null,
          onTap: () => _select(location),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        validator: _validate,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: widget.labelText.isEmpty ? null : widget.labelText,
          hintText: widget.hintText,
          // Matched to every other placeholder in the app.
          //
          // With no hintStyle this fell back to the theme's 16px body text,
          // so on any form where it sits among ordinary TextFields its
          // placeholder was visibly bigger than all of them — reported on the
          // edit employer profile screen, but it was true everywhere.
          hintStyle: const TextStyle(color: AppColors.neutral400, fontSize: 14),
          // Say it before submit rather than after — the user is looking at
          // the field right now.
          helperText: _needsSelection ? 'Choose one of the suggestions' : null,
          helperStyle: const TextStyle(color: AppColors.warning, fontSize: 12),
          filled: true,
          fillColor: widget.fillColor ?? Colors.white,
          prefixIcon: Icon(widget.prefixIcon, color: AppColors.neutral400),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : _hasSelectionFor(widget.controller.text.trim())
                  ? const Icon(Icons.check_circle,
                      size: 18, color: AppColors.success)
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        widget.controller.clear();
                        _selected = null;
                        widget.onCleared?.call();
                        _matches = [];
                        _removeOverlay();
                        setState(() {});
                      },
                    ),
          // Borderless by default, because most callers sit it on a tinted
          // panel where an outline would be noise. Forms whose other fields
          // are outlined pass a colour so this one does not read as a
          // different kind of control.
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: widget.borderColor == null
                ? BorderSide.none
                : BorderSide(color: widget.borderColor!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: widget.borderColor == null
                ? BorderSide.none
                : BorderSide(color: widget.borderColor!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
      ),
    );
  }
}
