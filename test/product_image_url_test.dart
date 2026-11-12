import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/core/utils/product_image_url.dart';
import 'package:rios_pastries/data/models/cart_item.dart';
import 'package:rios_pastries/data/models/product_model.dart';
import 'package:rios_pastries/presentation/controllers/auth_controller.dart';
import 'package:rios_pastries/presentation/providers/cart_provider.dart';
import 'package:rios_pastries/presentation/widgets/card_product.dart';
import 'package:rios_pastries/presentation/widgets/cart_item_card.dart';

void main() {
  test(
    'resolves Cloudinary paths while preserving escaped names and queries',
    () {
      expect(
        productImageUrl('image/upload/v123/product%20photo.webp?x=1'),
        'https://res.cloudinary.com/ddcxvarng/image/upload/v123/product%20photo.webp?x=1',
      );
    },
  );

  test('preserves absolute URLs and resolves backend-relative paths', () {
    expect(
      productImageUrl('https://images.example.com/product.webp'),
      'https://images.example.com/product.webp',
    );
    expect(
      productImageUrl('/media/product.webp'),
      'http://127.0.0.1:8000/media/product.webp',
    );
    expect(
      productImageUrl('media/product.webp'),
      'http://127.0.0.1:8000/api/media/product.webp',
    );
  });

  test('keeps missing images empty', () {
    expect(productImageUrl(null), isNull);
    expect(productImageUrl('  '), isNull);
  });

  testWidgets('catalog and saved cart items use the resolved image URL', (
    tester,
  ) async {
    const path = 'image/upload/v123/product.webp';
    const expectedUrl =
        'https://res.cloudinary.com/ddcxvarng/image/upload/v123/product.webp';
    final auth = AuthController();
    final cart = CartProvider(authController: auth);
    addTearDown(auth.dispose);
    addTearDown(cart.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ProductCard(
                authController: auth,
                cartProvider: cart,
                product: ProductModel(
                  id: 1,
                  name: 'Producto',
                  image: path,
                  description: '',
                  price: '1.00',
                  category: '',
                  available: true,
                  status: 'activo',
                ),
              ),
              CartItemCard(
                item: CartItem(
                  id: 1,
                  userId: 1,
                  productId: 1,
                  name: 'Producto',
                  price: '1.00',
                  image: path,
                  quantity: 1,
                  isAvailable: true,
                  createdAt: DateTime(2026),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(2));
    for (final image in images) {
      expect((image.image as NetworkImage).url, expectedUrl);
    }
  });
}
