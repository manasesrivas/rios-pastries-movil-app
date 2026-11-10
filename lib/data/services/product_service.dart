import '../../core/network/dio_client.dart';
import '../models/product_model.dart';
import '../../core/constants/api_constants.dart';

import 'package:dio/dio.dart';

class ProductService {
  final Dio _dio = DioClient.instance.dio;

  Future<List<ProductModel>> getProducts() async {
    try {
      final response = await _dio.get(ApiConstants.productsEndPoint);

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ProductModel.fromJson(json)).toList();
      } else {
        throw Exception('Error al cargar productos: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Error de red al obtener productos: ${e.message}');
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
      throw Exception(
        'Error de red al obtener el detalle del producto: ${e.message}',
      );
    }
  }

  
  
}
