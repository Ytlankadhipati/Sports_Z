import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:sports_z/core/config/api_config.dart';
import 'package:sports_z/features/events/data/models/event.dart';

class EventsApi {
  Future<EventPage> list({
    String status = 'upcoming',
    String? cursor,
    int limit = 20,
  }) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (token == null) throw Exception('Please log in again.');

    final uri = Uri.parse('${ApiConfig.baseUrl}/v1/events').replace(
      queryParameters: {
        'status': status,
        'limit': '$limit',
        if (cursor != null) 'cursor': cursor,
      },
    );

    final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 401) throw Exception('Session expired. Please log in again.');
    if (res.statusCode != 200) throw Exception('Could not load events (${res.statusCode}).');

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final items = (body['data'] as List)
        .map((e) => SportEvent.fromJson(e as Map<String, dynamic>))
        .toList();
    return EventPage(items, (body['meta'] as Map)['next_cursor'] as String?);
  }
}
