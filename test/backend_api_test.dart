import 'dart:typed_data';

import 'package:cinewave/services/backend_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.status);
  final int? status;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (status == null) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.connectionTimeout);
    }
    return ResponseBody.fromString(
      status == 200 ? '{"user":{"id":"account-1","name":"Updated"}}' : '{}',
      status!,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'token': 'saved-token',
      'auth_user': '{"id":"account-1","name":"Cached"}',
    });
  });

  for (final status in <int?>[null, 500, 403]) {
    test('Restore keeps session on status $status', () async {
      final dio = Dio()..httpClientAdapter = _Adapter(status);
      final api = BackendApi(dio: dio);
      await api.restore();
      expect(api.token, 'saved-token');
      expect(api.user?['id'], 'account-1');
      expect((await SharedPreferences.getInstance()).getString('token'),
          'saved-token');
    });
  }

  test('Unauthorized response clears session and cached profile', () async {
    final dio = Dio()..httpClientAdapter = _Adapter(401);
    final api = BackendApi(dio: dio);
    await api.restore();
    expect(api.loggedIn, isFalse);
    expect(api.user, isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('token'), isNull);
    expect(preferences.getString('auth_user'), isNull);
  });

  test('Successful restore refreshes cached profile', () async {
    final dio = Dio()..httpClientAdapter = _Adapter(200);
    final api = BackendApi(dio: dio);
    await api.restore();
    expect(api.user?['name'], 'Updated');
    expect((await SharedPreferences.getInstance()).getString('auth_user'),
        contains('Updated'));
  });
}
