import 'package:dio/dio.dart';

class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getAthleteProfile() =>
      _getMap('/me/profile/athlete');

  Future<Map<String, dynamic>> getSportszId() => _getMap('/me/sportsz-id');

  Future<Map<String, dynamic>> getSportsCatalog() => _getMap('/sports');

  Future<Map<String, dynamic>> getSportConfig(String sportId) =>
      _getMap('/sports/$sportId/config');

  Future<Map<String, dynamic>> getOrganizations() => _getMap('/organizations');

  Future<Map<String, dynamic>> patchAthleteProfile(
    Map<String, dynamic> payload,
  ) => _patchMap('/me/profile/athlete', payload);

  Future<Map<String, dynamic>> patchPhysical(Map<String, dynamic> payload) =>
      _patchMap('/me/profile/athlete/physical', payload);

  Future<Map<String, dynamic>> putSport(
    String sportId,
    Map<String, dynamic> payload,
  ) => _putMap('/me/profile/athlete/sports/$sportId', payload);

  Future<Map<String, dynamic>> addSport(Map<String, dynamic> payload) =>
      _postMap('/me/profile/athlete/sports', payload);

  Future<Map<String, dynamic>> setPrimarySport(String sportId) =>
      _postMap('/me/profile/athlete/sports/$sportId/primary', const {});

  Future<void> removeSport(String sportId) =>
      _delete('/me/profile/athlete/sports/$sportId');

  Future<Map<String, dynamic>> addExperience(Map<String, dynamic> payload) =>
      _postMap('/me/profile/athlete/experience', payload);

  Future<Map<String, dynamic>> updateExperience(
    String experienceId,
    Map<String, dynamic> payload,
  ) => _patchMap('/me/profile/athlete/experience/$experienceId', payload);

  Future<void> removeExperience(String experienceId) =>
      _delete('/me/profile/athlete/experience/$experienceId');

  Future<Map<String, dynamic>> _getMap(String path) async =>
      _mapData((await _dio.get<Object?>(path)).data);

  Future<Map<String, dynamic>> _postMap(
    String path,
    Map<String, dynamic> payload,
  ) async => _mapData((await _dio.post<Object?>(path, data: payload)).data);

  Future<Map<String, dynamic>> _putMap(
    String path,
    Map<String, dynamic> payload,
  ) async => _mapData((await _dio.put<Object?>(path, data: payload)).data);

  Future<Map<String, dynamic>> _patchMap(
    String path,
    Map<String, dynamic> payload,
  ) async => _mapData((await _dio.patch<Object?>(path, data: payload)).data);

  Future<void> _delete(String path) async {
    await _dio.delete<Object?>(path);
  }

  Map<String, dynamic> _mapData(Object? body) {
    if (body is! Map) throw const FormatException('Invalid API response');
    final rawData = body['data'];
    if (rawData is! Map) throw const FormatException('Invalid API response');
    return Map<String, dynamic>.from(rawData);
  }
}
