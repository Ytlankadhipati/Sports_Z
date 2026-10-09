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
        if (type != null) 'type': type,
        if (cursor != null) 'cursor': cursor,
      },
    );
    final body = response.data;
    if (body is! Map || body['data'] is! List || body['meta'] is! Map) {
      throw const FormatException('Invalid opportunities response');
    }
    final items = (body['data'] as List)
        .whereType<Map>()
        .map((item) => Opportunity.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return OpportunityPage(
      items,
      (body['meta'] as Map)['next_cursor'] as String?,
    );
  }
}
