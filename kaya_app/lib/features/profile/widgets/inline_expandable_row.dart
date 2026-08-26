import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/*
    A profile entry that opens into its own form, in place.

    Some things on a profile are not one line of text. A job you held has a
    title, an employer, two dates and a description; a licence has a name, an
    authority, a date and a scanned document. None of that fits in a single
    field, which is why they were the last parts still pushing a whole screen.

    They do not need a screen. Tapping the entry expands it into its fields
    right where it sits, and the rest of the profile stays above and below it.
    Saving collapses it again.

    Only one thing expands at a time, which the caller enforces - two open
    forms in a list is how somebody ends up typing into the wrong one.
*/
class InlineExpandableRow extends StatelessWidget {
  const InlineExpandableRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.onSave,
    required this.children,
    this.onDelete,
    this.deleteLabel = 'Remove',
    this.saving = false,
    this.error,
    this.saveLabel = 'Save',
  });

  final String title;
  final String? subtitle;

  final bool expanded;
  final VoidCallback onToggle;

  final VoidCallback onSave;
  final VoidCallback? onDelete;
  final String deleteLabel;
  final String saveLabel;

  /// The fields, supplied by whoever owns the data.
  final List<Widget> children;

  final bool saving;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error != null
                  ? AppColors.error
                  : expanded
                      ? AppColors.primary.withValues(alpha: 0.45)
                      : AppColors.neutral200,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: saving ? null : onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.isEmpty ? 'Untitled' : title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.neutral900,
                              ),
                            ),
                            if (subtitle != null && subtitle!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.neutral600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        expanded ? Icons.expand_less : Icons.edit_outlined,
                        size: 19,
                        color: expanded
                            ? AppColors.primary
                            : AppColors.neutral400,
                      ),
                    ],
                  ),
                ),
              ),
              // Built only while open. Keeping the fields alive collapsed would
              // hold stale controllers for every entry in the list.
              if (expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      ...children,
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.error),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (onDelete != null)
                            TextButton.icon(
                              onPressed: saving ? null : onDelete,
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: Text(deleteLabel),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.error,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          const Spacer(),
                          TextButton(
                            onPressed: saving ? null : onToggle,
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 4),
                          FilledButton(
                            onPressed: saving ? null : onSave,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: saving
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(saveLabel),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A labelled field for use inside an expandable row.
///
/// Defined here so every inline form on the profile looks the same, rather
/// than each one inventing its own spacing and border.
class InlineField extends StatelessWidget {
  const InlineField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.suffix,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;

  /// For fields opened by a picker rather than typed, like a date.
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffix;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        enabled: enabled,
        onTap: onTap,
        style: const TextStyle(fontSize: 14, color: AppColors.neutral900),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffix,
          isDense: true,
          labelStyle: const TextStyle(fontSize: 13),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.neutral300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}
