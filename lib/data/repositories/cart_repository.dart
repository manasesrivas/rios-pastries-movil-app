import '../database/cart_database.dart';
import '../models/cart_availability_issue.dart';
import '../models/cart_item.dart';
import '../models/product_model.dart';

class CartRepository {
  CartRepository({CartDatabase? cartDatabase})
    : _cartDatabase = cartDatabase ?? CartDatabase.instance;

  final CartDatabase _cartDatabase;

  Future<List<CartItem>> getItems(int userId) async {
    final db = await _cartDatabase.database;
    final rows = await db.query(
      CartDatabase.tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(CartItem.fromMap).toList();
  }

  Future<void> addProduct(
    int userId,
    ProductModel product, {
    int quantity = 1,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity', 'Debe ser mayor que 0.');
    }
    if (!product.available) {
      throw StateError('El producto ya no está disponible.');
    }

    final db = await _cartDatabase.database;
    await db.transaction((transaction) async {
      final existing = await transaction.query(
        CartDatabase.tableName,
        columns: ['quantity'],
        where: 'user_id = ? AND product_id = ?',
        whereArgs: [userId, product.id],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        await transaction.update(
          CartDatabase.tableName,
          {
            'name': product.name,
            'price': product.price,
            'image': product.image,
            'quantity': (existing.first['quantity'] as int) + quantity,
            'is_available': product.available ? 1 : 0,
            'availability_code': null,
          },
          where: 'user_id = ? AND product_id = ?',
          whereArgs: [userId, product.id],
        );
        return;
      }

      await transaction.insert(CartDatabase.tableName, {
        'user_id': userId,
        'product_id': product.id,
        'name': product.name,
        'price': product.price,
        'image': product.image,
        'quantity': quantity,
        'is_available': product.available ? 1 : 0,
        'availability_code': null,
        'created_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> updateQuantity(
    int userId,
    int productId,
    int quantity,
  ) async {
    if (quantity <= 0) {
      throw ArgumentError.value(quantity, 'quantity', 'Debe ser mayor que 0.');
    }

    final db = await _cartDatabase.database;
    final updatedCount = await db.update(
      CartDatabase.tableName,
      {'quantity': quantity},
      where: 'user_id = ? AND product_id = ?',
      whereArgs: [userId, productId],
    );
    if (updatedCount == 0) {
      throw StateError('El producto no existe en el carrito.');
    }
  }

  Future<void> removeProduct(int userId, int productId) async {
    final db = await _cartDatabase.database;
    await db.delete(
      CartDatabase.tableName,
      where: 'user_id = ? AND product_id = ?',
      whereArgs: [userId, productId],
    );
  }

  Future<void> clearCart(int userId) async {
    final db = await _cartDatabase.database;
    await db.delete(
      CartDatabase.tableName,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> syncAvailability(
    int userId,
    List<ProductModel> backendProducts,
  ) async {
    final productsById = {
      for (final product in backendProducts) product.id: product,
    };
    final db = await _cartDatabase.database;

    await db.transaction((transaction) async {
      final items = await transaction.query(
        CartDatabase.tableName,
        columns: ['product_id', 'is_available', 'availability_code'],
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      for (final item in items) {
        final product = productsById[item['product_id'] as int];
        final isAvailable = product?.available ?? false;
        final availabilityCode = product == null
            ? 'PRODUCT_NOT_FOUND'
            : isAvailable
            ? null
            : 'PRODUCT_INACTIVE';
        if ((item['is_available'] as int) != (isAvailable ? 1 : 0) ||
            item['availability_code'] != availabilityCode) {
          await transaction.update(
            CartDatabase.tableName,
            {
              'is_available': isAvailable ? 1 : 0,
              'availability_code': availabilityCode,
            },
            where: 'user_id = ? AND product_id = ?',
            whereArgs: [userId, item['product_id']],
          );
        }
      }
    });
  }

  Future<void> applyAvailabilityIssues(
    int userId,
    List<CartAvailabilityIssue> issues,
  ) async {
    final db = await _cartDatabase.database;
    await db.transaction((transaction) async {
      for (final issue in issues) {
        if (issue.code == 'PRODUCT_NOT_FOUND') {
          await transaction.delete(
            CartDatabase.tableName,
            where: 'user_id = ? AND product_id = ?',
            whereArgs: [userId, issue.productId],
          );
        } else if (issue.code == 'PRODUCT_INACTIVE') {
          await transaction.update(
            CartDatabase.tableName,
            {
              'is_available': 0,
              'availability_code': issue.code,
            },
            where: 'user_id = ? AND product_id = ?',
            whereArgs: [userId, issue.productId],
          );
        }
      }
    });
  }
}
