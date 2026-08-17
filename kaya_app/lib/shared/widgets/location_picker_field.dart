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
class LocationPickerField extends StatefulWidget {
  const LocationPickerField({
    super.key,
    required this.controller,
    this.onSelected,
    this.labelText = 'Location',
    this.hintText = 'Type a city or municipality',
    this.validator,
    this.enabled = true,
    this.prefixIcon = Icons.location_on_outlined,
    this.fillColor,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<LocationModel>? onSelected;
  final String labelText;
  final String hintText;
  final String? Function(String?)? validator;
  final bool enabled;
  final IconData prefixIcon;
  final Color? fillColor;
  final bool autofocus;

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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
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

    _matches = [];
    _removeOverlay();
    _focusNode.unfocus();

    widget.onSelected?.call(location);
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
        validator: widget.validator,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: widget.labelText.isEmpty ? null : widget.labelText,
          hintText: widget.hintText,
          filled: true,
          fillColor: widget.fillColor ?? Colors.white,
          prefixIcon: Icon(widget.prefixIcon, color: AppColors.neutral400),
          suffixIcon: widget.controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    widget.controller.clear();
                    _matches = [];
                    _removeOverlay();
                    setState(() {});
                  },
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
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
