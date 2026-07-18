import 'dart:io';

import 'package:flutter/material.dart';

/// Displays a photo attachment area: either an "add photo" button row
/// or a thumbnail with a remove button.
class PhotoAttachment extends StatelessWidget {
  final String? photoPath;
  final bool readOnly;
  final VoidCallback? onPickCamera;
  final VoidCallback? onPickGallery;
  final VoidCallback? onRemove;

  const PhotoAttachment({
    super.key,
    this.photoPath,
    this.readOnly = false,
    this.onPickCamera,
    this.onPickGallery,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (photoPath != null) {
      return _PhotoThumbnail(
        photoPath: photoPath!,
        readOnly: readOnly,
        onRemove: onRemove,
      );
    }

    if (readOnly) return const SizedBox.shrink();

    return Row(
      children: [
        _AddPhotoButton(
          icon: Icons.camera_alt_outlined,
          label: '카메라',
          onTap: onPickCamera,
        ),
        const SizedBox(width: 10),
        _AddPhotoButton(
          icon: Icons.photo_library_outlined,
          label: '갤러리',
          onTap: onPickGallery,
        ),
      ],
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final String photoPath;
  final bool readOnly;
  final VoidCallback? onRemove;

  const _PhotoThumbnail({
    required this.photoPath,
    required this.readOnly,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            File(photoPath),
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  '사진을 불러올 수 없어요',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!readOnly && onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: Semantics(
              button: true,
              label: '사진 제거',
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                    minimumSize: const Size(40, 40),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddPhotoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _AddPhotoButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
