import 'package:dio/dio.dart';

import '../models/saved_item.dart';

class SavedRepository {
  SavedRepository(this._dio);
  final Dio _dio;

  Future<SavedPage> list({String? type, String? cursor, int limit = 20}) async {
    final response = await _dio.get<Object?>(
      '/saved',
      queryParameters: {
        'limit': limit,
        'type': ?type,
        'cursor': ?cursor,
      },
    );
    final body = response.data;
    if (body is! Map || body['data'] is! List) {
      throw const FormatException('Invalid saved response');
    }
    final items = (body['data'] as List)
        .whereType<Map>()
        .map((item) => SavedItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final meta = body['meta'];
    return SavedPage(
      items,
      meta is Map ? meta['next_cursor'] as String? : null,
    );
  }

  Future<void> save(String type, String targetId) async {
    await _dio.post<Object?>(
      '/saved',
      data: {'type': type, 'target_id': targetId},
    );
  }

  Future<void> unsave(String type, String targetId) async {
    await _dio.delete<Object?>(
      '/saved/${Uri.encodeComponent(type)}/${Uri.encodeComponent(targetId)}',
    );
  }
}
