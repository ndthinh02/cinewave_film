import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

String relativeTime(Object? value) {
  final date = value is DateTime ? value : DateTime.tryParse('$value');
  if (date == null) return '';
  final elapsed = DateTime.now().difference(date);
  if (elapsed.inMinutes < 1) return 'Vừa xong';
  if (elapsed.inHours < 1) return '${elapsed.inMinutes} phút trước';
  if (elapsed.inDays < 1) return '${elapsed.inHours} giờ trước';
  if (elapsed.inDays < 7) return '${elapsed.inDays} ngày trước';
  return DateFormat('dd/MM/yyyy').format(date.toLocal());
}

void cineFeedback(BuildContext context, String message, {bool error = false}) {
  final colors = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        content: Text(message), backgroundColor: error ? colors.error : null));
}

class CineState extends StatelessWidget {
  const CineState(
      {super.key,
      required this.title,
      required this.description,
      this.icon = Icons.movie_outlined,
      this.action,
      this.actionLabel = 'Thử lại'});
  final String title, description, actionLabel;
  final IconData icon;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Center(
      child: SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        shape: BoxShape.circle),
                    child: Icon(icon,
                        size: 32,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 20),
                Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                if (action != null) ...[
                  const SizedBox(height: 16),
                  TextButton(onPressed: action, child: Text(actionLabel))
                ],
              ]))));
}

class CineAvatar extends StatelessWidget {
  const CineAvatar({super.key, required this.url, this.radius = 20});
  final String url;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipOval(
      child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: url.isEmpty
              ? CircleAvatar(
                  radius: radius, child: const Icon(Icons.person_outline))
              : CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      const CircleAvatar(child: Icon(Icons.person_outline)),
                  errorWidget: (_, __, ___) =>
                      const CircleAvatar(child: Icon(Icons.person_outline)))));
}

class CineSection extends StatelessWidget {
  const CineSection(
      {super.key,
      required this.title,
      this.subtitle,
      this.action,
      this.actionLabel = 'Xem tất cả'});
  final String title, actionLabel;
  final String? subtitle;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null)
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)
        ])),
        if (action != null)
          TextButton(onPressed: action, child: Text(actionLabel))
      ]));
}
