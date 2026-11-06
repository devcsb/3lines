import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/entry_repository.dart';

final isBookmarkedProvider = StreamProvider.autoDispose.family<bool, String>(
  (ref, date) => ref.watch(entryRepositoryProvider).watchIsBookmarked(date),
);

class BookmarkButton extends ConsumerStatefulWidget {
  const BookmarkButton({super.key, required this.date});

  final String date;

  @override
  ConsumerState<BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends ConsumerState<BookmarkButton> {
  bool _busy = false;
  bool _failed = false;

  Future<void> _setBookmark(bool value) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final updated = await ref
          .read(entryRepositoryProvider)
          .setBookmarked(widget.date, value);
      if (mounted && !updated) setState(() => _failed = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookmark = ref.watch(isBookmarkedProvider(widget.date));
    return bookmark.when(
      loading: () =>
          const TextButton(onPressed: null, child: Text('책갈피 불러오는 중')),
      error: (_, _) => TextButton.icon(
        onPressed: () => ref.invalidate(isBookmarkedProvider(widget.date)),
        icon: const Icon(Icons.refresh),
        label: const Text('책갈피 다시 불러오기'),
      ),
      data: (selected) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            toggled: selected,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _setBookmark(!selected),
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: Icon(
                selected
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
              label: Text(
                _busy
                    ? '책갈피 반영 중'
                    : selected
                    ? '책갈피 해제'
                    : '책갈피에 담기',
              ),
            ),
          ),
          if (_failed)
            Semantics(
              liveRegion: true,
              child: Text(
                '책갈피를 바꾸지 못했어요. 다시 눌러 주세요.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
