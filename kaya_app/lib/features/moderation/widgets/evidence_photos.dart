import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';

/*
    Up to three photos, each removable, with an Add tile while there is room.

    One picker for both sides of a report: the person filing it, and the
    person answering it. Evidence both ways is the point - a reply that can
    only be words is weaker than the report it answers.
*/
class EvidencePhotos extends StatelessWidget {
  const EvidencePhotos({
    super.key,
    required this.photos,
    required this.onChanged,
    required this.label,
  });

  final List<XFile> photos;
  final ValueChanged<List<XFile>> onChanged;
  final String label;

  static const max = 3;

  /// The photos as the server's `photos[]` field.
  static Future<List<MultipartFile>> files(List<XFile> photos) async => [
        for (final p in photos) await MultipartFile.fromFile(p.path, filename: p.name),
      ];

  Future<void> _add() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (picked != null) onChanged([...photos, picked]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.neutral700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < photos.length; i++)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(photos[i].path), width: 72, height: 72, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: InkWell(
                      onTap: () => onChanged([...photos]..removeAt(i)),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: AppColors.neutral900, shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 13, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            if (photos.length < max)
              InkWell(
                onTap: _add,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.neutral300),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: AppColors.neutral500),
                      SizedBox(height: 2),
                      Text('Add', style: TextStyle(fontSize: 11, color: AppColors.neutral500)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
