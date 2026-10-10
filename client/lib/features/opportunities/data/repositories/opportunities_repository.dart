import 'package:dio/dio.dart';

import '../models/opportunity.dart';

class OpportunitiesRepository {
  OpportunitiesRepository(this._dio);

  final Dio _dio;

  Future<OpportunityPage> list({
    String? type,
    required String status,
    String? cursor,
    int limit = 20,
  }) async {
    final response = await _dio.get<Object?>(
      '/opportunities',
      queryParameters: {
        'status': status,
        'limit': limit,
        'type': ?type,
        'cursor': ?cursor,
      },
    );
    final body = response.data;
    if (body is! Map || body['data'] is! List) {
      throw const FormatException('Invalid opportunities response');
    }
    final items = (body['data'] as List)
        .whereType<Map>()
        .map((item) => Opportunity.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return OpportunityPage(
      items,
      body['meta'] is Map
          ? (body['meta'] as Map)['next_cursor'] as String?
          : null,
    );
  }

  Future<OpportunityDetail> getById(String publicId) async {
    final response = await _dio.get<Object?>(
      '/opportunities/${Uri.encodeComponent(publicId)}',
    );
    final data = _data(response.data);
    if (data is! Map) {
      throw const FormatException('Invalid opportunity response');
    }
    return OpportunityDetail.fromJson(Map<String, dynamic>.from(data));
  }

  Object? _data(Object? body) => body is Map ? body['data'] : null;
}
