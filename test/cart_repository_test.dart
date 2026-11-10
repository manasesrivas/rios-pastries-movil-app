import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:rios_pastries/data/database/cart_database.dart';
import 'package:rios_pastries/data/models/cart_availability_issue.dart';
import 'package:rios_pastries/data/models/product_model.dart';
import 'package:rios_pastries/data/repositories/cart_repository.dart';

void main() {
  late CartDatabase database;
  late CartRepository repository;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    database = CartDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = CartRepository(cartDatabase: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('increments duplicate products without mixing users', () async {
    final product = _product(id: 5);

    await repository.addProduct(10, product);
    await repository.addProduct(10, product, quantity: 2);
    await repository.addProduct(11, product);

    final userTenItems = await repository.getItems(10);
    final userElevenItems = await repository.getItems(11);

    expect(userTenItems, hasLength(1));
    expect(userTenItems.single.quantity, 3);
    expect(userElevenItems, hasLength(1));
    expect(userElevenItems.single.quantity, 1);
    expect(userTenItems.single.userId, 10);
  });

  test(
    'updates availability and excludes unavailable products at read time',
    () async {
      await repository.addProduct(10, _product(id: 5));
      await repository.addProduct(10, _product(id: 6));

      await repository.syncAvailability(10, [
        _product(id: 5, available: false),
      ]);

      final items = await repository.getItems(10);
      expect(
        items.singleWhere((item) => item.productId == 5).isAvailable,
        isFalse,
      );
      expect(
        items.singleWhere((item) => item.productId == 6).isAvailable,
        isFalse,
      );
    },
  );

  test(
    'updates quantity and removes only from the selected user cart',
    () async {
      await repository.addProduct(10, _product(id: 5));
      await repository.addProduct(11, _product(id: 5));

      await repository.updateQuantity(10, 5, 4);
      await repository.removeProduct(10, 5);

      expect(await repository.getItems(10), isEmpty);
      expect((await repository.getItems(11)).single.quantity, 1);
    },
  );

  test('clears only the selected user cart', () async {
    await repository.addProduct(10, _product(id: 5));
    await repository.addProduct(11, _product(id: 5));

    await repository.clearCart(10);

    expect(await repository.getItems(10), isEmpty);
    expect((await repository.getItems(11)).single.productId, 5);
  });

  test('applies backend availability errors atomically per user', () async {
    await repository.addProduct(10, _product(id: 5));
    await repository.addProduct(10, _product(id: 6));
    await repository.addProduct(10, _product(id: 7));
    await repository.addProduct(11, _product(id: 5));

    await repository.applyAvailabilityIssues(10, const [
      CartAvailabilityIssue(
        productId: 5,
        code: 'PRODUCT_INACTIVE',
        message: 'Inactive',
      ),
      CartAvailabilityIssue(
        productId: 6,
        code: 'PRODUCT_NOT_FOUND',
        message: 'Missing',
      ),
      CartAvailabilityIssue(
        productId: 7,
        code: 'UNKNOWN',
        message: 'Unchanged',
      ),
    ]);

    final userTenItems = await repository.getItems(10);
    final inactive = userTenItems.singleWhere((item) => item.productId == 5);
    final unchanged = userTenItems.singleWhere((item) => item.productId == 7);
    expect(inactive.isAvailable, isFalse);
    expect(inactive.availabilityCode, 'PRODUCT_INACTIVE');
    expect(
      userTenItems.map((item) => item.productId),
      unorderedEquals([5, 7]),
    );
    expect(unchanged.isAvailable, isTrue);
    expect((await repository.getItems(11)).single.isAvailable, isTrue);
  });

  test('rejects adding unavailable products', () async {
    expect(
      () => repository.addProduct(10, _product(id: 5, available: false)),
      throwsStateError,
    );
  });
}

ProductModel _product({required int id, bool available = true}) {
  return ProductModel(
    id: id,
    name: 'Producto $id',
    image: null,
    description: '',
    price: '1.50',
    category: '',
    available: available,
    status: available ? 'disponible' : 'agotado',
  );
}
