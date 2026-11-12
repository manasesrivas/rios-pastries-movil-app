import 'package:flutter/material.dart';

import '../../core/utils/product_image_url.dart';
import '../../data/models/product_model.dart';
import '../controllers/auth_controller.dart';
import '../providers/cart_provider.dart';
import '../screens/products/product_detail_screen.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;
  final AuthController authController;
  final CartProvider cartProvider;

  const ProductCard({
    super.key,
    required this.product,
    required this.authController,
    required this.cartProvider,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = productImageUrl(product.image);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10.0),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(
                productId: product.id,
                authController: authController,
                cartProvider: cartProvider,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('No se pudo cargar la imagen del producto: $error');
                        return const Icon(Icons.fastfood, size: 30);
                      },
                    )
                  : const Icon(Icons.fastfood, size: 30),
            ),
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              product.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              '\$${product.price}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
