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
        'cursor': ?cursor,
      },
    );
    final body = response.data;
    if (body is! Map || body['data'] is! List) {
      throw const FormatException('Invalid events response');
    }
    final items = (body['data'] as List)
        .whereType<Map>()
        .map((item) => SportEvent.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return EventPage(
      items,
      body['meta'] is Map
          ? (body['meta'] as Map)['next_cursor'] as String?
          : null,
    );
  }

  Future<EventDetail> getById(String publicId) async {
    final response = await _dio.get<Object?>(
      '/events/${Uri.encodeComponent(publicId)}',
    );
    final data = _payload(response.data);
    if (data is! Map) {
      throw const FormatException('Invalid event response');
    }
    return EventDetail.fromJson(Map<String, dynamic>.from(data));
  }

  Future<EventRegistrationResult> register(String publicId) async {
    final response = await _dio.post<Object?>(
      '/events/${Uri.encodeComponent(publicId)}/register',
      data: const <String, dynamic>{},
    );
    final data = _payload(response.data);
    if (data is! Map) {
      throw const FormatException('Invalid registration response');
    }
    return EventRegistrationResult.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> cancel(String publicId) async {
    await _dio.delete<Object?>(
      '/events/${Uri.encodeComponent(publicId)}/register',
    );
  }

  Future<MyEventRegistrationPage> myRegistrations({
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Object?>(
      '/me/event-registrations',
      queryParameters: {'limit': limit, 'cursor': ?cursor},
    );
    final body = response.data;
    if (body is! Map || body['data'] is! List) {
      throw const FormatException('Invalid registrations response');
    }
    final items = (body['data'] as List)
        .whereType<Map>()
        .map((e) => MyEventRegistration.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return MyEventRegistrationPage(
      items,
      body['meta'] is Map
          ? (body['meta'] as Map)['next_cursor'] as String?
          : null,
    );
  }

  Object? _payload(Object? body) => body is Map ? body['data'] : null;
}
