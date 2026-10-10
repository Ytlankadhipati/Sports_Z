import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => message;

  static ApiException fromDio(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final body = response?.data;
    final backendMessage = _messageFromBody(body);

    if (backendMessage != null) {
      return ApiException(
        message: backendMessage,
        statusCode: statusCode,
        code: error.type.name,
      );
    }

    final message = switch (statusCode) {
      401 => 'Your session has expired. Sign in again.',
      403 => 'You do not have permission to perform this action.',
      404 => 'The requested information could not be found.',
      422 => 'Some submitted details are invalid.',
      429 => 'Too many requests. Please wait and try again.',
      int status when status >= 500 =>
        'The server could not complete the request. Please try again.',
      _ => switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'The request timed out. Check your connection and retry.',
        DioExceptionType.connectionError =>
          'Could not connect to SportsZ. Check your connection and retry.',
        DioExceptionType.cancel => 'The request was cancelled.',
        _ => 'The request could not be completed. Please try again.',
      },
    };
    return ApiException(
      message: message,
      statusCode: statusCode,
      code: error.type.name,
    );
  }

  static String? _messageFromBody(Object? body) {
    if (body is! Map) return null;
    final candidates = [body['detail'], body['message'], body['error']];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
      if (candidate is Map) {
        final nested = candidate['message'] ?? candidate['detail'];
        if (nested is String && nested.trim().isNotEmpty) return nested.trim();
      }
      if (candidate is List && candidate.isNotEmpty) {
        final messages = candidate
            .map((item) => item is Map ? item['msg'] : item)
            .whereType<String>()
            .where((message) => message.trim().isNotEmpty)
            .toList();
        if (messages.isNotEmpty) return messages.join(' ');
      }
    }
    return null;
  }
}

ApiException? apiExceptionFrom(Object error) {
  if (error is ApiException) return error;
  if (error is DioException && error.error is ApiException) {
    return error.error as ApiException;
  }
  return null;
}

String apiErrorText(Object error) {
  final apiError = apiExceptionFrom(error);
  if (apiError != null) return apiError.message;
  return error.toString();
}
