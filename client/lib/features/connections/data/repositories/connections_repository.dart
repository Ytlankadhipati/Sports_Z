import 'package:dio/dio.dart';
import 'package:sports_z/features/connections/data/models/connection_item.dart';
import 'package:sports_z/features/m4_common/m4_http.dart';

class ConnectionsRepository {
  ConnectionsRepository(this._dio);
  final Dio _dio;

  Future<List<ConnectionItem>> list({String? status}) async {
    final response = await _dio.get<Object?>(
      '/connections',
      queryParameters: {'limit': 50, 'status': ?status},
    );
    return dataList(response).map(ConnectionItem.fromJson).toList();
  }

  Future<ConnectionItem> request(String targetUserId, {String? note}) async {
    final response = await _dio.post<Object?>(
      '/connections',
      data: {
        'target_user_id': targetUserId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return ConnectionItem.fromJson(dataMap(response));
  }

  Future<ConnectionItem> respond(String id, {required bool accept}) async {
    final response = await _dio.post<Object?>(
      '/connections/${Uri.encodeComponent(id)}/respond',
      data: {'decision': accept ? 'accept' : 'decline'},
    );
    return ConnectionItem.fromJson(dataMap(response));
  }

  Future<ConnectionItem> blockUser(String targetUserId) async {
    final response = await _dio.post<Object?>(
      '/connections/block',
      data: {'target_user_id': targetUserId},
    );
    return ConnectionItem.fromJson(dataMap(response));
  }

  Future<void> unblock(String id) async {
    await _dio.post<Object?>('/connections/${Uri.encodeComponent(id)}/unblock');
  }
}
