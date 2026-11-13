import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/reservation_api_error.dart';
import '../models/reservation_create_request.dart';
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

  Future<Reservation> createReservation(
    ReservationCreateRequest request,
  ) async {
    try {
      final response = await _dio.post(
        ApiConstants.reservationsCreateEndPoint,
        data: request.toJson(),
      );
      final data = response.data;
      if (data is! Map) {
        throw const FormatException(
          'El servidor devolvió una reservación inválida.',
        );
      }
      return Reservation.fromJson(data.cast<String, dynamic>());
    } on DioException catch (error) {
      if (error.response?.statusCode == 400 &&
          error.requestOptions.path == ApiConstants.reservationsCreateEndPoint) {
        throw ReservationApiException(
          ReservationApiError.fromJson(error.response?.data),
        );
      }
      rethrow;
    }
  }

  Future<void> updateReservation({
    required int id,
    required ReservationCreateRequest request,
  }) async {
    try {
      await _dio.patch(
        '${ApiConstants.reservationsEndPoint}$id/',
        data: request.toJson(),
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 400 &&
          error.requestOptions.path ==
              '${ApiConstants.reservationsEndPoint}$id/') {
        throw ReservationApiException(
          ReservationApiError.fromJson(error.response?.data),
        );
      }
      rethrow;
    }
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
