import 'package:dio/dio.dart';
import '../../core/config.dart';

const reactionEmoji = {
  'like': '👍',
  'love': '❤️',
  'haha': '😂',
  'wow': '😮',
  'sad': '😢',
  'fire': '🔥'
};

class ReviewEngagement {
  const ReviewEngagement(
      {this.reactionCounts = const {}, this.commentCount = 0, this.myReaction});
  final Map<String, int> reactionCounts;
  final int commentCount;
  final String? myReaction;
  factory ReviewEngagement.fromJson(Map<String, dynamic> json) =>
      ReviewEngagement(
          reactionCounts: (json['reactionCounts'] as Map? ?? {}).map(
              (key, value) => MapEntry(key.toString(), (value as num).toInt())),
          commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
          myReaction: json['myReaction'] as String?);
}

class ReviewComment {
  const ReviewComment(
      {required this.id,
      required this.content,
      required this.userName,
      required this.avatar,
      required this.createdAt,
      required this.isMine,
      required this.isDeleted,
      this.parentId,
      this.replyCount = 0});
  final String id, content, userName, avatar;
  final String? parentId;
  final DateTime createdAt;
  final bool isMine, isDeleted;
  final int replyCount;
  factory ReviewComment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map;
    return ReviewComment(
        id: json['id'] as String,
        content: json['content'] as String,
        userName: user['name'] as String? ?? 'Người dùng',
        avatar: user['avatar'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        isMine: json['isMine'] == true,
        isDeleted: json['isDeleted'] == true,
        parentId: json['parentCommentId'] as String?,
        replyCount: (json['replyCount'] as num?)?.toInt() ?? 0);
  }
  ReviewComment withReplies(int value) => ReviewComment(
      id: id,
      content: content,
      userName: userName,
      avatar: avatar,
      createdAt: createdAt,
      isMine: isMine,
      isDeleted: isDeleted,
      parentId: parentId,
      replyCount: value);
  ReviewComment deleted() => ReviewComment(
      id: id,
      content: 'Bình luận đã xóa',
      userName: userName,
      avatar: avatar,
      createdAt: createdAt,
      isMine: false,
      isDeleted: true,
      parentId: parentId,
      replyCount: replyCount);
}

class CommentPage {
  const CommentPage(this.items, this.page, this.hasMore);
  final List<ReviewComment> items;
  final int page;
  final bool hasMore;
  factory CommentPage.fromJson(Map<String, dynamic> json) => CommentPage(
      (json['items'] as List)
          .map((item) =>
              ReviewComment.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      json['page'] as int,
      json['hasMore'] as bool);
}

class CommentResult {
  CommentResult(Map<String, dynamic> json)
      : item = ReviewComment.fromJson(
            Map<String, dynamic>.from(json['item'] as Map)),
        engagement = ReviewEngagement.fromJson(
            Map<String, dynamic>.from(json['engagement'] as Map));
  final ReviewComment item;
  final ReviewEngagement engagement;
}

class EngagementApi {
  EngagementApi()
      : _dio = Dio(BaseOptions(
            baseUrl: AppConfig.backendBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20)));
  final Dio _dio;
  Options _options(String? token, [String method = 'GET']) => Options(
      method: method,
      headers: token == null ? {} : {'Authorization': 'Bearer $token'});
  Future<ReviewEngagement> engagement(String id, String? token) async {
    final response = await _dio.get<Map<String, dynamic>>(
        '/community/reviews/$id/engagement',
        options: _options(token));
    return ReviewEngagement.fromJson(response.data!);
  }

  Future<ReviewEngagement> react(String id, String token, String? type) async {
    final response = await _dio.request<Map<String, dynamic>>(
        '/community/reviews/$id/reaction',
        data: type == null ? null : {'type': type},
        options: _options(token, type == null ? 'DELETE' : 'PUT'));
    return ReviewEngagement.fromJson(response.data!);
  }

  Future<CommentPage> comments(String reviewId, String? token, int page,
      {String? parentId}) async {
    final path = parentId == null
        ? '/community/reviews/$reviewId/comments'
        : '/community/comments/$parentId/replies';
    final response = await _dio.get<Map<String, dynamic>>(path,
        queryParameters: {'page': page, 'limit': 10}, options: _options(token));
    return CommentPage.fromJson(response.data!);
  }

  Future<CommentResult> write(String reviewId, String token, String content,
      {String? parentId, String? editId}) async {
    final path = editId != null
        ? '/community/comments/$editId'
        : parentId != null
            ? '/community/comments/$parentId/replies'
            : '/community/reviews/$reviewId/comments';
    final response = await _dio.request<Map<String, dynamic>>(path,
        data: {'content': content},
        options: _options(token, editId == null ? 'POST' : 'PATCH'));
    return CommentResult(response.data!);
  }

  Future<ReviewEngagement> remove(String id, String token) async {
    final response = await _dio.delete<Map<String, dynamic>>(
        '/community/comments/$id',
        options: _options(token));
    return ReviewEngagement.fromJson(
        Map<String, dynamic>.from(response.data!['engagement'] as Map));
  }
}
