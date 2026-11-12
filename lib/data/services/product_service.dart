import '../../core/network/dio_client.dart';
import '../models/product_model.dart';
import '../../core/constants/api_constants.dart';

import 'package:dio/dio.dart';

class ProductService {
  ProductService({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  final Dio _dio;

  Future<List<ProductModel>> getProducts() async {
    try {
      final response = await _dio.get(ApiConstants.productsEndPoint);
      final data = response.data;
      final List<dynamic> results;
      if (data is List) {
        results = data;
      } else if (data is Map && data['results'] is List) {
        results = data['results'] as List<dynamic>;
      } else {
        throw const FormatException(
          'El servidor devolvió una lista de productos inválida.',
        );
      }
      return results.map((item) {
        if (item is! Map) {
          throw const FormatException(
            'El servidor devolvió un producto inválido.',
          );
        }
        return ProductModel.fromJson(item.cast<String, dynamic>());
      }).toList();
    } on DioException catch (e) {
      throw Exception(DioClient.handleDioError(e));
    }
  }

  Future<ProductModel> getProduct(int id) async {
    try {
      // Concatenamos el id al endpoint correspondientes (o usando interpolación)
      final response = await _dio.get('${ApiConstants.productsEndPoint}$id/');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        return ProductModel.fromJson(data);
      } else {
        throw Exception('Error al obtener el producto: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception(DioClient.handleDioError(e));
    }
  }

  
  
}
