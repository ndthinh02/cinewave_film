import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../models/movie.dart';

class BackendApi {
  BackendApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConfig.backendBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 20),
              ),
            );
  final Dio _dio;
  String? token;
  Map<String, dynamic>? user;

  bool get loggedIn => token != null;

  Future<void> restore() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString('token');
    if (token != null) {
      final cachedUser = p.getString('auth_user');
      if (cachedUser != null) {
        try {
          user = Map<String, dynamic>.from(jsonDecode(cachedUser) as Map);
        } on FormatException {
          await p.remove('auth_user');
        } on TypeError {
          await p.remove('auth_user');
        }
      }
      try {
        final r = await _get('/auth/me');
        user = Map<String, dynamic>.from(r.data['user']);
        await p.setString('auth_user', jsonEncode(user));
      } on DioException catch (error) {
        // Mất mạng hoặc lỗi server không đồng nghĩa token đã hết hạn.
        if (error.response?.statusCode == 401) {
          await logout();
        }
      } on TypeError {
        // Phản hồi sai định dạng không xác nhận token đã hết hạn.
      }
    }
  }

  Future<Response> _get(String p) =>
      _dio.get(p, options: Options(headers: _headers));

  Future<Response> _post(String p, d) => _dio.post(
        p,
        data: d,
        options: Options(headers: _headers),
      );

  Map<String, String> get _headers =>
      token == null ? {} : {'Authorization': 'Bearer $token'};

  Future<void> login(String email, String password) async {
    final r = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    await _saveAuth(r.data);
  }

  Future<void> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      final r = await _post('/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      });

      print('REGISTER STATUS: ${r.statusCode}');
      print('REGISTER DATA: ${r.data}');

      await _saveAuth(r.data);
    } on DioException catch (e) {
      print('REGISTER ERROR STATUS: ${e.response?.statusCode}');
      print('REGISTER ERROR DATA: ${e.response?.data}');
      print('REGISTER ERROR MESSAGE: ${e.message}');

      rethrow;
    }
  }

  Future<void> _saveAuth(dynamic d) async {
    token = d['token'];
    user = Map<String, dynamic>.from(d['user']);
    final p = await SharedPreferences.getInstance();
    await p.setString('token', token!);
    await p.setString('auth_user', jsonEncode(user));
  }

  Future<void> logout() async {
    token = null;
    user = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('token');
    await preferences.remove('auth_user');
  }

  Future<List<Map<String, dynamic>>> favorites() async {
    final r = await _get('/user/favorites');
    return (r.data['items'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> addFavorite(Movie m) => _post('/user/favorites', {
        'movieSlug': m.slug,
        'name': m.name,
        'thumbUrl': m.thumbUrl,
        'posterUrl': m.posterUrl,
        'year': m.year,
      });

  Future<void> removeFavorite(String slug) =>
      _dio.delete('/user/favorites/$slug', options: Options(headers: _headers));

  Future<List<Map<String, dynamic>>> history() async {
    final r = await _get('/user/history');
    return (r.data['items'] as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> saveProgress({
    required Movie movie,
    required Episode episode,
    required int position,
    required int duration,
    bool completed = false,
  }) {
    final headers = Map<String, String>.from(_headers);

    final data = {
      'movieSlug': movie.slug,
      'movieName': movie.name,
      'thumbUrl': movie.thumbUrl,
      'episodeName': episode.name,
      'episodeSlug': episode.slug,
      'positionSeconds': position,
      'durationSeconds': duration,
      'completed': completed,
    };

    final request = _progressWrites.then((_) async {
      await _dio.put(
        '/user/progress',
        data: data,
        options: Options(headers: headers),
      );
    });

    // Một lần ghi lỗi không chặn các lần ghi tiếp theo.
    _progressWrites = request.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );

    return request;
  }

  Future<void> _progressWrites = Future<void>.value();

  String mediaUrl(String value) {
    if (value.isEmpty) return '';

    return Uri.parse(AppConfig.backendBaseUrl).resolve(value).toString();
  }

  Future<void> uploadAvatar(String filePath) async {
    final response = await _dio.put(
      '/user/avatar',
      data: FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      }),
      options: Options(headers: _headers),
    );

    user = Map<String, dynamic>.from(response.data['user']);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('auth_user', jsonEncode(user));
  }

// Home chờ lần lưu cuối hoàn tất trước khi đọc lại lịch sử.
  Future<void> flushProgress() => _progressWrites;
}
