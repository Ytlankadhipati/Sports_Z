import 'package:dio/dio.dart';
import 'package:sports_z/features/coach_links/data/models/coach_link_item.dart';
import 'package:sports_z/features/m4_common/m4_http.dart';

class CoachLinksRepository {
  CoachLinksRepository(this._dio);
  final Dio _dio;

  Future<List<CoachLinkItem>> list({String? status}) async {
    final response = await _dio.get<Object?>(
      '/coach-links',
      queryParameters: {'limit': 50, 'status': ?status},
    );
    return dataList(response).map(CoachLinkItem.fromJson).toList();
  }

  Future<CoachLinkItem> request(
    String counterpartUserId,
    String sportId,
  ) async {
    final response = await _dio.post<Object?>(
      '/coach-links',
      data: {
        'counterpart_user_id': counterpartUserId,
        'sport_id': sportId,
      },
    );
    return CoachLinkItem.fromJson(dataMap(response));
  }

  Future<CoachLinkItem> approve(String id) => _act(id, 'approve');
  Future<CoachLinkItem> decline(String id) => _act(id, 'decline');
  Future<CoachLinkItem> end(String id) => _act(id, 'end');

  Future<CoachLinkItem> _act(String id, String action) async {
    final response = await _dio.post<Object?>(
      '/coach-links/${Uri.encodeComponent(id)}/$action',
    );
    return CoachLinkItem.fromJson(dataMap(response));
  }
}
