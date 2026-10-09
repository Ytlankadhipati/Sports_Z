import 'package:dio/dio.dart';

import '../models/event.dart';

class EventsRepository {
  EventsRepository(this._dio);

  final Dio _dio;

  Future<EventPage> list({
    required String status,
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Object?>(
      '/events',
      queryParameters: {
        'status': status,
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
      },
    );
    final body = response.data;
    if (body is! Map || body['data'] is! List || body['meta'] is! Map) {
      throw const FormatException('Invalid events response');
    }
    final items = (body['data'] as List)
        .whereType<Map>()
        .map((item) => SportEvent.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return EventPage(items, (body['meta'] as Map)['next_cursor'] as String?);
  }
}
