import 'package:dio/dio.dart';
import 'package:sports_z/features/opportunities/data/datasources/opportunities_api.dart';
import 'package:sports_z/features/saved/data/models/saved_item.dart';

class SavedApi {
  SavedApi(this._dio);

  final Dio _dio;

  Future<SavedPage> list({String? type, String? cursor, int limit = 20}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/saved',
        queryParameters: {
          'limit': limit,
          'type': ?type,
          'cursor': ?cursor,
        },
      );
      final body = response.data ?? <String, dynamic>{};
      final items = (body['data'] as List)
          .map((item) => SavedItem.fromJson(item as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;
      return SavedPage(items, meta['next_cursor'] as String?);
    } on DioException catch (error) {
      _throwError(error, action: 'load_saved');
    }
  }

  Future<void> save(String type, String targetId) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/v1/saved',
        data: {'type': type, 'target_id': targetId},
      );
    } on DioException catch (error) {
      _throwError(error, action: 'save');
    }
  }

  Future<void> remove(String type, String targetId) async {
    try {
      await _dio.delete<void>(
        '/v1/saved/${Uri.encodeComponent(type)}/${Uri.encodeComponent(targetId)}',
      );
    } on DioException catch (error) {
      _throwError(error, action: 'remove');
    }
  }

  Never _throwError(DioException error, {required String action}) {
    final status = error.response?.statusCode;
    if (error.error is LoginRequired) throw Exception('Please log in again.');
    if (status == 401) throw Exception('Session expired. Please log in again.');
    if (status == 404) throw Exception('This item is no longer available.');
    if (status == 422) throw Exception('This item cannot be saved.');
    if (status != null) throw Exception('Could not $action items ($status).');
    throw Exception('Could not connect to the server. Please try again.');
  }
}
