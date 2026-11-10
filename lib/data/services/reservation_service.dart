import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/reservation_model.dart';

class ReservationService {
  ReservationService({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;

  Future<List<ReservationModel>> getReservations() async {
    try {
      final response = await _dio.get(ApiConstants.reservationsEndPoint);
      final data = response.data;
      final List<dynamic> results;

      if (data is List) {
        results = data;
      } else if (data is Map && data['results'] is List) {
        results = data['results'] as List<dynamic>;
      } else {
        throw const FormatException(
          'El servidor devolvió una lista de reservaciones inválida.',
        );
      }

      return results.map((item) {
        if (item is! Map) {
          throw const FormatException(
            'El servidor devolvió una reservación inválida.',
          );
        }
        return ReservationModel.fromJson(item.cast<String, dynamic>());
      }).toList();
    } on DioException catch (error) {
      throw Exception(DioClient.handleDioError(error));
    }
  }
}
