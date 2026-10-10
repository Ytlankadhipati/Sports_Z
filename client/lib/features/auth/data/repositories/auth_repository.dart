import 'dart:async';

import 'package:dio/dio.dart';

import '../datasources/auth_service.dart';

class AuthRepository {
  AuthRepository({required Dio dio, required AuthService authService})
    : _dio = dio,
      _authService = authService;

  final Dio _dio;
  final AuthService _authService;

  Future<Map<String, dynamic>?> verifyWithBackend() async {
    final user = _authService.currentUser;
    if (user == null) return null;
    final idToken = await _authService.getFirebaseIdToken().timeout(
      const Duration(seconds: 8),
    );
    if (idToken == null) return null;

    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/session',
      data: {'id_token': idToken},
    );
    final data = response.data;
    if (data == null || response.statusCode != 200) return null;
    await _authService.saveBackendSession(
      token: data['token'] as String,
      userId: data['user_id'] as String,
      role: data['role'] as String?,
    );
    return data;
  }

  Future<Map<String, dynamic>?> selectRole(String role) async {
    if (_authService.currentUser == null) return null;
    // V3: athlete enrolment is POST /me/roles/athlete (no body; identity comes
    // from the token). Other roles still use the generic /auth/select-role.
    final response = role == 'athlete'
        ? await _dio.post<Map<String, dynamic>>('/me/roles/athlete')
        : await _dio.post<Map<String, dynamic>>(
            '/auth/select-role',
            data: {'role': role},
          );
    final data = response.data;
    if (data == null || response.statusCode != 200) return null;
    await _authService.saveBackendSession(
      token: data['token'] as String,
      userId: data['user_id'] as String,
      role: data['role'] as String?,
    );
    return data;
  }

  /// V3: POST /auth/logout (A07, X01). Best-effort: the caller must still
  /// sign out of Firebase and clear the local session even if this fails
  /// (offline / expired token).
  Future<void> logoutFromBackend() async {
    try {
      await _dio.post<void>('/auth/logout');
    } on DioException {
      // Ignore: local sign-out must not depend on the network.
    }
  }
}
