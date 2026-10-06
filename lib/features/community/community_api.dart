import 'package:dio/dio.dart';
import '../../core/config.dart';
import '../reviews/review_model.dart';

class CommunityApi {
  final Dio _dio = Dio(BaseOptions(
      baseUrl: AppConfig.backendBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20)));
  Future<Map<String, dynamic>> request(String path, String? token,
      {String method = 'GET',
      Object? data,
      Map<String, dynamic>? query}) async {
    final result = await _dio.request<Map<String, dynamic>>('/community$path',
        data: data,
        queryParameters: query,
        options: Options(
            method: method,
            headers: token == null ? {} : {'Authorization': 'Bearer $token'}));
    return result.data!;
  }

  Future<ReviewPage> reviews(String path, String? token, int page) async =>
      ReviewPage.fromJson(
          await request(path, token, query: {'page': page, 'limit': 10}));
}
