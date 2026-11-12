import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/cart_availability_issue.dart';
import '../models/cart_item.dart';
import '../models/order_model.dart';

class OrderService {
  OrderService({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;

  Future<List<OrderModel>> getOrders() async {
    try {
      final response = await _dio.get(ApiConstants.ordersEndPoint);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => OrderModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener órdenes: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error de red al obtener órdenes: ${e.message}');
    }
  }

  Future<OrderModel> getOrder(int id) async {
    try {
      final response = await _dio.get('${ApiConstants.ordersEndPoint}$id');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        return OrderModel.fromJson(data);
      } else {
        throw Exception('Error al obtener la orden: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error de red al obtener la orden: ${e.message}');
    }
  }

  Future<void> validateAvailability(List<CartItem> items) async {
    try {
      final response = await _dio.post(
        ApiConstants.validateOrderAvailabilityEndPoint,
        data: {'items': _itemsPayload(items)},
      );
      if (response.statusCode == 409) {
        throw _availabilityException(_responseMap(response.data));
      }
      final data = _responseMap(response.data);
      if (data['valid'] == true && data['code'] == 'CART_VALID') return;

      if (data['code'] == 'CART_UNAVAILABLE_PRODUCTS' ||
          data['valid'] == false) {
        throw _availabilityException(data);
      }
      
      throw FormatException(
        'Respuesta inesperada al validar el carrito: ${data['code'] ?? 'sin código'}.',
      );
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        throw _availabilityException(_responseMap(error.response?.data));
      }
      throw Exception(DioClient.handleDioError(error));
    }
  }

  Future<OrderModel> createOrder({
    required List<CartItem> items,
    required String paymentMethod,
    required String deliveryType,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.ordersEndPoint,
        data: {
          'items': _itemsPayload(items),
          'metodo_pago': paymentMethod,
          'tipo_entrega': deliveryType,
        },
      );
      if (response.statusCode == 409) {
        throw _availabilityException(_responseMap(response.data));
      }
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Error al crear el pedido: ${response.statusCode ?? 'sin código'}.',
        );
      }
      return OrderModel.fromJson(_responseMap(response.data));
    } on DioException catch (error) {
      if (error.response?.statusCode == 409) {
        throw _availabilityException(_responseMap(error.response?.data));
      }
      throw Exception(DioClient.handleDioError(error));
    }
  }

  List<Map<String, int>> _itemsPayload(List<CartItem> items) {
    return items
        .map(
          (item) => {
            'product_id': item.productId,
            'quantity': item.quantity,
          },
        )
        .toList();
  }

  Map<String, dynamic> _responseMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    throw const FormatException('El servidor devolvió una respuesta inválida.');
  }

  CartAvailabilityException _availabilityException(
    Map<String, dynamic> data,
  ) {
    final rawErrors = data['errors'];
    if (rawErrors != null && rawErrors is! List) {
      throw const FormatException(
        'El servidor devolvió errores de disponibilidad inválidos.',
      );
    }
    final errors = (rawErrors as List<dynamic>? ?? [])
        .map((error) {
          if (error is! Map) {
            throw const FormatException(
              'El servidor devolvió un error de producto inválido.',
            );
          }
          return CartAvailabilityIssue.fromJson(
            error.cast<String, dynamic>(),
          );
        })
        .toList();

    return CartAvailabilityException(
      code: data['code']?.toString() ?? 'CART_UNAVAILABLE_PRODUCTS',
      message: data['message']?.toString() ??
          'No se puede completar el pedido.',
      errors: errors,
    );
  }
}