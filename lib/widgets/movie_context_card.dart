import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/movie.dart';
import '../services/movie_metadata.dart';
import '../screens/detail_screen.dart';

class MovieContextCard extends StatefulWidget {
  const MovieContextCard(
      {super.key,
      required this.slug,
      this.movie,
      this.subtitle,
      this.trailing,
      this.progress});
  final String slug;
  final Movie? movie;
  final String? subtitle;
  final Widget? trailing;
  final double? progress;
  @override
  State<MovieContextCard> createState() => _MovieContextCardState();
}

class _MovieContextCardState extends State<MovieContextCard> {
  late Future<Movie> _movie;
  void _resolve() {
    final supplied = widget.movie;
    if (supplied != null &&
        supplied.name.isNotEmpty &&
        supplied.name != supplied.slug) {
      MovieMetadata.remember(supplied);
      _movie = Future.value(supplied);
    } else {
      _movie = MovieMetadata.resolve(widget.slug);
    }
  }

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant MovieContextCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug || oldWidget.movie != widget.movie)
      _resolve();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Movie>(
      future: _movie,
      builder: (context, snapshot) {
        final movie = snapshot.data ??
            widget.movie ??
            MovieMetadata.fallback(widget.slug);
        final colors = Theme.of(context).colorScheme;
        final title = movie.name.isEmpty || movie.name == widget.slug
            ? MovieMetadata.fallback(widget.slug).name
            : movie.name;
        final image = movie.thumbUrl.isEmpty ? movie.posterUrl : movie.thumbUrl;
        return Material(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DetailScreen(movie: movie))),
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                              width: 56,
                              height: 80,
                              child: image.isEmpty
                                  ? ColoredBox(
                                      color: colors.surfaceContainerHighest,
                                      child: const Icon(Icons.movie_outlined))
                                  : CachedNetworkImage(
                                      imageUrl: image,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => ColoredBox(
                                          color:
                                              colors.surfaceContainerHighest),
                                      errorWidget: (_, __, ___) =>
                                          const Icon(Icons.movie_outlined)))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text(
                                [
                                  if (movie.year != null) '${movie.year}',
                                  ...movie.categories.take(2),
                                  if (movie.quality.isNotEmpty) movie.quality
                                ].join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall),
                            if (widget.subtitle != null)
                              Text(widget.subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: colors.onSurfaceVariant)),
                            if (widget.progress != null) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                      value: widget.progress!.clamp(0, 1),
                                      minHeight: 4))
                            ],
                          ])),
                      if (widget.trailing != null) widget.trailing!,
                    ]))));
      });
}
