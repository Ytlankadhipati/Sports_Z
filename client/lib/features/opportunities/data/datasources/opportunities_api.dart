import 'package:dio/dio.dart';
import 'package:sports_z/features/opportunities/data/models/opportunity.dart';

class OpportunitiesApi {
  OpportunitiesApi(this._dio);

  final Dio _dio;

  Future<OpportunityPage> list({
    String? type,
    String status = 'open',
    String? cursor,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/opportunities',
        queryParameters: {
          'status': status,
          'limit': limit,
          if (type != null) 'type': type,
          if (cursor != null) 'cursor': cursor,
        },
      );
      final body = response.data!;
      final items = (body['data'] as List)
          .map((item) => Opportunity.fromJson(item as Map<String, dynamic>))
          .toList();
      return OpportunityPage(
        items,
        (body['meta'] as Map<String, dynamic>)['next_cursor'] as String?,
      );
    } on DioException catch (error) {
      _throwListError(error);
    }
  }

  Future<OpportunityDetail> getById(String publicId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/opportunities/${Uri.encodeComponent(publicId)}',
      );
      return OpportunityDetail.fromJson(
        response.data!['data'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      _throwDetailError(error);
    }
  }

  Never _throwListError(DioException error) {
    final status = error.response?.statusCode;
    if (error.error is LoginRequired) throw Exception('Please log in again.');
    if (status == 401) throw Exception('Session expired. Please log in again.');
    if (status != null)
      throw Exception('Could not load opportunities ($status).');
    throw Exception('Could not connect to the server. Please try again.');
  }

  Never _throwDetailError(DioException error) {
    final status = error.response?.statusCode;
    if (error.error is LoginRequired) throw Exception('Please log in again.');
    if (status == 401) throw Exception('Session expired. Please log in again.');
    if (status == 404)
      throw Exception('This opportunity is no longer available.');
    if (status != null) throw Exception('Could not load details ($status).');
    throw Exception('Could not connect to the server. Please try again.');
  }
}

class LoginRequired implements Exception {}
