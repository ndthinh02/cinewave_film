import 'package:dio/dio.dart';

import '../../core/config.dart';

class RatingSummary {
  const RatingSummary(
      {required this.averageRating, required this.ratingCount, this.myRating});
  final double? averageRating;
  final int ratingCount;
  final int? myRating;

  factory RatingSummary.fromJson(Map<String, dynamic> json) => RatingSummary(
        averageRating: (json['averageRating'] as num?)?.toDouble(),
        ratingCount: (json['ratingCount'] as num).toInt(),
        myRating: (json['myRating'] as num?)?.toInt(),
      );
}

class RatingApi {
  RatingApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.backendBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 20),
            ));
  final Dio _dio;

  Future<RatingSummary> request(String slug, String? token,
      {int? score, bool delete = false}) async {
    final response = await _dio.request<Map<String, dynamic>>(
      '/community/movies/${Uri.encodeComponent(slug)}/${score != null || delete ? 'rating' : 'summary'}',
      data: score == null ? null : {'score': score},
      options: Options(
        method: delete
            ? 'DELETE'
            : score != null
                ? 'PUT'
                : 'GET',
        headers: token == null ? {} : {'Authorization': 'Bearer $token'},
      ),
    );
    return RatingSummary.fromJson(response.data!);
  }
}
