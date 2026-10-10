import 'package:dio/dio.dart';
import 'package:sports_z/features/events/data/models/event.dart';

class EventsApi {
  EventsApi(this._dio);

  final Dio _dio;

  Future<EventPage> list({
    String status = 'upcoming',
    String? sportId,
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/events',
        queryParameters: {
          'status': status,
          'limit': limit,
          'sport_id': ?sportId,
          'cursor': ?cursor,
        },
      );
      final body = response.data ?? <String, dynamic>{};
      final items = (body['data'] as List)
          .map((item) => SportEvent.fromJson(item as Map<String, dynamic>))
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;
      return EventPage(items, meta['next_cursor'] as String?);
    } on DioException catch (error) {
      _throwError(error, action: 'load_events');
    }
  }

  Future<EventDetail> getById(String publicId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/events/${Uri.encodeComponent(publicId)}',
      );
      final body = response.data ?? <String, dynamic>{};
      return EventDetail.fromJson(body['data'] as Map<String, dynamic>);
    } on DioException catch (error) {
      _throwError(error, action: 'load_event');
    }
  }

  Future<EventRegistrationResult> register(String publicId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/events/${Uri.encodeComponent(publicId)}/register',
        data: const <String, dynamic>{},
      );
      return EventRegistrationResult.fromJson(
        (response.data ?? <String, dynamic>{})['data'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      _throwError(error, action: 'register');
    }
  }

  Future<void> cancel(String publicId) async {
    try {
      await _dio.delete<Map<String, dynamic>>(
        '/v1/events/${Uri.encodeComponent(publicId)}/register',
      );
    } on DioException catch (error) {
      _throwError(error, action: 'cancel');
    }
  }

  Future<MyEventRegistrationPage> myRegistrations({
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/me/event-registrations',
        queryParameters: {'limit': limit, 'cursor': ?cursor},
      );
      final body = response.data ?? <String, dynamic>{};
      final items = (body['data'] as List)
          .map(
            (item) =>
                MyEventRegistration.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      final meta = body['meta'] as Map<String, dynamic>;
      return MyEventRegistrationPage(items, meta['next_cursor'] as String?);
    } on DioException catch (error) {
      _throwError(error, action: 'my_registrations');
    }
  }

  Never _throwError(DioException error, {required String action}) {
    final status = error.response?.statusCode;
    final code = _errorCode(error);
    if (status == 401) {
      throw Exception('Session expired. Please log in again.');
    }
    if (status == 404) {
      if (action == 'cancel') {
        throw Exception('No active registration was found for this event.');
      }
      throw Exception('This event is no longer available.');
    }
    if (status == 409) {
      switch (code) {
        case 'DUPLICATE_REGISTRATION':
          throw Exception('You already have an active registration.');
        case 'REGISTRATION_DEADLINE_PASSED':
          throw Exception('The registration deadline has passed.');
        case 'EVENT_CLOSED':
          throw Exception('This event is not open for registration.');
        case 'CANCELLATION_IN_PROGRESS':
          throw Exception('Your cancellation is already being processed.');
        default:
          throw Exception('Event availability changed. Please try again.');
      }
    }
    if (status != null) {
      final resource = action == 'my_registrations'
          ? 'registrations'
          : 'events';
      throw Exception('Could not $action $resource ($status).');
    }
    throw Exception('Could not connect to the server. Please try again.');
  }

  String? _errorCode(DioException error) {
    final data = error.response?.data;
    if (data is! Map) return null;
    final details = data['error'];
    if (details is! Map) return null;
    final code = details['code'];
    return code is String ? code : null;
  }
}
