import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({Dio? dio, FirebaseAuth? firebaseAuth})
    : _dio = dio,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final Dio? _dio;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final user = _firebaseAuth.currentUser;
      // Firebase token acquisition happens before Dio's connect timeout, so
      // bound it separately to prevent profile screens waiting indefinitely.
      final token = await user?.getIdToken().timeout(
        const Duration(seconds: 10),
      );
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      if (kDebugMode) {
        debugPrint(
          '[SportsZ API] ${options.method} ${options.path} '
          'firebaseUser=${user != null} bearerAttached=${token?.isNotEmpty == true}',
        );
      }
      handler.next(options);
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[SportsZ API] ${options.method} ${options.path} '
          'authTokenAcquisitionFailed=${error.runtimeType}',
        );
      }
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          type: DioExceptionType.unknown,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final dio = _dio;
    final user = _firebaseAuth.currentUser;
    if (err.response?.statusCode != 401 ||
        request.extra['authRetried'] == true ||
        dio == null ||
        user == null) {
      handler.next(err);
      return;
    }

    try {
      final token = await user
          .getIdToken(true)
          .timeout(const Duration(seconds: 10));
      if (token == null || token.isEmpty) {
        handler.next(err);
        return;
      }
      final retry = request.copyWith(
        headers: {...request.headers, 'Authorization': 'Bearer $token'},
        extra: {...request.extra, 'authRetried': true},
      );
      handler.resolve(await dio.fetch<Object?>(retry));
    } catch (_) {
      handler.next(err);
    }
  }
}
