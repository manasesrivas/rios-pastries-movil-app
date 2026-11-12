import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/reservation_model.dart';

class HallsService {
  HallsService({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;

  Future<List<HallModel>> getHalls() async {
    try {
      final response = await _dio.get(ApiConstants.hallsEndPoint);
      final data = response.data;
      final List<dynamic> results;

      if (data is List) {
        results = data;
      } else if (data is Map && data['results'] is List) {
        results = data['results'] as List<dynamic>;
      } else {
        throw const FormatException(
          'El servidor devolvió una lista de salas inválida.',
        );
      }

      return results.map((item) {
        if (item is! Map) {
          throw const FormatException('El servidor devolvió una sala inválida.');
        }

        final hall = HallModel.fromJson(item.cast<String, dynamic>());
        if (hall.id == null || hall.hallName.isEmpty) {
          throw const FormatException(
            'El servidor devolvió una sala sin identificador o nombre.',
          );
        }
        return hall;
      }).toList();
    } on DioException catch (error) {
      throw Exception(DioClient.handleDioError(error));
    }
  }
}