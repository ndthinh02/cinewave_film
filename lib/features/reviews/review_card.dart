import 'package:flutter/material.dart';
import '../../widgets/cine_ui.dart';
import 'review_model.dart';
import 'engagement_api.dart';

class ReviewCard extends StatefulWidget {
  const ReviewCard(
      {super.key,
      required this.review,
      required this.avatarUrl,
      this.onEdit,
      this.onDelete,
      this.onReact,
      this.onComments,
      this.onProfile,
      this.movieContext,
      this.interactionLoading = false});
  final MovieReview review;
  final String avatarUrl;
  final VoidCallback? onEdit, onDelete;
  final VoidCallback? onReact, onComments;
  final VoidCallback? onProfile;
  final bool interactionLoading;
  final Widget? movieContext;
  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool _revealed = false;
  @override
  void didUpdateWidget(covariant ReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.id != widget.review.id ||
        oldWidget.review.content != widget.review.content ||
        oldWidget.review.hasSpoiler != widget.review.hasSpoiler) {
      _revealed = false;
    }
  }

  String _time(DateTime date) {
    final elapsed = DateTime.now().difference(date);
    if (elapsed.inMinutes < 1) return 'Vừa xong';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes} phút trước';
    if (elapsed.inDays < 1) return '${elapsed.inHours} giờ trước';
    if (elapsed.inDays < 7) return '${elapsed.inDays} ngày trước';
    return relativeTime(date);
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final colors = Theme.of(context).colorScheme;
    return Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              GestureDetector(
                  onTap: widget.onProfile,
                  child: CineAvatar(url: widget.avatarUrl)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    GestureDetector(
                        onTap: widget.onProfile,
                        child: Text(review.userName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                    Text(_time(review.createdAt),
                        style: TextStyle(
                            color: colors.onSurfaceVariant, fontSize: 12)),
                  ])),
              if (review.rating != null)
                Chip(
                    avatar: Icon(Icons.star_rounded,
                        size: 16, color: colors.primary),
                    label: Text('${review.rating}/10'),
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact),
              if (review.isMine &&
                  (widget.onEdit != null || widget.onDelete != null))
                PopupMenuButton<String>(
                    onSelected: (value) => value == 'edit'
                        ? widget.onEdit?.call()
                        : widget.onDelete?.call(),
                    itemBuilder: (_) => [
                          if (widget.onEdit != null)
                            const PopupMenuItem(
                                value: 'edit', child: Text('Chỉnh sửa')),
                          if (widget.onDelete != null)
                            const PopupMenuItem(
                                value: 'delete', child: Text('Xóa')),
                        ]),
            ]),
            const SizedBox(height: 12),
            if (widget.movieContext != null) ...[
              widget.movieContext!,
              const SizedBox(height: 16)
            ],
            if (review.hasSpoiler && !_revealed) ...[
              const Row(children: [
                Icon(Icons.visibility_off_outlined, size: 18),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Nội dung có spoiler',
                        style: TextStyle(fontWeight: FontWeight.w700)))
              ]),
              const Text('Review này có thể tiết lộ nội dung phim.'),
              TextButton(
                  onPressed: () => setState(() => _revealed = true),
                  child: const Text('Hiện nội dung')),
            ] else
              Text(review.content,
                  style: Theme.of(context).textTheme.bodyMedium),
            if (widget.onReact != null || widget.onComments != null) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                for (final entry in review.engagement.reactionCounts.entries)
                  if (entry.value > 0)
                    Text('${reactionEmoji[entry.key] ?? ''} ${entry.value}'),
              ]),
              Wrap(spacing: 8, children: [
                TextButton(
                    onPressed:
                        widget.interactionLoading ? null : widget.onReact,
                    child: Text(review.engagement.myReaction == null
                        ? 'Thả cảm xúc'
                        : '${reactionEmoji[review.engagement.myReaction]} Đã thả cảm xúc')),
                TextButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    onPressed: widget.onComments,
                    label: Text('${review.engagement.commentCount} bình luận')),
              ]),
              if (widget.interactionLoading) const LinearProgressIndicator(),
            ],
          ]),
        ));
  }
}
