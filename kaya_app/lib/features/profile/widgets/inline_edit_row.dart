import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';

/*
    A profile field you edit where it sits.

    Every field on this profile used to be a row that pushed a whole screen:
    tap Full Name, wait for a page transition, edit one text box, tap save,
    wait for the transition back. Nine fields meant eighteen transitions to
    correct a typo in each, and you could not see any other field while you
    were editing one.

    Tapping a row here puts a cursor in it and raises the keyboard. That is the
    entire interaction. Nothing navigates, nothing is lost on the way back, and
    the rest of the profile stays on screen while you type.

    Two safeguards, because editing in place is easy to do by accident:
    dismissing without saving keeps the original, and clearing a field that had
    something in it asks first - that is the one edit nobody performs on
    purpose and the one that silently destroys data.
*/
class InlineEditRow extends StatefulWidget {
  const InlineEditRow({
    super.key,
    required this.label,
    required this.value,
    required this.onSave,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.emptyLabel = 'Not set',
    this.enabled = true,
    this.disabledNote,
  });

  final String label;

  /// What is stored now. Null or empty renders as an invitation to fill it in.
  final String? value;

  /// Returns an error message, or null when the save worked.
  final Future<String?> Function(String newValue) onSave;

  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;

  /// Checked before saving. Return a message to refuse, null to allow.
  final String? Function(String)? validator;

  final String emptyLabel;

  /// For fields that are shown but cannot be changed here.
  final bool enabled;
  final String? disabledNote;

  @override
  State<InlineEditRow> createState() => _InlineEditRowState();
}

class _InlineEditRowState extends State<InlineEditRow> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');
  final FocusNode _focus = FocusNode();

  bool _editing = false;
  bool _saving = false;
  String? _error;

  @override
  void didUpdateWidget(InlineEditRow old) {
    super.didUpdateWidget(old);
    // A value refreshed from the server while this row is idle should show.
    // Doing it mid-edit would overwrite what is being typed.
    if (!_editing && widget.value != old.value) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEditing() {
    if (!widget.enabled) {
      if (widget.disabledNote != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.disabledNote!)),
        );
      }
      return;
    }
    setState(() {
      _editing = true;
      _error = null;
      _controller.text = widget.value ?? '';
    });
    // Requested after the field exists, or there is nothing to focus.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _cancel() {
    setState(() {
      _editing = false;
      _error = null;
      _controller.text = widget.value ?? '';
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _save() async {
    final next = _controller.text.trim();
    final before = (widget.value ?? '').trim();

    if (next == before) {
      _cancel();
      return;
    }

    final invalid = widget.validator?.call(next);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }

    // Emptying a field that had content is almost always a slip.
    if (next.isEmpty && before.isNotEmpty) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('Clear ${widget.label.toLowerCase()}?'),
          content: Text('This removes what is saved there now.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep it'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final failure = await widget.onSave(next);
    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = failure;
      // Stays open on failure, so the typing is not thrown away.
      if (failure == null) _editing = false;
    });

    if (failure == null) FocusScope.of(context).unfocus();
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
            child: Row(
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
                          keyboardType: widget.keyboardType,
                          maxLines: widget.maxLines,
                          enabled: !_saving,
                          textInputAction: widget.maxLines == 1
                              ? TextInputAction.done
                              : TextInputAction.newline,
                          onSubmitted: (_) => _save(),
                          inputFormatters: widget.maxLength == null
                              ? null
                              : [
                                  LengthLimitingTextInputFormatter(
                                      widget.maxLength)
                                ],
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: AppColors.neutral900,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: widget.hint,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        )
                      else
                        Text(
                          filled ? widget.value! : widget.emptyLabel,
                          maxLines: widget.maxLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            color:
                                filled ? AppColors.neutral900 : AppColors.primary,
                            fontWeight:
                                filled ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _trailing(filled),
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
      // Both actions visible, because a cursor sitting in a field gives no
      // clue how to get out of it without saving.
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: _cancel,
            icon:
                const Icon(Icons.close, size: 20, color: AppColors.neutral500),
            tooltip: 'Cancel',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.check, size: 22, color: AppColors.primary),
            tooltip: 'Save',
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }

    if (!widget.enabled) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: Icon(Icons.lock_outline, size: 18, color: AppColors.neutral400),
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
}
