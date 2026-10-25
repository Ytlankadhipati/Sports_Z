import 'package:dio/dio.dart';

/// Helpers for the SportsZ envelope {data, meta{next_cursor, request_id}}.
Map<String, dynamic> dataMap(Response<Object?> response) {
  final body = response.data;
  if (body is Map && body['data'] is Map) {
    return Map<String, dynamic>.from(body['data'] as Map);
  }
  throw const FormatException('Invalid response');
}

List<Map<String, dynamic>> dataList(Response<Object?> response) {
  final body = response.data;
  if (body is Map && body['data'] is List) {
    return (body['data'] as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  throw const FormatException('Invalid response');
}

String? nextCursorOf(Response<Object?> response) {
  final body = response.data;
  final meta = body is Map ? body['meta'] : null;
  return meta is Map ? meta['next_cursor'] as String? : null;
}
