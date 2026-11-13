import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const String genericErrorMessage = 'Ocurrió un error';

void logError(Object error, {required String operation}) {
  if (error is DioException) {
    debugPrint(
      '$operation: ${error.type}, HTTP ${error.response?.statusCode ?? '-'}'
      ', causa: ${error.error?.runtimeType ?? '-'}',
    );
  } else {
    debugPrint('$operation: $error');
  }
}
