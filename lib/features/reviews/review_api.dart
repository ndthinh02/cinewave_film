import 'package:dio/dio.dart';
import '../../core/config.dart';
import 'review_model.dart';

class ReviewApi {
  ReviewApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
                baseUrl: AppConfig.backendBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20)));
  final Dio _dio;
  String _path(String slug) => '/community/movies/${Uri.encodeComponent(slug)}';
  Options _options(String? token) =>
      Options(headers: token == null ? {} : {'Authorization': 'Bearer $token'});

  Future<ReviewPage> list(String slug, String? token, {int page = 1}) async {
    final response = await _dio.get<Map<String, dynamic>>(
        '${_path(slug)}/reviews',
        queryParameters: {'page': page, 'limit': 10},
        options: _options(token));
    return ReviewPage.fromJson(response.data!);
  }

  Future<MovieReview?> mine(String slug, String token) async {
    final response = await _dio.get<Map<String, dynamic>>(
        '${_path(slug)}/reviews/me',
        options: _options(token));
    final item = response.data!['item'];
    return item == null
        ? null
        : MovieReview.fromJson(Map<String, dynamic>.from(item as Map));
  }

  Future<MovieReview> save(
      String slug, String token, String content, bool hasSpoiler) async {
    final response = await _dio.put<Map<String, dynamic>>(
        '${_path(slug)}/review',
        data: {'content': content, 'hasSpoiler': hasSpoiler},
        options: _options(token));
    return MovieReview.fromJson(
        Map<String, dynamic>.from(response.data!['item'] as Map));
  }

  Future<void> remove(String slug, String token) async {
    await _dio.delete('${_path(slug)}/review', options: _options(token));
  }
}
