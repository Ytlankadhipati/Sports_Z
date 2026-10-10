import 'package:dio/dio.dart';

/// ST02 / A08 — account identity read from `GET /me`.
///
/// The server already masks email and phone; the client never sees (or asks
/// for) the full values.
class AccountRepository {
  AccountRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get<Object?>('/me');
    final body = response.data;
    if (body is! Map) throw const FormatException('Invalid API response');
    final data = body['data'];
    if (data is! Map) throw const FormatException('Invalid API response');
    return Map<String, dynamic>.from(data);
  }
}
