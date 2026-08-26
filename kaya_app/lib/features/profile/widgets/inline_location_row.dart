import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/location_model.dart';
import '../../../providers/location_provider.dart';

/*
    Location, edited in place like every other field.

    The obvious way to make this inline is a plain text box, and it is the
    wrong one: a location is not a string here. It carries a PSGC id and a
    latitude and longitude, and those are what "jobs near you", the distance on
    every card, and the radius search all run on. Typing "Urdaneta" into a text
    field would save the word and leave the coordinates behind, and the app
    would quietly stop knowing where anybody is.

    So it types like a text field and commits like a picker: you get a cursor
    and a keyboard on tap, suggestions appear as you type, and choosing one
    saves the name together with its id and coordinates. Free text is never
    saved on its own - a name with nothing behind it is exactly the broken
    state this avoids.

    Search is debounced and the provider caches by term, so backspacing through
    a word does not fire a request per keystroke.
*/
class InlineLocationRow extends StatefulWidget {
  const InlineLocationRow({
    super.key,
    required this.value,
    required this.onSave,
    this.label = 'Location',
  });

  final String? value;
  final String label;

  /// Returns an error message, or null when the save worked.
  final Future<String?> Function(LocationModel picked) onSave;

  @override
  State<InlineLocationRow> createState() => _InlineLocationRowState();
}

class _InlineLocationRowState extends State<InlineLocationRow> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  Timer? _debounce;
  bool _editing = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() {
      _editing = true;
      _error = null;
      // Starts empty rather than pre-filled. Pre-filling means the first
      // keystroke appends to a full place name and searches for nonsense.
      _controller.clear();
    });
    context.read<LocationProvider>().clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _cancel() {
    _debounce?.cancel();
    setState(() {
      _editing = false;
      _error = null;
      _controller.clear();
    });
    context.read<LocationProvider>().clear();
    FocusScope.of(context).unfocus();
  }

  void _onTyped(String term) {
    _debounce?.cancel();

    // Rebuilds on every keystroke, which is not just cosmetic: the suggestion
    // block below decides what to show from the current text, and without this
    // the only rebuilds came from the provider - so the text it compared
    // against stayed whatever it was when the field opened, which was empty.
    // The result was a box that said "type at least two letters" no matter how
    // much you typed.
    setState(() {});

    // Two characters is where results stop being the whole country.
    if (term.trim().length < 2) {
      context.read<LocationProvider>().clear();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) context.read<LocationProvider>().search(term.trim());
    });
  }

  Future<void> _pick(LocationModel place) async {
    setState(() {
      _saving = true;
      _error = null;
    });

    final failure = await widget.onSave(place);
    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = failure;
      if (failure == null) _editing = false;
    });

    if (failure == null) {
      _controller.clear();
      context.read<LocationProvider>().clear();
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filled = (widget.value ?? '').trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _editing ? null : _startEditing,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _error != null ? AppColors.error : AppColors.neutral200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              color: AppColors.neutral500,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (_editing)
                            TextField(
                              controller: _controller,
                              focusNode: _focus,
                              enabled: !_saving,
                              onChanged: _onTyped,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: AppColors.neutral900,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                hintText: 'Search a city or barangay',
                                contentPadding: EdgeInsets.zero,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                            )
                          else
                            Text(
                              filled ? widget.value! : 'Not set',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                color: filled
                                    ? AppColors.neutral900
                                    : AppColors.primary,
                                fontWeight: filled
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _trailing(filled),
                  ],
                ),
                if (_editing && !_saving) _suggestions(),
                if (_error != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    style: const TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _trailing(bool filled) {
    if (_saving) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_editing) {
      // No tick here on purpose. There is nothing to confirm - a location is
      // committed by choosing one from the list, never by what was typed.
      return IconButton(
        onPressed: _cancel,
        icon: const Icon(Icons.close, size: 20, color: AppColors.neutral500),
        tooltip: 'Cancel',
        visualDensity: VisualDensity.compact,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Icon(
        filled ? Icons.edit_outlined : Icons.add,
        size: 19,
        color: filled ? AppColors.neutral400 : AppColors.primary,
      ),
    );
  }

  Widget _suggestions() {
    return Consumer<LocationProvider>(
      builder: (context, locations, _) {
        // Read here, not above: this builder also runs on its own when the
        // provider notifies, and a value captured outside it would be stale.
        final typed = _controller.text.trim();

        if (typed.length < 2) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Type at least two letters.',
              style: TextStyle(fontSize: 12, color: AppColors.neutral500),
            ),
          );
        }

        if (locations.isSearching) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (locations.results.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No place found by that name.',
              style: TextStyle(fontSize: 12, color: AppColors.neutral500),
            ),
          );
        }

        // Capped and scrollable: this sits inside a list, and an unbounded
        // run of results would push the rest of the profile off screen.
        return Container(
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(maxHeight: 210),
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: locations.results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final place = locations.results[i];
              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(
                  place.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5),
                ),
                subtitle: place.provinceName == null
                    ? null
                    : Text(
                        place.provinceName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5),
                      ),
                onTap: () => _pick(place),
              );
            },
          ),
        );
      },
    );
  }
}
