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

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _AddPhotoButton(
          icon: Icons.camera_alt_outlined,
          label: '카메라',
          onTap: onPickCamera,
        ),
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
              constraints: const BoxConstraints(minHeight: 60),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12,
                  12,
                  !readOnly && onRemove != null ? 60 : 12,
                  12,
                ),
                child: Text(
                  '사진을 불러올 수 없어요',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
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

  const _AddPhotoButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: theme.colorScheme.onSurfaceVariant,
          backgroundColor: theme.colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label, style: theme.textTheme.labelMedium),
      ),
    );
  }
}
