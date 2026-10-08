import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sports_z/core/config/api_config.dart';
import 'package:sports_z/features/opportunities/data/models/opportunity.dart';

class OpportunitiesApi {
  Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) throw Exception('Please log in again.');
    return token;
  }

  Future<OpportunityPage> list({
    String? type,
    String status = 'open',
    String? cursor,
    int limit = 20,
  }) async {
    final token = await _token();

    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/opportunities').replace(
      queryParameters: {
        'status': status,
        'limit': '$limit',
        if (type != null) 'type': type,
        if (cursor != null) 'cursor': cursor,
      },
    );

    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 401) throw Exception('Session expired. Please log in again.');
    if (res.statusCode != 200) throw Exception('Could not load opportunities (${res.statusCode}).');

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['data'] as List)
        .map((e) => Opportunity.fromJson(e as Map<String, dynamic>))
        .toList();
    return OpportunityPage(items, (body['meta'] as Map)['next_cursor'] as String?);
  }

  /// OP02: ek opportunity ki poori detail.
  Future<OpportunityDetail> getById(String publicId) async {
    final token = await _token();

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/v1/opportunities/${Uri.encodeComponent(publicId)}',
    );

    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 401) throw Exception('Session expired. Please log in again.');
    if (res.statusCode == 404) throw Exception('This opportunity is no longer available.');
    if (res.statusCode != 200) throw Exception('Could not load details (${res.statusCode}).');

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return OpportunityDetail.fromJson(body['data'] as Map<String, dynamic>);
  }
}