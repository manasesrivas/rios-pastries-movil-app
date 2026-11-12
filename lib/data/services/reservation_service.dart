import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/reservation_model.dart';
import 'halls_service.dart';

class ReservationService {
  ReservationService({Dio? dio})
    : _dio = dio ?? DioClient.instance.dio,
      _hallsService = HallsService(dio: dio);

  final Dio _dio;
  final HallsService _hallsService;

  Future<List<HallModel>> getHalls() => _hallsService.getHalls();

  Future<List<ReservationModel>> getReservations() async {
    try {
      final response = await _dio.get(ApiConstants.reservationsEndPoint);
      return _listFromResponse(response.data, 'reservaciones').map((item) {
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

  Future<void> createReservation(Reservation reservation) async {
    await _dio.post(
      ApiConstants.reservationsCreateEndPoint,
      data: reservation.toJson(),
    );
  }

  Future<void> updateReservation({
    required int id,
    required Reservation reservation,
  }) async {
    await _dio.patch(
      '${ApiConstants.reservationsEndPoint}$id/',
      data: reservation.toJson(),
    );
  }

  List<dynamic> _listFromResponse(dynamic data, String entityName) {
    if (data is List) return data;
    if (data is Map && data['results'] is List) {
      return data['results'] as List<dynamic>;
    }
    throw FormatException(
      'El servidor devolvió una lista de $entityName inválida.',
    );
  }
}
