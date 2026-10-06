import 'engagement_api.dart';

class MovieReview {
  const MovieReview(
      {this.engagement = const ReviewEngagement(),
      required this.id,
      required this.movieSlug,
      required this.content,
      required this.hasSpoiler,
      required this.userId,
      required this.userName,
      required this.avatar,
      required this.rating,
      required this.isMine,
      required this.createdAt,
      required this.updatedAt});

  final String id, movieSlug, content, userId, userName, avatar;
  final bool hasSpoiler, isMine;
  final int? rating;
  final DateTime createdAt, updatedAt;
  final ReviewEngagement engagement;

  factory MovieReview.fromJson(Map<String, dynamic> json) {
    final user = Map<String, dynamic>.from(json['user'] as Map);
    return MovieReview(
        engagement: ReviewEngagement.fromJson(json),
        id: json['id'] as String,
        movieSlug: json['movieSlug'] as String,
        content: json['content'] as String,
        hasSpoiler: json['hasSpoiler'] == true,
        userId: user['id'] as String,
        userName: user['name'] as String? ?? 'Người dùng',
        avatar: user['avatar'] as String? ?? '',
        rating: (json['rating'] as num?)?.toInt(),
        isMine: json['isMine'] == true,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String));
  }

  MovieReview withRating(int? value) => MovieReview(
      engagement: engagement,
      id: id,
      movieSlug: movieSlug,
      content: content,
      hasSpoiler: hasSpoiler,
      userId: userId,
      userName: userName,
      avatar: avatar,
      rating: value,
      isMine: isMine,
      createdAt: createdAt,
      updatedAt: updatedAt);

  MovieReview withEngagement(ReviewEngagement value) => MovieReview(
      engagement: value,
      id: id,
      movieSlug: movieSlug,
      content: content,
      hasSpoiler: hasSpoiler,
      userId: userId,
      userName: userName,
      avatar: avatar,
      rating: rating,
      isMine: isMine,
      createdAt: createdAt,
      updatedAt: updatedAt);
}

class ReviewPage {
  const ReviewPage(
      {required this.items,
      required this.page,
      required this.limit,
      required this.hasMore,
      required this.total});

  final List<MovieReview> items;
  final int page, limit, total;
  final bool hasMore;

  factory ReviewPage.fromJson(Map<String, dynamic> json) => ReviewPage(
      items: (json['items'] as List)
          .map((item) =>
              MovieReview.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      page: json['page'] as int,
      limit: json['limit'] as int,
      hasMore: json['hasMore'] as bool,
      total: json['total'] as int);
}
