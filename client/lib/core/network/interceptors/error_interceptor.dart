import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api_exception.dart';

class ErrorInterceptor extends Interceptor {
  /// Optional callback invoked when a request's final response (after any
  /// upstream retry by [AuthInterceptor]) is HTTP 401.  The [path] of the
  /// failing request is forwarded so callers can filter auth-handshake paths.
  const ErrorInterceptor({this.onUnauthorized});

  final void Function(String path)? onUnauthorized;

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (kDebugMode) {
      debugPrint(
        '[SportsZ API] ${response.requestOptions.method} '
        '${response.requestOptions.path} '
        'succeeded status=${response.statusCode}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '[SportsZ API] ${err.requestOptions.method} '
        '${err.requestOptions.path} failed '
        'status=${err.response?.statusCode ?? 'none'} type=${err.type.name}',
      );
    }
    if (err.response?.statusCode == 401) {
      onUnauthorized?.call(err.requestOptions.path);
    }
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: ApiException.fromDio(err),
        stackTrace: err.stackTrace,
      ),
    );
  }
}
