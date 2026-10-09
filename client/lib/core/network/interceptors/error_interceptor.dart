import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api_exception.dart';

class ErrorInterceptor extends Interceptor {
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
