import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/category_model.dart';
import '../../providers/worker_profile_provider.dart';
import '../constants/app_colors.dart';
import 'app_toast.dart';
import 'kaya_popup.dart';
import 'loading.dart';

/*
    One of your own custom categories, off your list, after asking.

    It lived in the Post a Job form, so a worker who never posts a job had no
    way to remove a category they had added.
*/
Future<bool> removeCustomCategory(BuildContext context, CategoryModel category) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remove This Category?'),
      content: Text('"${category.name}" will no longer be on your list. '
          'Your skills under it stay, and closed job posts keep the name.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;

  final provider = context.read<WorkerProfileProvider>();
  final error = await withPleaseWait(context, () => provider.removeCustomCategory(category));
  if (!context.mounted) return error == null;

  if (error != null) {
    AppToast.error(context, error);
    return false;
  }
  AppToast.success(context, 'Category removed');
  return true;
}

/// Pick a job category. Your own carry a delete icon; [onRemoved] is told.
Future<CategoryModel?> pickCategory(
  BuildContext context, {
  int? selectedId,
  ValueChanged<CategoryModel>? onRemoved,
}) =>
    showKayaPopup<CategoryModel>(
      context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Job Category',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neutral900),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: Consumer<WorkerProfileProvider>(
                builder: (context, taxonomy, _) => ListView(
                  shrinkWrap: true,
                  children: [
                    for (final category in taxonomy.categories)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          category.name,
                          style: TextStyle(
                            fontWeight: category.id == selectedId ? FontWeight.w600 : FontWeight.normal,
                            color: category.id == selectedId ? AppColors.primary : AppColors.neutral900,
                          ),
                        ),
                        trailing: category.isCustom
                            ? IconButton(
                                tooltip: 'Remove This Category',
                                icon: const Icon(Icons.delete_outline, color: AppColors.neutral500),
                                onPressed: () async {
                                  if (await removeCustomCategory(context, category)) onRemoved?.call(category);
                                },
                              )
                            : category.id == selectedId
                                ? const Icon(Icons.check, color: AppColors.primary)
                                : null,
                        onTap: () => Navigator.pop(sheetContext, category),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
