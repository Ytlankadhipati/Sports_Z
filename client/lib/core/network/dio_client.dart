import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../auth/unauthorized_events.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';

class DioClient {
  DioClient._() : dio = _createDio();

  static final DioClient instance = DioClient._();

  final Dio dio;

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: '${ApiConfig.baseUrl}/v1',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    dio.interceptors.addAll([
      AuthInterceptor(dio: dio),
      ErrorInterceptor(onUnauthorized: UnauthorizedEvents.instance.signal401),
    ]);
    return dio;
  }
}
