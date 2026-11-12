import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rios_pastries/data/models/product_model.dart';
import 'package:rios_pastries/presentation/controllers/auth_controller.dart';
import 'package:rios_pastries/presentation/providers/cart_provider.dart';
import 'package:rios_pastries/presentation/widgets/card_product.dart';

void main() {
  testWidgets('only unavailable products show the Agotado label', (
    tester,
  ) async {
    final auth = AuthController();
    final cart = CartProvider(authController: auth);
    addTearDown(auth.dispose);
    addTearDown(cart.dispose);

    ProductModel product(int id, bool available) => ProductModel(
      id: id,
      name: 'Producto $id',
      image: null,
      description: 'Descripción del producto',
      price: '1.50',
      category: 'Postres',
      available: available,
      status: 'activo',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ProductCard(
                product: product(1, false),
                authController: auth,
                cartProvider: cart,
              ),
              ProductCard(
                product: product(2, true),
                authController: auth,
                cartProvider: cart,
              ),
            ],
          ),
        ),
      ),
    );

    final cards = find.byType(ProductCard);
    expect(
      find.descendant(of: cards.first, matching: find.text('Agotado')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: cards.last, matching: find.text('Agotado')),
      findsNothing,
    );
    expect(
      tester
          .widget<InkWell>(
            find
                .descendant(of: cards.first, matching: find.byType(InkWell))
                .first,
          )
          .onTap,
      isNotNull,
    );
  });
}
