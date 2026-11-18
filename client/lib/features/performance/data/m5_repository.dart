import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

/// M5 API adapter. All requests use the shared authenticated Dio client.
class M5Repository {
  M5Repository({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;
  final Dio _dio;
  Future<dynamic> _get(String path, [Map<String, dynamic>? query]) async =>
      (await _dio.get(path, queryParameters: query)).data['data'];
  Future<dynamic> _post(String path, Map<String, dynamic> body) async =>
      (await _dio.post(path, data: body)).data['data'];
  Future<dynamic> _patch(String path, Map<String, dynamic> body) async =>
      (await _dio.patch(path, data: body)).data['data'];
  Future<void> _delete(String path) async => _dio.delete(path);

  Future<List<dynamic>> performance({String? metricKey}) async =>
      List<dynamic>.from(await _get('/me/performance', {'metric_key': metricKey}));
  Future<dynamic> addPerformance(Map<String, dynamic> body) => _post('/performance', body);
  Future<dynamic> updatePerformance(String id, Map<String, dynamic> body) => _patch('/performance/$id', body);
  Future<void> deletePerformance(String id) => _delete('/performance/$id');
  Future<List<dynamic>> metricBests({String? sportId}) async =>
      List<dynamic>.from(await _get('/me/metric-bests', {'sport_id': sportId}));
  Future<List<dynamic>> achievements() async => List<dynamic>.from(await _get('/me/achievements'));
  Future<dynamic> addAchievement(Map<String, dynamic> body) => _post('/achievements', body);
  Future<dynamic> updateAchievement(String id, Map<String, dynamic> body) => _patch('/achievements/$id', body);
  Future<void> deleteAchievement(String id) => _delete('/achievements/$id');
  Future<List<dynamic>> media() async => List<dynamic>.from(await _get('/me/media'));
  Future<List<dynamic>> documents() async => List<dynamic>.from(await _get('/me/documents'));
  Future<List<dynamic>> verification() async => List<dynamic>.from(await _get('/me/verification'));
  Future<dynamic> requestVerification(Map<String, dynamic> body) => _post('/verification', body);
  Future<dynamic> resubmitVerification(String id) => _post('/me/verification/$id/resubmit', {});

  /// Returns upload_url + upload_id. Upload bytes with PUT and the returned Content-Type,
  /// then call confirmMedia/confirmDocument.
  Future<Map<String, dynamic>> createUpload({required bool document, required String filename,
    required String contentType, required int sizeBytes}) async {
    final kind = document ? 'documents' : 'media';
    return Map<String, dynamic>.from(await _post('/$kind/upload-url', {
      'filename': filename, 'content_type': contentType, 'size_bytes': sizeBytes,
      'purpose': document ? 'athlete_document' : 'evidence',
    }));
  }
  Future<dynamic> confirmUpload({required bool document, required String uploadId}) =>
      _post('/${document ? 'documents' : 'media'}/$uploadId/confirm', {});
}
